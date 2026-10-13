import SwiftUI

struct StudioGridInspector: View {
    let editor: StudioEditor

    private var autoLayout: Binding<Bool> {
        Binding(get: { editor.style.columns == 0 }, set: { on in
            editor.edit { g in g.style.columns = on ? 0 : max(2, min(6, Int(Double(g.items.count).squareRoot().rounded(.up)))) }
        })
    }

    /// Tight 8, Normal 14, Airy 22.
    private var density: Binding<Int> {
        Binding(get: {
            let s = editor.style.spacing
            return s < 11 ? 0 : (s < 18 ? 1 : 2)
        }, set: { i in editor.edit { $0.style.spacing = [8, 14, 22][i] } })
    }

    var body: some View {
        let style = editor.style
        Form {
            Section("View") {
                Picker("View", selection: editor.binding(\.style.layout)) {
                    Label("Grid", systemImage: "square.grid.3x3").tag(LayoutKind.grid)
                    Label("List", systemImage: "list.bullet").tag(LayoutKind.list)
                    Label("Tiles", systemImage: "square.grid.2x2").tag(LayoutKind.tiles)
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleAndIcon)
            }
            Section {
                Toggle("Auto Layout", isOn: autoLayout)
                if style.columns > 0 {
                    Stepper(value: editor.binding(\.style.columns), in: 1...12) {
                        LabeledContent("Columns", value: "\(style.columns)")
                    }
                }
                Stepper(value: editor.binding(\.style.maxRows), in: 0...12) {
                    LabeledContent("Rows", value: style.maxRows == 0 ? String(localized: "No Limit") : "\(style.maxRows)")
                }
                Toggle("Pages", isOn: editor.binding(\.style.paged))
                Toggle("Page Dots", isOn: editor.binding(\.style.showPageIndicator))
                    .disabled(!style.paged)
            } header: {
                Text("Layout")
            } footer: {
                Text(style.columns == 0 ? "Columns and rows fit the items automatically." : "More items than fit go to the next page.")
            }
            Section("Size and Spacing") {
                StudioSlider(title: "Icon Size", value: editor.binding(\.style.iconSize), range: 32...128, step: 1, format: .points, editor: editor)
                Picker("Density", selection: density) {
                    Text("Tight").tag(0)
                    Text("Normal").tag(1)
                    Text("Airy").tag(2)
                }
                .pickerStyle(.segmented)
                StudioSlider(title: "Margin", value: editor.binding(\.style.padding), range: 6...36, step: 1, format: .points, editor: editor)
                StudioSlider(title: "Popup Scale", value: editor.binding(\.style.popupScale), range: 0.7...1.5, format: .multiplier, editor: editor)
            }
            Section("Items") {
                Picker("Sort", selection: editor.binding(\.sortOrder)) {
                    Text("Manual").tag(SortOrder.manual)
                    Text("Name").tag(SortOrder.name)
                    Text("Kind").tag(SortOrder.kind)
                    Text("Date Added").tag(SortOrder.dateAdded)
                    Text("Last Opened").tag(SortOrder.lastOpened)
                    Text("Most Opened").tag(SortOrder.mostOpened)
                }
                Toggle("Running Indicator", isOn: editor.binding(\.style.runningIndicator))
            }
        }
        .formStyle(.grouped)
    }
}
