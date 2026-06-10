import Cocoa
import SwiftUI

/// Hosts the library UI in a real, dockable window with proper macOS chrome.
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let controller: MenuBarController

    init(controller: MenuBarController) {
        self.controller = controller

        let host = NSHostingController(
            rootView: PopoverContentView(controller: controller, isWindow: true)
                .environmentObject(controller.recorder)
                .environmentObject(controller.player)
                .environmentObject(controller.state)
                .environmentObject(controller.library)
        )

        let win = NSWindow(contentViewController: host)
        win.title = "TinyRecorder"
        win.setContentSize(NSSize(width: 720, height: 600))
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        win.minSize = NSSize(width: 400, height: 480)
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.toolbarStyle = .unified
        win.backgroundColor = .clear
        win.setFrameAutosaveName("TinyRecorder.MainWindow")
        super.init(window: win)
        win.delegate = self
        if win.frameAutosaveName.isEmpty { win.center() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Dedicated Settings window (HIG: Settings belongs in its own window,
/// not a popover spawned inside the menu-bar popover).
final class SettingsWindowController: NSWindowController {
    init(controller: MenuBarController) {
        let host = NSHostingController(
            rootView: SettingsPanel(controller: controller, inWindow: true)
                .environmentObject(controller.state)
                .environmentObject(controller.library)
        )
        let win = NSWindow(contentViewController: host)
        win.title = "Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setFrameAutosaveName("TinyRecorder.Settings")
        super.init(window: win)
        if win.frameAutosaveName.isEmpty { win.center() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
