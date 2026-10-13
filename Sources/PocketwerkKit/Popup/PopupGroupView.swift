import SwiftUI

// OWNER: popup agent. Placeholder with the final API.

/// One group as the popup shows it: background, border, header, items in grid/list/tiles.
/// Sizes itself to its content (adaptive layout). `preview: true` is used by the Design Studio:
/// no launching, no keyboard focus, but everything else looks exactly like the real popup.
struct PopupGroupView: View {
    let group: ItemGroup
    var preview: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            if group.style.header != .hidden { Text(group.name).font(.headline) }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(group.style.iconSize + 16)), count: 4)) {
                ForEach(group.items) { item in
                    Image(nsImage: IconRenderer.icon(for: item, size: group.style.iconSize))
                }
            }
        }
        .padding(group.style.padding)
        .background(StyleBackgroundView(background: group.style.background))
        .clipShape(RoundedRectangle(cornerRadius: group.style.cornerRadius))
    }
}
