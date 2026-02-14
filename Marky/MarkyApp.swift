import SwiftUI

@main
struct MarkyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var tabObservers: [NSObjectProtocol] = []
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true

        // Global keyboard shortcut monitor — runs before event dispatch, returning nil swallows the event (no beep)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event) ?? event
        }

        let events: [NSNotification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didChangeOcclusionStateNotification,
        ]
        for name in events {
            let obs = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                self?.updateAllTabs()
            }
            tabObservers.append(obs)
        }

        let obs = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            window.tabbingMode = .preferred
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateAllTabs()
            }
        }
        tabObservers.append(obs)
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let palette = CommandPaletteController.shared
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // When palette is visible, route keys to it first
        if palette.isVisible {
            if let handled = palette.handleKeyWhileVisible(event), handled != event {
                return handled  // nil means consumed
            }
            // If palette didn't handle it, check if it's CMD+K to close
            if mods == .command, event.charactersIgnoringModifiers == "k" {
                palette.hide()
                return nil
            }
            // Let other keys through to the search field
            return event
        }

        // CMD+K opens the palette
        if mods == .command, event.charactersIgnoringModifiers == "k" {
            palette.show()
            return nil
        }

        // CMD+1-9 switches tabs
        if mods == .command,
           let char = event.charactersIgnoringModifiers,
           let num = Int(char), num >= 1, num <= 9 {
            if switchToTab(num) {
                return nil  // consumed — no beep
            }
            return nil  // still consume to prevent beep even if tab doesn't exist
        }

        return event
    }

    @discardableResult
    private func switchToTab(_ number: Int) -> Bool {
        guard let window = NSApp.keyWindow,
              let tabs = window.tabbedWindows,
              number > 0, number <= tabs.count
        else { return false }
        let target = tabs[number - 1]
        target.makeKeyAndOrderFront(nil)
        if let tabGroup = target.tabGroup {
            tabGroup.selectedWindow = target
        }
        return true
    }

    private func updateAllTabs() {
        for window in NSApp.windows where window.isVisible {
            guard let tabs = window.tabbedWindows, tabs.count > 1 else {
                stripTabNumber(window)
                continue
            }
            for (i, tab) in tabs.enumerated() {
                setTabNumber(tab, index: i + 1)
            }
        }
    }

    private func setTabNumber(_ window: NSWindow, index: Int) {
        let title = stripNumberPrefix(window.title)
        let prefix = index <= 9 ? "\(index). " : ""
        let newTitle = prefix + title
        if window.title != newTitle {
            window.title = newTitle
        }
    }

    private func stripTabNumber(_ window: NSWindow) {
        let stripped = stripNumberPrefix(window.title)
        if window.title != stripped {
            window.title = stripped
        }
    }

    private func stripNumberPrefix(_ title: String) -> String {
        if let range = title.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return String(title[range.upperBound...])
        }
        return title
    }
}
