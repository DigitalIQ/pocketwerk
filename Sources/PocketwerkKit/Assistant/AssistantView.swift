import SwiftUI

/// Plain language editing of a group ("dark blue, list view", "add Pages and Numbers"), on device.
/// Every change is listed and can be undone; removals wait for confirmation.
struct AssistantView: View {
    let groupID: UUID
    @State private var text = ""
    @State private var status = AIStatus.current
    @FocusState private var inputFocused: Bool
    private var conversation: AssistantConversation { AssistantConversation.forGroup(groupID) }

    private var examples: [String] {
        [String(localized: "Make it dark blue with a list view"),
         String(localized: "Use a warm gradient and round corners"),
         String(localized: "Show labels only on hover"),
         String(localized: "Add my music apps"),
         String(localized: "Rename it to Studio and pick a fitting emoji")]
    }

    var body: some View {
        VStack(spacing: 0) {
            if !status.isAvailable {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(status.message)
                    Spacer()
                    if status == .notEnabled { Button("Open Settings") { AIStatus.openSettings() } }
                    Button("Check Again") { status = AIStatus.current }
                }
                .padding(12)
                .background(.orange.opacity(0.12))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if conversation.turns.isEmpty { intro }
                        ForEach(conversation.turns) { turn in
                            TurnView(turn: turn, conversation: conversation).id(turn.id)
                        }
                        if conversation.isWorking {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Thinking…").foregroundStyle(.secondary)
                            }
                            .id("working")
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: conversation.turns.count) { _, _ in
                    if let last = conversation.turns.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            Divider()
            HStack(spacing: 8) {
                TextField("Describe a change", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .onSubmit(send)
                    .disabled(!status.isAvailable)
                    .accessibilityLabel(Text("Request for the assistant"))
                Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || conversation.isWorking || !status.isAvailable)
                    .help("Send (⌘↩)")
                    .accessibilityLabel(Text("Send"))
                Menu {
                    Button("Clear Conversation") { conversation.clear() }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel(Text("More"))
            }
            .padding(12)
        }
        .onAppear {
            status = AIStatus.current
            conversation.prewarm()
            inputFocused = true
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Change this group in your own words", systemImage: "wand.and.stars").font(.headline)
            Text("The assistant can change the look, labels, layout, Dock icon and name, and add or remove apps. It runs on this Mac; the conversation is forgotten when Pocketwerk quits.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            FlowChips(items: examples) { example in
                Button { text = example; send() } label: { Text(example) }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!status.isAvailable)
            }
        }
    }

    private func send() {
        let request = text
        guard !request.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        text = ""
        Task { await conversation.send(request) }
    }
}

private struct TurnView: View {
    let turn: AssistantTurn
    let conversation: AssistantConversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer(minLength: 60)
                Text(turn.request)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                    .textSelection(.enabled)
            }
            if !turn.reply.isEmpty {
                Text(turn.reply).foregroundStyle(turn.failed ? .red : .primary).textSelection(.enabled)
            }
            if !turn.changes.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(turn.changes.enumerated()), id: \.offset) { _, change in
                        Label(change, systemImage: turn.undone ? "arrow.uturn.backward" : "checkmark")
                            .font(.callout)
                            .foregroundStyle(turn.undone ? .secondary : .primary)
                            .strikethrough(turn.undone)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            if !turn.skipped.isEmpty {
                ForEach(Array(turn.skipped.enumerated()), id: \.offset) { _, s in
                    Label(s, systemImage: "minus.circle").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !turn.removals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Remove \(turn.removals.map(\.displayName).joined(separator: ", "))?").font(.callout.weight(.semibold))
                    HStack {
                        Button("Remove", role: .destructive) { conversation.confirmRemovals(turn.id) }
                        Button("Keep") { conversation.keepItems(turn.id) }
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            if turn.after != nil {
                HStack {
                    if turn.undone {
                        Text("Undone").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Undo") { conversation.undo(turn.id) }
                            .controlSize(.small)
                            .disabled(!conversation.canUndo(turn))
                            .help(conversation.canUndo(turn) ? "Restore the group as it was before"
                                  : "The group changed since then. Use Edit > Undo instead.")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Simple wrapping row of chips.
struct FlowChips<Item, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in content(item) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty && rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var r = rows[rows.count - 1]
            r.width += (r.indices.isEmpty ? 0 : spacing) + size.width
            r.height = max(r.height, size.height)
            r.indices.append(i)
            rows[rows.count - 1] = r
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
