// STUB: replaced by Dock module
import SwiftUI

/// Dock icons (slots) editor. Placeholder until the Dock module provides it.
struct DockSlotsView: View {
    var body: some View {
        ContentUnavailableView("Dock Icons", systemImage: "dock.rectangle",
                               description: Text("Dock icon settings appear here."))
    }
}

/// Saved Dock layouts. Placeholder until the Dock module provides it.
struct DockProfilesView: View {
    var body: some View {
        ContentUnavailableView("Profiles", systemImage: "square.stack.3d.up",
                               description: Text("Saved Dock layouts appear here."))
    }
}
