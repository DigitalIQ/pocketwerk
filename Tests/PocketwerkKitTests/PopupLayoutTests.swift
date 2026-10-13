import Foundation
import Testing
@testable import PocketwerkKit

@Suite struct PopupLayoutTests {
    @Test func adaptiveGridColumnsAreBalanced() {
        let expected: [Int: Int] = [1: 1, 2: 2, 3: 3, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 3, 12: 4, 20: 5, 50: 8, 200: 8]
        for (count, cols) in expected {
            #expect(PopupMetrics.adaptiveColumns(count: count, layout: .grid) == cols, "count \(count)")
        }
        // Never a nearly empty last row.
        for n in 2...60 {
            let cols = PopupMetrics.adaptiveColumns(count: n, layout: .grid)
            let rows = Int((Double(n) / Double(cols)).rounded(.up))
            #expect(n - (rows - 1) * cols >= 1)
            #expect(cols * rows - n < max(rows, cols), "count \(n)")
        }
    }

    @Test func adaptiveListAndTiles() {
        #expect(PopupMetrics.adaptiveColumns(count: 5, layout: .list) == 1)
        #expect(PopupMetrics.adaptiveColumns(count: 10, layout: .list) == 2)
        #expect(PopupMetrics.adaptiveColumns(count: 30, layout: .list) == 3)
        #expect(PopupMetrics.adaptiveColumns(count: 100, layout: .tiles) == 6)
    }

    @Test func fixedColumns() {
        var input = PopupLayoutInput(itemCount: 10)
        input.columns = 4
        let m = PopupMetrics.compute(input)
        #expect(m.columns == 4)
        #expect(m.totalRows == 3)
        #expect(m.pageCount == 1)
        // Fixed columns never exceed the item count, so a small group gets a small popup.
        input.itemCount = 3
        input.columns = 6
        #expect(PopupMetrics.compute(input).columns == 3)
    }

    @Test func maxRowsPages() {
        var input = PopupLayoutInput(itemCount: 20)
        input.columns = 4
        input.maxRows = 2
        let m = PopupMetrics.compute(input)
        #expect(m.visibleRows == 2)
        #expect(m.pageCount == 3)
        #expect(m.itemsPerPage == 8)
        #expect(m.pageRange(0, itemCount: 20) == 0..<8)
        #expect(m.pageRange(2, itemCount: 20) == 16..<20)
        #expect(m.pageRange(9, itemCount: 20) == 16..<20)
        #expect(m.page(of: 9) == 1)
        #expect(m.page(of: 19) == 2)
        #expect(!m.scrolls)
        #expect(m.dotsHeight > 0)
    }

    @Test func maxRowsScrolls() {
        var input = PopupLayoutInput(itemCount: 20)
        input.columns = 4
        input.maxRows = 2
        input.paged = false
        let m = PopupMetrics.compute(input)
        #expect(m.scrolls)
        #expect(m.pageCount == 1)
        #expect(m.pageRange(1, itemCount: 20) == 0..<20)
        #expect(m.dotsHeight == 0)
    }

    @Test func screenLimitsRowsAndColumns() {
        var input = PopupLayoutInput(itemCount: 200)
        input.maxSize = CGSize(width: 500, height: 400)
        let m = PopupMetrics.compute(input)
        #expect(m.size.width <= 500)
        #expect(m.size.height <= 400)
        #expect(m.pageCount > 1)
        #expect(m.pageCount * m.itemsPerPage >= 200)
    }

    @Test func sizeAddsUp() {
        var input = PopupLayoutInput(itemCount: 8)
        input.showHeader = false
        let m = PopupMetrics.compute(input)
        #expect(m.columns == 4)
        #expect(m.visibleRows == 2)
        #expect(m.size.width == m.gridSize.width + 2 * m.padding)
        #expect(m.size.height == m.gridSize.height + 2 * m.padding)
        #expect(m.gridSize.width == 4 * m.cell.width + 3 * m.gap)
    }

    @Test func headerMinimumWidthAndDotsForGroups() {
        var input = PopupLayoutInput(itemCount: 1)
        input.groupCount = 3
        let m = PopupMetrics.compute(input)
        #expect(m.size.width >= PopupMetrics.minWidthWithHeader)
        #expect(m.headerHeight > 0)
        #expect(m.dotsHeight > 0)
        input.showDots = false
        #expect(PopupMetrics.compute(input).dotsHeight == 0)
    }

    @Test func labelsAndScaleChangeCells() {
        var input = PopupLayoutInput(itemCount: 4)
        let withLabels = PopupMetrics.compute(input).cell
        input.labelMode = .off
        let without = PopupMetrics.compute(input).cell
        #expect(without.height < withLabels.height)
        input.scale = 1.5
        let scaled = PopupMetrics.compute(input).cell
        #expect(abs(scaled.width - without.width * 1.5) <= 1)
    }

    @Test func tilesAndListCells() {
        var input = PopupLayoutInput(itemCount: 8)
        input.layout = .tiles
        input.iconSize = 32
        let tiles = PopupMetrics.compute(input)
        #expect(tiles.cell.width == 92)
        input.layout = .list
        let list = PopupMetrics.compute(input)
        #expect(list.columns == 1)
        #expect(list.cell.width >= 220)
    }

    @Test func emptyGroupStillHasRoomForHint() {
        let m = PopupMetrics.compute(PopupLayoutInput(itemCount: 0))
        #expect(m.columns == 3)
        #expect(m.size.height > 60)
    }

    @Test func dropIndexFromPoint() {
        var input = PopupLayoutInput(itemCount: 8)
        input.columns = 4
        let m = PopupMetrics.compute(input)
        let colW = m.cell.width + m.gap
        // Middle of the first cell: on item 0.
        let mid = m.dropIndex(at: CGPoint(x: m.cell.width / 2, y: m.cell.height / 2), pageStart: 0, itemCount: 8)
        #expect(mid.onItem == 0)
        // Right edge of cell 1: insert after it.
        let edge = m.dropIndex(at: CGPoint(x: colW + m.cell.width * 0.95, y: 10), pageStart: 0, itemCount: 8)
        #expect(edge.insert == 2)
        #expect(edge.onItem == nil)
        // Second row, first cell, left edge, on page 2.
        let row = m.dropIndex(at: CGPoint(x: 2, y: m.cell.height + m.gap + 5), pageStart: 8, itemCount: 20)
        #expect(row.insert == 12)
        // Past the end clamps to the count.
        let end = m.dropIndex(at: CGPoint(x: 3 * colW + m.cell.width * 0.9, y: 500), pageStart: 0, itemCount: 8)
        #expect(end.insert == 8)
    }

    @Test func carouselStepsThroughPagesThenGroups() {
        let counts = [2, 1, 3]
        var pos = CarouselPosition(group: 0, page: 0)
        pos = CarouselPosition.step(pos, by: 1, pageCounts: counts)
        #expect(pos == CarouselPosition(group: 0, page: 1))
        pos = CarouselPosition.step(pos, by: 1, pageCounts: counts)
        #expect(pos == CarouselPosition(group: 1, page: 0))
        pos = CarouselPosition.step(pos, by: 1, pageCounts: counts)
        #expect(pos == CarouselPosition(group: 2, page: 0))
        pos = CarouselPosition.step(pos, by: -1, pageCounts: counts)
        #expect(pos == CarouselPosition(group: 1, page: 0))
        pos = CarouselPosition.step(pos, by: -1, pageCounts: counts)
        #expect(pos == CarouselPosition(group: 0, page: 1))
        // Wraps around both ways.
        #expect(CarouselPosition.step(CarouselPosition(group: 2, page: 2), by: 1, pageCounts: counts) == CarouselPosition(group: 0, page: 0))
        #expect(CarouselPosition.step(CarouselPosition(group: 0, page: 0), by: -1, pageCounts: counts) == CarouselPosition(group: 2, page: 2))
        // A single group with one page does not move without wrap.
        #expect(CarouselPosition.step(CarouselPosition(group: 0, page: 0), by: 1, pageCounts: [1], wrap: false) == CarouselPosition(group: 0, page: 0))
    }

    @Test func keyboardSelection() {
        #expect(SelectionMath.move(nil, .right, count: 5, columns: 3) == 0)
        #expect(SelectionMath.move(0, .right, count: 5, columns: 3) == 1)
        #expect(SelectionMath.move(0, .left, count: 5, columns: 3) == 0)
        #expect(SelectionMath.move(1, .down, count: 5, columns: 3) == 4)
        // Down from the last full row into a short row lands on the last item.
        #expect(SelectionMath.move(2, .down, count: 5, columns: 3) == 4)
        #expect(SelectionMath.move(4, .down, count: 5, columns: 3) == 4)
        #expect(SelectionMath.move(4, .up, count: 5, columns: 3) == 1)
        #expect(SelectionMath.move(0, .up, count: 5, columns: 3) == 0)
        #expect(SelectionMath.move(3, .right, count: 0, columns: 3) == nil)
    }

    @Test func searchRanksPrefixFirst() {
        let names = ["Safari", "Mail", "Messages", "Microsoft Word", "Système", "Home", "Photo Booth"]
        func run(_ q: String) -> [String] { PopupSearch.filter(names, query: q) { $0 } }
        #expect(run("") == names)
        #expect(run("m") == ["Mail", "Messages", "Microsoft Word", "Système", "Home"])
        #expect(run("word") == ["Microsoft Word"])
        #expect(run("SYS") == ["Système"])
        #expect(run("syste") == ["Système"])
        #expect(run("pb") == ["Photo Booth"])
        #expect(run("oo") == ["Photo Booth"])
        #expect(run("xyz").isEmpty)
    }

    @Test func reorderMath() {
        #expect(ReorderMath.move("a", to: 2, shown: ["a", "b", "c"]) == ["b", "a", "c"])
        #expect(ReorderMath.move("a", to: 3, shown: ["a", "b", "c"]) == ["b", "c", "a"])
        #expect(ReorderMath.move("c", to: 0, shown: ["a", "b", "c"]) == ["c", "a", "b"])
        #expect(ReorderMath.move("b", to: 1, shown: ["a", "b", "c"]) == ["a", "b", "c"])
        #expect(ReorderMath.move("x", to: 1, shown: ["a", "b"]) == ["a", "b"])
    }

    @Test func labelColorFromBackground() {
        #expect(PopupLook.prefersLightText(.solid(RGBA(0.05, 0.05, 0.05)), dark: false))
        #expect(!PopupLook.prefersLightText(.solid(RGBA(1, 0.95, 0.9)), dark: true))
        #expect(PopupLook.prefersLightText(.glass(tint: RGBA(0, 0, 0, 0.05), intensity: 1), dark: true))
        #expect(!PopupLook.prefersLightText(.glass(tint: RGBA(0, 0, 0, 0.05), intensity: 1), dark: false))
        #expect(PopupLook.prefersLightText(.wallpaper(blur: 20, dim: 0.2), dark: false))
        if case .solid = PopupLook.opaque(.glass(tint: RGBA(0, 0, 0, 0.3), intensity: 1), dark: true) {} else {
            Issue.record("glass must become solid under Reduce Transparency")
        }
    }

    @Test func iconCacheBuckets() {
        #expect(PopupIconCache.bucket(56) == 56)
        #expect(PopupIconCache.bucket(57) == 64)
        #expect(PopupIconCache.bucket(4) == 16)
    }
}

@Suite struct PopupStoreTests {
    func tempStore() -> LibraryStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pw-popup-\(UUID().uuidString).json")
        return LibraryStore(fileURL: url)
    }

    func urls(_ names: [String]) -> [URL] {
        names.map { URL(string: "https://\($0).example")! }
    }

    @Test func insertIntoSortedGroupKeepsShownOrder() {
        let store = tempStore()
        let g = store.addGroup(name: "Links")
        store.addItems(urls(["c", "a", "b"]), to: g.id)
        store.updateGroup(g.id) { $0.sortOrder = .name }
        let shown = store.visibleItems(of: store.group(g.id)!)
        #expect(shown.map(\.displayName) == ["a.example", "b.example", "c.example"])
        store.insertItems(urls(["d"]), into: g.id, atShownIndex: 1, shown: shown)
        let after = store.group(g.id)!
        #expect(after.sortOrder == .manual)
        #expect(after.items.map(\.displayName) == ["a.example", "d.example", "b.example", "c.example"])
        // Existing URLs are not added twice.
        store.insertItems(urls(["a"]), into: g.id, atShownIndex: 0, shown: store.visibleItems(of: after))
        #expect(store.group(g.id)!.items.count == 4)
    }

    @Test func reorderAndMoveAndRename() {
        let store = tempStore()
        let g = store.addGroup(name: "A")
        let h = store.addGroup(name: "B")
        store.addItems(urls(["x", "y", "z"]), to: g.id)
        let items = store.group(g.id)!.items
        store.reorderItem(items[2].id, in: g.id, toShownIndex: 0, shown: items)
        #expect(store.group(g.id)!.items.map(\.displayName) == ["z.example", "x.example", "y.example"])

        store.moveItem(items[0].id, from: g.id, to: h.id)
        #expect(store.group(g.id)!.items.count == 2)
        #expect(store.group(h.id)!.items.map(\.url) == [items[0].url])

        store.renameItem(items[0].id, in: g.id, to: "  Mine  ")
        #expect(store.group(h.id)!.items[0].displayName == "Mine")
        store.renameItem(items[0].id, in: h.id, to: "")
        #expect(store.group(h.id)!.items[0].customName == nil)
    }

    @Test func popupStyleUsesDefaultsWhenAsked() {
        let store = tempStore()
        let g = store.addGroup(name: "A")
        store.mutate { $0.settings.defaultStyle.iconSize = 99 }
        #expect(store.popupStyle(of: store.group(g.id)!).iconSize != 99)
        store.updateGroup(g.id) { $0.usesDefaultStyle = true }
        #expect(store.popupStyle(of: store.group(g.id)!).iconSize == 99)
        store.adjustIconSize(of: g.id, by: 8)
        #expect(store.library.settings.defaultStyle.iconSize == 107)
    }

    @Test func modelFiltersAndPicks() {
        let store = LibraryStore.shared
        var group = ItemGroup(name: "T")
        group.items = urls(["alpha", "beta", "gamma"]).map { DockItem(url: $0) }
        let model = PopupModel(groupIDs: [group.id])
        model.query = "be"
        #expect(model.shownItems(of: group).map(\.displayName) == ["beta.example"])
        model.query = ""
        #expect(model.cellCount(of: group) == 3)
        model.activate(group.items[1], in: group, modifiers: .command)
        #expect(model.picked == [group.items[1].url])
        model.activate(group.items[1], in: group, modifiers: .command)
        #expect(model.picked.isEmpty)
        _ = store
    }
}

@Suite struct PopupPhaseBTests {
    @Test func twoLineLabelsMakeTallerCells() {
        var input = PopupLayoutInput(itemCount: 6)
        let one = PopupMetrics.compute(input)
        input.labelLines = 2
        let two = PopupMetrics.compute(input)
        #expect(two.labelLines == 2)
        #expect(two.cell.height > one.cell.height)
        #expect(two.cell.width == one.cell.width)
        // Lists stay on one line, tiles always allow two.
        input.layout = .list
        #expect(PopupMetrics.compute(input).labelLines == 1)
        input.layout = .tiles
        #expect(PopupMetrics.compute(input).labelLines == 2)
    }

    @Test func labelFitMeasuresNames() {
        var style = GroupStyle()
        style.iconSize = 56
        let short = [DockItem(kind: .link, url: URL(string: "https://a.example")!, customName: "Mail")]
        let long = [DockItem(kind: .link, url: URL(string: "https://b.example")!, customName: "Microsoft Remote Desktop Beta")]
        #expect(!LabelFit.needsTwoLines(short, style: style))
        #expect(LabelFit.needsTwoLines(long, style: style))
        #expect(!LabelFit.needsTwoLines([], style: style))
    }

    @Test func sidebarHeightGrowsWithGroups() {
        #expect(PopupSidebar.minHeight(groupCount: 10) > PopupSidebar.minHeight(groupCount: 2))
        #expect(PopupSidebar.compactWidth < PopupSidebar.fullWidth)
    }

    @Test func mirroredIconLook() {
        let store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pw-mirror-\(UUID().uuidString).json"))
        let g = store.addGroup(name: "M")
        store.updateGroup(g.id) { g in
            g.icon.background = .solid(RGBA(1, 0, 0))
            g.icon.opacity = 0.5
        }
        #expect(store.popupStyle(of: store.group(g.id)!).background != .solid(RGBA(1, 0, 0)))
        store.updateGroup(g.id) { $0.style.mirrorIcon = true }
        let style = store.popupStyle(of: store.group(g.id)!)
        #expect(style.background == .solid(RGBA(1, 0, 0)))
        #expect(style.opacity == 0.5)
    }

    @Test func relinkMovesItem() {
        let store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pw-relink-\(UUID().uuidString).json"))
        let g = store.addGroup(name: "R")
        store.addItems([URL(fileURLWithPath: "/nowhere/Old.txt")], to: g.id)
        let id = store.group(g.id)!.items[0].id
        store.relinkItem(id, in: g.id, to: URL(fileURLWithPath: "/tmp/New.txt"))
        #expect(store.group(g.id)!.items[0].url.lastPathComponent == "New.txt")
        #expect(store.group(g.id)!.items[0].id == id)
    }
}
