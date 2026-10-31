import Cocoa
import ApplicationServices
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var mainWindow: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        menuBar = MenuBarController()
        menuBar.state.refreshPermissions()
        menuBar.showMainWindowHandler = { [weak self] in self?.presentMainWindow() }
        // Honor the saved Dock vs menu-bar-only preference.
        menuBar.applyAppearanceMode()

        // First-launch onboarding takes priority over the main window.
        if !menuBar.state.onboardingComplete {
            menuBar.showWelcomeIfNeeded()
        } else {
            promptForAccessibilityIfNeeded()
            // In menu-bar-only mode, launch quietly to the status item — no window.
            if !menuBar.state.menuBarOnly {
                menuBar.showMainWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // Cmd-Q / Quit menu: never lose an in-flight recording or unsaved edits.
    func applicationWillTerminate(_ notification: Notification) {
        menuBar?.prepareForTermination()
    }

    // Bring the main window back when the user clicks the dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            menuBar.showMainWindow()
        }
        return true
    }

    // .tinyrec file open (Finder double-click, drag-drop on dock).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            menuBar?.importMacro(at: url)
        }
        menuBar.showMainWindow()
    }

    private func promptForAccessibilityIfNeeded() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Main window

    @objc func showMainWindow(_ sender: Any?) {
        menuBar?.showMainWindow()
    }

    private func presentMainWindow() {
        if mainWindow == nil {
            mainWindow = MainWindowController(controller: menuBar)
        }
        mainWindow?.show()
    }

    /// The library advertises ⌘F; wire it through the responder chain so it
    /// reliably focuses the SwiftUI search field in the Dock window.
    @objc func focusLibrarySearch(_ sender: Any?) {
        menuBar.showMainWindow()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MenuBarController.focusSearchNotification, object: nil)
        }
    }

    @objc func showQuickRun(_ sender: Any?) {
        menuBar?.presentQuickRun()
    }

    // MARK: - File menu actions

    @objc func newRecording(_ sender: Any?) {
        menuBar?.toggleRecording()
    }

    @objc func importMacro(_ sender: Any?) {
        menuBar?.open()
    }

    @objc func exportMacro(_ sender: Any?) {
        menuBar?.exportAsScript()
    }

    @objc func exportText(_ sender: Any?) {
        menuBar?.exportAsText()
    }

    @objc func playMacro(_ sender: Any?) {
        menuBar?.play()
    }

    @objc func stopAll(_ sender: Any?) {
        menuBar?.stopAll()
    }

    @objc func openEditor(_ sender: Any?) {
        menuBar?.openEditor()
    }

    @objc func showPreferences(_ sender: Any?) {
        menuBar?.showSettingsWindow()
    }

    @objc func openAccessibilityPrefs(_ sender: Any?) {
        menuBar?.openAccessibilityPrefs()
    }

    @objc func showHelp(_ sender: Any?) {
        menuBar?.showHelp()
    }

    @objc func showAbout(_ sender: Any?) {
        menuBar?.showAbout()
    }

    // MARK: - Menu bar (top of screen)

    private func installMainMenu() {
        let main = NSMenu()

        // — App menu —
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let about = NSMenuItem(
            title: L10n.text("About TinyRecorder"),
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        let prefs = NSMenuItem(
            title: L10n.text("Settings…"),
            action: #selector(showPreferences(_:)),
            keyEquivalent: ","
        )
        prefs.target = self
        appMenu.addItem(prefs)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: L10n.text("Hide TinyRecorder"),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        ))
        let hideOthers = NSMenuItem(
            title: L10n.text("Hide Others"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(
            title: L10n.text("Show All"),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: L10n.text("Quit TinyRecorder"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appItem.submenu = appMenu
        main.addItem(appItem)

        // — File menu —
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: L10n.text("File"))
        let newRec = NSMenuItem(title: L10n.text("New Recording"), action: #selector(newRecording(_:)), keyEquivalent: "r")
        newRec.target = self
        fileMenu.addItem(newRec)
        let stop = NSMenuItem(title: L10n.text("Stop"), action: #selector(stopAll(_:)), keyEquivalent: ".")
        stop.target = self
        fileMenu.addItem(stop)
        fileMenu.addItem(.separator())
        let imp = NSMenuItem(title: L10n.text("Import Macro…"), action: #selector(importMacro(_:)), keyEquivalent: "o")
        imp.target = self
        imp.toolTip = L10n.text("Import a TinyRecorder (.tinyrec), TinyTask (.rec), or text (.txt) macro")
        fileMenu.addItem(imp)
        let exp = NSMenuItem(title: L10n.text("Export as Shell Script…"), action: #selector(exportMacro(_:)), keyEquivalent: "e")
        exp.target = self
        fileMenu.addItem(exp)
        let expText = NSMenuItem(title: L10n.text("Export as Text…"), action: #selector(exportText(_:)), keyEquivalent: "e")
        expText.keyEquivalentModifierMask = [.command, .shift]
        expText.target = self
        fileMenu.addItem(expText)
        fileMenu.addItem(.separator())
        let quickRun = NSMenuItem(title: L10n.text("Quick Run…"), action: #selector(showQuickRun(_:)), keyEquivalent: "k")
        quickRun.target = self
        fileMenu.addItem(quickRun)
        let search = NSMenuItem(title: L10n.text("Search Library"), action: #selector(focusLibrarySearch(_:)), keyEquivalent: "f")
        search.target = self
        fileMenu.addItem(search)
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(
            title: L10n.text("Close Window"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        ))
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        // — Edit menu — standard Cocoa items (Undo/Redo come from responder chain)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.text("Edit"))
        editMenu.addItem(NSMenuItem(title: L10n.text("Undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: L10n.text("Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: L10n.text("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L10n.text("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L10n.text("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L10n.text("Delete"), action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: L10n.text("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        main.addItem(editItem)

        // — Macro menu —
        let macroItem = NSMenuItem()
        let macroMenu = NSMenu(title: L10n.text("Macro"))
        let play = NSMenuItem(title: L10n.text("Play"), action: #selector(playMacro(_:)), keyEquivalent: "p")
        play.target = self
        macroMenu.addItem(play)
        let openEdit = NSMenuItem(title: L10n.text("Open Editor…"), action: #selector(openEditor(_:)), keyEquivalent: "e")
        openEdit.keyEquivalentModifierMask = [.command, .option]
        openEdit.target = self
        macroMenu.addItem(openEdit)
        macroItem.submenu = macroMenu
        main.addItem(macroItem)

        // — Window menu —
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: L10n.text("Window"))
        windowMenu.addItem(NSMenuItem(
            title: L10n.text("Minimize"),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        ))
        windowMenu.addItem(NSMenuItem(
            title: L10n.text("Zoom"),
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        ))
        windowMenu.addItem(.separator())
        let lib = NSMenuItem(title: L10n.text("Library"), action: #selector(showMainWindow(_:)), keyEquivalent: "0")
        lib.target = self
        windowMenu.addItem(lib)
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(
            title: L10n.text("Bring All to Front"),
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        ))
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        // — Help menu —
        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: L10n.text("Help"))
        let help = NSMenuItem(
            title: L10n.text("TinyRecorder Help"),
            action: #selector(AppDelegate.showHelp(_:)),
            keyEquivalent: "?"
        )
        help.target = self
        helpMenu.addItem(help)
        helpItem.submenu = helpMenu
        main.addItem(helpItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }
}
