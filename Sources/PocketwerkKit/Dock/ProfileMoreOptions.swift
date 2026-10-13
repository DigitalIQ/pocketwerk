import AppKit
import SwiftUI

/// Switching, Spaces, privacy and the "last context" note of one profile.
struct ProfileMoreOptions: View {
    let profile: DockProfile
    @State private var places: [SpacePlace] = []

    private var store: LibraryStore { LibraryStore.shared }
    private var profiles: DockProfiles { DockProfiles.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Switching").font(.headline)
            Toggle("Keep this profile's apps open when switching away", isOn: bind(\.appsStayOpen))
            Toggle("Skip in “Next Profile”", isOn: bind(\.excludedFromCycle))
            Toggle("Private (left out of Export All and sharing)", isOn: bind(\.isPrivate))
            HStack {
                Text("Tags")
                TextField("work, travel", text: Binding(
                    get: { profile.tags.joined(separator: ", ") },
                    set: { t in profiles.updateProfile(profile.id) {
                        $0.tags = t.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    } }))
                    .frame(maxWidth: 260)
                    .accessibilityLabel(Text("Tags"))
            }
            if store.settings.askLastContext || !profile.note.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last context note").font(.caption).foregroundStyle(.secondary)
                    TextField("Where you left off", text: Binding(
                        get: { profile.note },
                        set: { n in profiles.updateProfile(profile.id, undoable: false) { $0.note = n } }))
                        .accessibilityLabel(Text("Last context note"))
                }
            }
            spaces
        }
        .toggleStyle(.checkbox)
        .onAppear { places = SpaceWatcher.currentPlaces() }
    }

    private var spaces: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Apply automatically on").font(.caption).foregroundStyle(.secondary)
            if !store.settings.profilePerSpace, !profile.spaces.isEmpty {
                Text("Turn on “Switch with Spaces and displays” to use these.").font(.caption).foregroundStyle(.orange)
            }
            ForEach(profile.spaces, id: \.self) { id in
                HStack {
                    Text(name(of: id))
                    Spacer()
                    Button { profiles.updateProfile(profile.id) { $0.spaces.removeAll { $0 == id } } } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Remove \(name(of: id))"))
                }
            }
            HStack {
                ForEach(places, id: \.id) { place in
                    Button(place.id.hasPrefix("space:") ? String(localized: "Link This Space") : String(localized: "Link This Display")) {
                        link(place.id)
                    }
                    .disabled(profile.spaces.contains(place.id))
                    .help(Text(place.label))
                }
            }
        }
    }

    private func name(of id: String) -> String {
        if let place = places.first(where: { $0.id == id }) { return String(localized: "\(place.label) (current)") }
        return id.hasPrefix("space:") ? String(localized: "A Space") : String(localized: "A display")
    }

    /// A place belongs to one profile only, so switching is never ambiguous.
    private func link(_ id: String) {
        store.mutate { lib in
            for i in lib.profiles.indices {
                lib.profiles[i].spaces.removeAll { $0 == id }
                if lib.profiles[i].id == profile.id { lib.profiles[i].spaces.append(id) }
            }
        }
    }

    private func bind(_ key: WritableKeyPath<DockProfile, Bool>) -> Binding<Bool> {
        Binding(get: { profile[keyPath: key] }, set: { v in profiles.updateProfile(profile.id) { $0[keyPath: key] = v } })
    }
}
