import AppKit
import Combine
import IOKit.ps
import SwiftUI

/// Animated background for `Background.fx`. Drawn with Canvas + TimelineView (and MeshGradient
/// for plasma), so no shader build step is needed.
///
/// CPU budget: the timeline is paused (no frames at all) when `isActive` is false or the window is
/// hidden or fully covered, and a still frame is shown under Reduce Motion and Low Power Mode.
/// While the pointer rests outside, slow effects drop to 20-30 fps; on battery every effect is capped
/// at 30 fps and draws fewer particles.
struct FXView: View {
    var params: FXParams
    /// Pointer in view coordinates from the caller. nil = read the real pointer position.
    var pointer: CGPoint?
    var isActive: Bool

    @State private var state = FXState()
    @State private var tracker = PointerTracker()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var windowVisible = true
    @State private var lively = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Effect time used for still frames: late enough that every effect has filled the view.
    static let stillTime: Double = 24

    /// Motion is allowed at all (otherwise a fixed still frame is shown).
    private var motionAllowed: Bool { !reduceMotion && !lowPower }
    private var animating: Bool { isActive && windowVisible && motionAllowed }

    private var frameInterval: Double {
        let battery = PowerState.onBattery
        let fps = lively && !battery ? FXRenderer.framesPerSecond(params.kind) : FXRenderer.idleFramesPerSecond(params.kind)
        return 1 / fps
    }

    var body: some View {
        let animating = self.animating
        TimelineView(.animation(minimumInterval: frameInterval, paused: !animating)) { timeline in
            // nil = still frame; inactive views freeze on the current moment of their clock instead.
            let real: Double? = motionAllowed ? timeline.date.timeIntervalSince(state.start) : nil
            if params.kind == .plasma {
                GeometryReader { geo in
                    PlasmaMesh(frame: makeFrame(size: geo.size, real: real))
                }
            } else {
                Canvas { gc, size in
                    FXRenderer.draw(makeFrame(size: size, real: real), into: &gc)
                }
            }
        }
        .drawingGroup()
        .background(
            // Zero opacity: the view only tracks; offscreen renderers would otherwise draw a placeholder for it.
            PointerTrackingView(tracker: tracker) { visible in
                if windowVisible != visible { windowVisible = visible }
            }
            .opacity(0)
        )
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: DispatchQueue.main)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }

    private func makeFrame(size: CGSize, real: Double?) -> FXFrame {
        let still = real == nil
        let live = !still && animating
        let ptr = live ? (pointer ?? tracker.location()) : nil
        let dt = live ? state.advance(real: real ?? 0, pointer: ptr, model: params.pointer) : 0
        // Effects run on one clock per look for the whole session, so reopening the popup
        // continues the scene (and a settled snow pile stays settled). Paused views freeze on it.
        let age = still ? 1000 : FXClock.age(of: params)
        let t = ((still ? 0 : age) + Self.stillTime) * max(0.05, params.speed)
        if live {
            let wantLively = ptr != nil || state.influence > 0.01
            if wantLively != lively { DispatchQueue.main.async { lively = wantLively } }
        }
        return FXFrame(w: Double(size.width), h: Double(size.height), t: t, age: age, dt: dt,
                       still: !live, p: params, state: state, density: PowerState.onBattery ? 0.6 : 1)
    }
}

/// One clock per look for the app session.
enum FXClock {
    private static var starts: [Int: Date] = [:]

    static func age(of params: FXParams) -> Double {
        var h = Hasher()
        h.combine(params.kind)
        h.combine(params.palette)
        let key = h.finalize()
        if let start = starts[key] { return Date().timeIntervalSince(start) }
        starts[key] = Date()
        return 0
    }
}

/// Whether the Mac runs on battery. Read at most every 30 seconds.
enum PowerState {
    private static var cached = false
    private static var checked = Date.distantPast

    static var onBattery: Bool {
        if Date().timeIntervalSince(checked) > 30 {
            checked = Date()
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
            let type = info.flatMap { IOPSGetProvidingPowerSourceType($0)?.takeUnretainedValue() as String? }
            cached = type == kIOPMBatteryPowerKey
        }
        return cached
    }
}

// MARK: - Frame

/// Everything an effect needs to draw one frame.
struct FXFrame {
    var w: Double
    var h: Double
    /// Effect time: seconds times speed.
    var t: Double
    /// Real seconds since the view appeared (snow settles over the first 30 s). Large for still frames.
    var age: Double
    var dt: Double
    var still: Bool
    var p: FXParams
    var state: FXState
    /// Particle count factor: 1, or less on battery.
    var density: Double = 1

    var size: CGSize { CGSize(width: w, height: h) }
    var rect: CGRect { CGRect(origin: .zero, size: size) }
    var minSide: Double { min(w, h) }

    func color(_ i: Int) -> RGBA { p.palette.isEmpty ? .white : p.palette[i % p.palette.count] }
    /// Intensity factor for alphas and glow.
    var k: Double { 0.35 + 0.65 * min(1.6, max(0, p.intensity)) }
    /// Effect-specific size/density knob, 0...1.
    var p3: Double { min(1, max(0, p.p3)) }

    /// Displacement away from the pointer for a point (ripple and comb models).
    func push(_ x: Double, _ y: Double, radius: Double? = nil, strength: Double = 1) -> (dx: Double, dy: Double) {
        guard let ptr = state.pointerPoint, state.influence > 0.001 else { return (0, 0) }
        let r = radius ?? minSide * PointerModel.radius
        let vx = x - Double(ptr.x), vy = y - Double(ptr.y)
        let d = max(0.001, (vx * vx + vy * vy).squareRoot())
        let f = exp(-(d / r) * (d / r))
        let mag = f * r * 0.35 * strength * state.influence
        return (vx / d * mag, vy / d * mag)
    }

    /// Position of particle `i` after the pointer reaction of this effect.
    func displaced(_ i: Int, _ x: Double, _ y: Double) -> CGPoint {
        switch p.pointer {
        case .still: return CGPoint(x: x, y: y)
        case .shove: return state.shove(i, x, y, frame: self)
        case .ripple, .comb:
            let d = push(x, y)
            return CGPoint(x: x + d.dx, y: y + d.dy)
        }
    }
}

// MARK: - State

/// Timings of the pointer models.
enum PointerModel {
    /// Ripple: how long the bump stays after the pointer leaves, then how long it takes to spring back.
    static let rippleLinger = 0.6
    static let rippleSpringBack = 0.68
    /// Comb: strands return over this many seconds.
    static let combSpringBack = 0.9
    /// Shove: pushed particles keep their offset with this time constant.
    static let shoveLinger = 10.0
    /// Radius of the reaction relative to the shorter view side.
    static let radius = 0.22
}

/// Per-view mutable state: smoothed pointer, its influence, shoved particle offsets and ripple rings.
final class FXState {
    let start = Date()
    private(set) var pointerPoint: CGPoint?
    private(set) var influence: Double = 0
    private(set) var rings: [(point: CGPoint, born: Double)] = []
    private(set) var now: Double = 0
    private var lastReal: Double?
    private var lastSeen: Double = -100
    private var lastRing: CGPoint?
    private var offsets: [CGVector] = []
    /// Per-effect cache for parts that do not move (built once per size).
    var cache: [String: Any] = [:]

    /// Advances the pointer model. Returns the frame delta in seconds.
    func advance(real: Double, pointer: CGPoint?, model: FXPointer) -> Double {
        let dt = min(0.1, max(0, real - (lastReal ?? real)))
        lastReal = real
        now = real
        guard model != .still else { influence = 0; pointerPoint = nil; return dt }
        if let pointer {
            if let old = pointerPoint, influence > 0.01 {
                let a = min(1, dt * 18)
                pointerPoint = CGPoint(x: old.x + (pointer.x - old.x) * a, y: old.y + (pointer.y - old.y) * a)
            } else {
                pointerPoint = pointer
            }
            lastSeen = real
            influence = min(1, influence + dt / 0.18)
            if model == .ripple, lastRing.map({ hypot($0.x - pointer.x, $0.y - pointer.y) > 24 }) ?? true {
                rings.append((point: pointer, born: real))
                lastRing = pointer
            }
        } else {
            lastRing = nil
            switch model {
            case .ripple:
                // Lingers briefly, then springs back.
                if real - lastSeen > PointerModel.rippleLinger { influence = max(0, influence - dt / PointerModel.rippleSpringBack) }
            case .comb: influence = max(0, influence - dt / PointerModel.combSpringBack)
            case .shove, .still: influence = 0
            }
        }
        rings.removeAll { real - $0.born > 2.6 }
        if rings.count > 16 { rings.removeFirst(rings.count - 16) }
        // Shoved particles settle back slowly.
        let decay = exp(-dt / PointerModel.shoveLinger)
        for i in offsets.indices { offsets[i].dx *= decay; offsets[i].dy *= decay }
        return dt
    }

    /// Shove model: particles near the pointer get an offset that lingers.
    func shove(_ i: Int, _ x: Double, _ y: Double, frame: FXFrame) -> CGPoint {
        if offsets.count <= i { offsets.append(contentsOf: repeatElement(CGVector(), count: i + 1 - offsets.count)) }
        var o = offsets[i]
        if let ptr = pointerPoint, influence > 0 {
            let r = frame.minSide * 0.16
            let vx = x + Double(o.dx) - Double(ptr.x), vy = y + Double(o.dy) - Double(ptr.y)
            let d = max(0.001, (vx * vx + vy * vy).squareRoot())
            if d < r * 1.6 {
                let f = exp(-(d / r) * (d / r)) * influence
                o.dx += vx / d * f * r * frame.dt * 7
                o.dy += vy / d * f * r * frame.dt * 7
                let len = (o.dx * o.dx + o.dy * o.dy).squareRoot()
                if len > r { o.dx *= r / len; o.dy *= r / len }
                offsets[i] = o
            }
        }
        return CGPoint(x: x + Double(o.dx), y: y + Double(o.dy))
    }
}

// MARK: - Pointer

/// Reads the real pointer position relative to a view, whether or not its window is key.
final class PointerTracker {
    weak var view: NSView?

    func location() -> CGPoint? {
        guard let view, let window = view.window else { return nil }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        var p = view.convert(inWindow, from: nil)
        if !view.isFlipped { p.y = view.bounds.height - p.y }
        return CGRect(origin: .zero, size: view.bounds.size).contains(p) ? p : nil
    }
}

struct PointerTrackingView: NSViewRepresentable {
    let tracker: PointerTracker
    /// Called with false when the window is hidden, minimized or fully covered.
    var onVisibility: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> TrackingView {
        let v = TrackingView()
        v.onVisibility = onVisibility
        tracker.view = v
        return v
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onVisibility = onVisibility
        tracker.view = nsView
    }
}

/// An empty view that never takes clicks and reports whether its window can be seen.
final class TrackingView: NSView {
    var onVisibility: ((Bool) -> Void)?
    private var observer: NSObjectProtocol?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        guard let window else { return }
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
        report()
    }

    private func report() {
        guard let window else { return }
        let visible = window.occlusionState.contains(.visible)
        DispatchQueue.main.async { [onVisibility] in onVisibility?(visible) }
    }
}

/// An empty view that never takes clicks.
final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Plasma (mesh gradient)

struct PlasmaMesh: View {
    let frame: FXFrame

    var body: some View {
        MeshGradient(width: 4, height: 4, points: points, colors: colors)
    }

    private var points: [SIMD2<Float>] {
        let t = frame.t
        var out: [SIMD2<Float>] = []
        let ptr = frame.state.pointerPoint
        for j in 0..<4 {
            for i in 0..<4 {
                var x = Double(i) / 3, y = Double(j) / 3
                let edgeX = i == 0 || i == 3, edgeY = j == 0 || j == 3
                if !edgeX { x += (edgeY ? 0.06 : 0.1) * sin(t * 0.55 + Double(i * 3 + j) * 1.7) }
                if !edgeY { y += (edgeX ? 0.06 : 0.1) * cos(t * 0.47 + Double(i + j * 5) * 1.3) }
                if !edgeX, !edgeY, let ptr, frame.w > 0, frame.h > 0 {
                    // Interior points lean toward the pointer.
                    let px = Double(ptr.x) / frame.w, py = Double(ptr.y) / frame.h
                    let d = hypot(px - x, py - y)
                    let f = exp(-(d / 0.35) * (d / 0.35)) * 0.18 * frame.state.influence
                    x += (px - x) * f; y += (py - y) * f
                }
                out.append(SIMD2(Float(x), Float(y)))
            }
        }
        return out
    }

    private var colors: [Color] {
        (0..<16).map { k in
            let ph = frame.t * 0.25 + Double(k) * 0.71
            var acc = RGBA(0, 0, 0, 0)
            var total = 0.0
            for m in 0..<3 {
                let wgt = pow((sin(ph + Double(m) * 2.09) + 1) / 2, 2) + 0.05
                let c = frame.color(m)
                acc = RGBA(acc.r + c.r * wgt, acc.g + c.g * wgt, acc.b + c.b * wgt, 1)
                total += wgt
            }
            return RGBA(acc.r / total, acc.g / total, acc.b / total).color
        }
    }
}
