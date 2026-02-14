import SwiftUI
import AppKit

// MARK: - Data

struct CommandItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let shortcut: String
    let action: () -> Void
}

// MARK: - Panel controller

class CommandPaletteController {
    static let shared = CommandPaletteController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<CommandPaletteContent>?
    private var clickMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        guard let keyWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }

        let state = PaletteViewModel()
        state.commands = buildCommands()
        state.onDismiss = { [weak self] in self?.hide() }

        let content = CommandPaletteContent(state: state)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 500, height: 400)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.contentView = hosting
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        // Center above the parent window
        let parentFrame = keyWindow.frame
        let x = parentFrame.midX - 250
        let y = parentFrame.midY + 50
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.hostingView = hosting

        // Dismiss when clicking outside the panel
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return event }
            if event.window !== panel {
                self.hide()
            }
            return event
        }

        // Focus the search field after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            panel.makeFirstResponder(nil)
            if let textField = self.findTextField(in: hosting) {
                panel.makeFirstResponder(textField)
            }
        }
    }

    func hide() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    private func findTextField(in view: NSView) -> NSTextField? {
        for subview in view.subviews {
            if let tf = subview as? NSTextField, tf.isEditable { return tf }
            if let found = findTextField(in: subview) { return found }
        }
        return nil
    }

    func handleKeyWhileVisible(_ event: NSEvent) -> NSEvent? {
        guard isVisible,
              let hosting = hostingView,
              let state = (hosting.rootView as? CommandPaletteContent)?.state
        else { return event }

        switch event.keyCode {
        case 53: // ESC
            hide()
            return nil
        case 125: // Down
            state.moveDown()
            return nil
        case 126: // Up
            state.moveUp()
            return nil
        case 36: // Return
            state.executeSelected()
            hide()
            return nil
        default:
            return event
        }
    }

    // MARK: - Build command list

    private func buildCommands() -> [CommandItem] {
        var items: [CommandItem] = []

        // Open documents (tabs)
        if let keyWindow = NSApp.keyWindow,
           let tabs = keyWindow.tabbedWindows, tabs.count > 1 {
            for (i, win) in tabs.enumerated() {
                let title = stripNumberPrefix(win.title.isEmpty ? "Untitled" : win.title)
                let num = i + 1
                items.append(CommandItem(
                    icon: "doc.text",
                    title: title,
                    subtitle: "Switch to tab",
                    shortcut: num <= 9 ? "⌘\(num)" : ""
                ) {
                    win.makeKeyAndOrderFront(nil)
                    if let tabGroup = win.tabGroup {
                        tabGroup.selectedWindow = win
                    }
                })
            }
        }

        items.append(CommandItem(
            icon: "doc.badge.plus", title: "New Document",
            subtitle: "Create a new markdown file", shortcut: "⌘N"
        ) {
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        })

        items.append(CommandItem(
            icon: "folder", title: "Open File…",
            subtitle: "Open a file from disk", shortcut: "⌘O"
        ) {
            NSApp.sendAction(#selector(NSDocumentController.openDocument(_:)), to: nil, from: nil)
        })

        items.append(CommandItem(
            icon: "square.and.arrow.down", title: "Save",
            subtitle: "Save the current document", shortcut: "⌘S"
        ) {
            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        })

        items.append(CommandItem(
            icon: "arrow.uturn.backward", title: "Undo",
            subtitle: "Undo the last change", shortcut: "⌘Z"
        ) {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        })

        items.append(CommandItem(
            icon: "arrow.uturn.forward", title: "Redo",
            subtitle: "Redo the last undone change", shortcut: "⌘⇧Z"
        ) {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        })

        items.append(CommandItem(
            icon: "bold", title: "Bold",
            subtitle: "Toggle bold formatting", shortcut: "⌘B"
        ) {
            NSApp.sendAction(NSSelectorFromString("toggleBoldface:"), to: nil, from: nil)
        })

        items.append(CommandItem(
            icon: "italic", title: "Italic",
            subtitle: "Toggle italic formatting", shortcut: "⌘I"
        ) {
            NSApp.sendAction(NSSelectorFromString("toggleItalics:"), to: nil, from: nil)
        })

        return items
    }

    private func stripNumberPrefix(_ title: String) -> String {
        if let range = title.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return String(title[range.upperBound...])
        }
        return title
    }
}

// MARK: - View model

class PaletteViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedIndex = 0
    var commands: [CommandItem] = []
    var onDismiss: (() -> Void)?

    var filteredItems: [CommandItem] {
        if query.isEmpty { return commands }
        let q = query.lowercased()
        return commands.filter {
            $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
        }
    }

    func moveDown() {
        if selectedIndex < filteredItems.count - 1 { selectedIndex += 1 }
    }

    func moveUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }

    func executeSelected() {
        guard selectedIndex < filteredItems.count else { return }
        filteredItems[selectedIndex].action()
    }
}

// MARK: - SwiftUI content

struct CommandPaletteContent: View {
    @ObservedObject var state: PaletteViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                TextField("Type a command…", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit {
                        state.executeSelected()
                        state.onDismiss?()
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(state.filteredItems.enumerated()), id: \.element.id) { index, item in
                            CommandRow(item: item, isSelected: index == state.selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    item.action()
                                    state.onDismiss?()
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
                .onChange(of: state.selectedIndex) { newIndex in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            if state.filteredItems.isEmpty && !state.query.isEmpty {
                Text("No results")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                    .padding(.vertical, 20)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: state.query) { _ in state.selectedIndex = 0 }
    }
}

struct CommandRow: View {
    let item: CommandItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }

            Spacer()

            if !item.shortcut.isEmpty {
                Text(item.shortcut)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.white.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }
}
