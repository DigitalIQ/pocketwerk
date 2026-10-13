import SwiftUI

/// Light snowfall for December, drawn with Canvas. Static (no animation) with Reduce Motion
/// or Low Power Mode, and hidden when "Seasonal touches" is off.
struct SeasonalSnow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func isSeason(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.month, from: date) == 12
    }

    var body: some View {
        if LibraryStore.shared.settings.seasonalTouches && Self.isSeason() {
            if reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled {
                flakes(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    flakes(time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private func flakes(time: Double) -> some View {
        Canvas { ctx, size in
            for i in 0..<36 {
                let seed = Double(i) * 12.9898
                let x0 = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let speed = 12 + (x0 * 22)
                let y = (time * speed + x0 * Double(size.height) * 3).truncatingRemainder(dividingBy: Double(size.height) + 10) - 5
                let x = x0 * Double(size.width) + sin(time * 0.6 + seed) * 8
                let r = 1.2 + x0 * 2.2
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.75)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
