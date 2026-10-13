import Foundation

/// Everything the popup size depends on, as plain values.
nonisolated struct PopupLayoutInput: Equatable, Sendable {
    var itemCount: Int
    var layout: LayoutKind = .grid
    /// 0 = adaptive.
    var columns: Int = 0
    /// 0 = unlimited.
    var maxRows: Int = 0
    var paged = true
    var iconSize: Double = 56
    var spacing: Double = 14
    var padding: Double = 18
    var labelMode: LabelMode = .always
    var labelSize: Double = 11
    /// Grid labels: 2 when a name does not fit on one line.
    var labelLines = 1
    var showHeader = true
    /// Dots row for pages or several groups.
    var showDots = true
    /// Number of groups in the carousel (dots also appear for several groups).
    var groupCount = 1
    var scale: Double = 1
    /// Largest size the popup may take on screen.
    var maxSize = CGSize(width: 1600, height: 1000)

    init(itemCount: Int) { self.itemCount = itemCount }

    init(style: GroupStyle, itemCount: Int, groupCount: Int = 1, maxSize: CGSize = CGSize(width: 1600, height: 1000), iconSizeDelta: Double = 0) {
        self.itemCount = itemCount
        layout = style.layout
        columns = style.columns
        maxRows = style.maxRows
        paged = style.paged
        iconSize = min(max(style.iconSize + iconSizeDelta, 16), 160)
        spacing = style.spacing
        padding = style.padding
        labelMode = style.labels.mode
        labelSize = style.labels.size
        showHeader = style.header != .hidden
        showDots = style.showPageIndicator
        self.groupCount = groupCount
        scale = min(max(style.popupScale, 0.5), 2)
        self.maxSize = maxSize
    }
}

/// Resolved sizes of one popup page. All values are in points and already scaled.
nonisolated struct PopupMetrics: Equatable, Sendable {
    var columns: Int
    /// Rows shown at once (per page, or the scroll viewport).
    var visibleRows: Int
    /// Rows needed for all items.
    var totalRows: Int
    var pageCount: Int
    var itemsPerPage: Int
    /// True when the items scroll instead of paging.
    var scrolls: Bool
    var cell: CGSize
    var iconSize: CGFloat
    var gap: CGFloat
    var padding: CGFloat
    var labelSize: CGFloat
    var labelHeight: CGFloat
    /// Lines a grid label may use.
    var labelLines: Int = 1
    var headerHeight: CGFloat
    var dotsHeight: CGFloat
    /// Size of the item area (one page or the scroll viewport).
    var gridSize: CGSize
    /// Whole popup.
    var size: CGSize

    static let headerBase: CGFloat = 34
    static let dotsBase: CGFloat = 18
    static let minWidthWithHeader: CGFloat = 236

    /// Balanced adaptive column count: wider than tall, no nearly empty last row.
    static func adaptiveColumns(count: Int, layout: LayoutKind) -> Int {
        let n = max(count, 1)
        switch layout {
        case .list:
            return n <= 8 ? 1 : (n <= 24 ? 2 : 3)
        case .grid, .tiles:
            let cap = layout == .tiles ? 6 : 8
            var cols = min(max(Int((Double(n) * 1.5).squareRoot().rounded(.up)), 1), cap)
            let rows = Int((Double(n) / Double(cols)).rounded(.up))
            cols = min(Int((Double(n) / Double(rows)).rounded(.up)), cap)
            return max(cols, 1)
        }
    }

    /// Width available to a grid label before scaling.
    static func gridLabelWidth(iconSize: Double) -> Double {
        iconSize + max(18, iconSize * 0.4) - 6
    }

    /// Cell size for a layout before scaling.
    static func cellSize(layout: LayoutKind, iconSize: Double, labelMode: LabelMode, labelSize: Double, labelLines: Int = 1) -> (cell: CGSize, icon: CGFloat, labelHeight: CGFloat) {
        let lineHeight = (labelSize * 1.3).rounded(.up)
        switch layout {
        case .grid:
            let labelH = labelMode == .off ? 0 : lineHeight * CGFloat(min(max(labelLines, 1), 2)) + 4
            let width = iconSize + max(18, iconSize * 0.4)
            return (CGSize(width: width, height: iconSize + 10 + labelH), iconSize, labelH)
        case .list:
            let icon = min(max(iconSize * 0.5, 20), 48)
            let height = max(icon + 10, lineHeight + 12)
            let width = max(220, icon + 24 + labelSize * 15)
            return (CGSize(width: width, height: height), icon, lineHeight)
        case .tiles:
            let card = max(92, iconSize * 1.65)
            let labelH = labelMode == .off ? 0 : lineHeight * 2
            let icon = (card * 0.42).rounded()
            return (CGSize(width: card, height: max(card * 0.8, icon + 20 + labelH)), icon, labelH)
        }
    }

    static func compute(_ input: PopupLayoutInput) -> PopupMetrics {
        let s = CGFloat(input.scale)
        let base = cellSize(layout: input.layout, iconSize: input.iconSize, labelMode: input.labelMode, labelSize: input.labelSize, labelLines: input.labelLines)
        let cell = CGSize(width: (base.cell.width * s).rounded(), height: (base.cell.height * s).rounded())
        let gap = (CGFloat(input.layout == .list ? input.spacing * 0.4 : input.spacing) * s).rounded()
        let padding = (CGFloat(input.padding) * s).rounded()
        let header = input.showHeader ? (headerBase * s).rounded() : 0
        // The empty state shows a hint the size of a few cells.
        let count = max(input.itemCount, 0)
        let layoutCount = max(count, input.layout == .list ? 1 : 3)

        // Columns: fixed or adaptive, then limited by the screen width.
        var cols = input.columns > 0 ? input.columns : adaptiveColumns(count: layoutCount, layout: input.layout)
        if input.columns > 0 { cols = min(cols, max(layoutCount, 1)) }
        let fitCols = Int(((input.maxSize.width - 2 * padding + gap) / (cell.width + gap)).rounded(.down))
        cols = max(1, min(cols, max(fitCols, 1)))

        let totalRows = max(1, Int((Double(layoutCount) / Double(cols)).rounded(.up)))
        var rowLimit = input.maxRows > 0 ? input.maxRows : Int.max

        // Rows that fit on screen (assume dots might be needed).
        let dotsGuess = (dotsBase * s).rounded()
        let roomH = input.maxSize.height - header - 2 * padding - dotsGuess
        let fitRows = max(1, Int(((roomH + gap) / (cell.height + gap)).rounded(.down)))
        rowLimit = min(rowLimit, fitRows)

        var visibleRows = min(totalRows, rowLimit)
        var pageCount = 1
        var scrolls = false
        if totalRows > visibleRows {
            if input.paged {
                pageCount = Int((Double(layoutCount) / Double(cols * visibleRows)).rounded(.up))
            } else {
                scrolls = true
            }
        }
        visibleRows = max(visibleRows, 1)
        let showDots = input.showDots && (pageCount > 1 || input.groupCount > 1)
        let dots = showDots ? dotsGuess : 0

        let gridW = CGFloat(cols) * cell.width + CGFloat(cols - 1) * gap
        let gridH = CGFloat(visibleRows) * cell.height + CGFloat(visibleRows - 1) * gap
        var width = gridW + 2 * padding
        if input.showHeader { width = max(width, (minWidthWithHeader * s).rounded()) }
        width = min(width, input.maxSize.width)
        let height = min(header + gridH + 2 * padding + dots, input.maxSize.height)

        return PopupMetrics(
            columns: cols, visibleRows: visibleRows, totalRows: totalRows, pageCount: pageCount,
            itemsPerPage: scrolls ? layoutCount : cols * visibleRows, scrolls: scrolls,
            cell: cell, iconSize: (base.icon * s).rounded(), gap: gap, padding: padding,
            labelSize: CGFloat(input.labelSize) * s, labelHeight: base.labelHeight * s,
            labelLines: input.layout == .grid ? min(max(input.labelLines, 1), 2) : (input.layout == .tiles ? 2 : 1),
            headerHeight: header, dotsHeight: dots,
            gridSize: CGSize(width: gridW, height: gridH), size: CGSize(width: width.rounded(), height: height.rounded()))
    }

    /// Range of item indices on a page.
    func pageRange(_ page: Int, itemCount: Int) -> Range<Int> {
        guard !scrolls, pageCount > 1 else { return 0..<itemCount }
        let p = min(max(page, 0), pageCount - 1)
        let start = min(p * itemsPerPage, itemCount)
        return start..<min(start + itemsPerPage, itemCount)
    }

    /// Page that shows an item index.
    func page(of index: Int) -> Int {
        guard !scrolls, pageCount > 1, itemsPerPage > 0 else { return 0 }
        return min(max(index, 0) / itemsPerPage, pageCount - 1)
    }

    /// Item index under a point in grid coordinates (origin top left of the item area, page local),
    /// plus whether the point is on the cell itself or in the gap before it.
    /// Returns the insertion index for drops (0...count on this page).
    func dropIndex(at point: CGPoint, pageStart: Int, itemCount: Int) -> (insert: Int, onItem: Int?) {
        let colW = cell.width + gap, rowH = cell.height + gap
        let col = min(max(Int(point.x / colW), 0), columns - 1)
        let row = max(Int(point.y / rowH), 0)
        let local = row * columns + col
        let index = pageStart + local
        let xIn = point.x - CGFloat(col) * colW
        let yIn = point.y - CGFloat(row) * rowH
        let insideCell = xIn >= cell.width * 0.2 && xIn <= cell.width * 0.8 && yIn <= cell.height
        let insert = min(xIn > cell.width / 2 ? index + 1 : index, itemCount)
        return (max(insert, 0), insideCell && index < itemCount ? index : nil)
    }
}

/// Horizontal steps through pages of the current group, then on to the next group.
nonisolated struct CarouselPosition: Equatable, Sendable {
    var group: Int
    var page: Int

    /// Moves by one step. `pageCounts` holds the page count of every group.
    /// Wraps around from the last group to the first.
    static func step(_ pos: CarouselPosition, by delta: Int, pageCounts: [Int], wrap: Bool = true) -> CarouselPosition {
        guard !pageCounts.isEmpty else { return pos }
        var g = min(max(pos.group, 0), pageCounts.count - 1)
        var p = pos.page + delta
        if p >= 0, p < max(pageCounts[g], 1) { return CarouselPosition(group: g, page: p) }
        if pageCounts.count == 1 && !wrap { return CarouselPosition(group: g, page: min(max(p, 0), pageCounts[g] - 1)) }
        if delta > 0 {
            g += 1
            if g >= pageCounts.count {
                guard wrap else { return pos }
                g = 0
            }
            p = 0
        } else {
            g -= 1
            if g < 0 {
                guard wrap else { return pos }
                g = pageCounts.count - 1
            }
            p = max(pageCounts[g], 1) - 1
        }
        return CarouselPosition(group: g, page: p)
    }
}

nonisolated enum MoveDirection: Sendable {
    case left, right, up, down
}

/// Keyboard selection in a grid.
nonisolated enum SelectionMath {
    /// New selection after an arrow key. nil selection starts at the first item.
    static func move(_ selection: Int?, _ direction: MoveDirection, count: Int, columns: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let s = selection, s < count else { return 0 }
        let cols = max(columns, 1)
        switch direction {
        case .left: return max(s - 1, 0)
        case .right: return min(s + 1, count - 1)
        case .up: return s - cols >= 0 ? s - cols : s
        case .down: return s + cols < count ? s + cols : (s / cols < (count - 1) / cols ? count - 1 : s)
        }
    }
}

/// Type-to-search inside the popup.
nonisolated enum PopupSearch {
    /// Items whose name matches the query, best matches first:
    /// name starts with the query, then a word starts with it, then it appears anywhere.
    /// Case and diacritics are ignored. An empty query keeps the order.
    static func filter<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
        let q = normalize(query)
        guard !q.isEmpty else { return items }
        var ranked: [(rank: Int, index: Int, item: T)] = []
        for (i, item) in items.enumerated() {
            let n = normalize(name(item))
            let rank: Int
            if n.hasPrefix(q) {
                rank = 0
            } else if n.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(q) }) {
                rank = 1
            } else if n.contains(q) {
                rank = 2
            } else if initials(n).hasPrefix(q) {
                rank = 3
            } else {
                continue
            }
            ranked.append((rank, i, item))
        }
        return ranked.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }.map(\.item)
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func initials(_ s: String) -> String {
        String(s.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).compactMap(\.first))
    }
}

/// Reordering on screen when the shown order differs from the stored order.
nonisolated enum ReorderMath {
    /// Stored order after moving `id` to position `target` of the shown order.
    /// The result is the shown order with the move applied; the group becomes manually sorted.
    static func move<ID: Hashable>(_ id: ID, to target: Int, shown: [ID]) -> [ID] {
        guard let from = shown.firstIndex(of: id) else { return shown }
        var out = shown
        out.remove(at: from)
        let t = min(max(from < target ? target - 1 : target, 0), out.count)
        out.insert(id, at: t)
        return out
    }
}
