import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = AppPreferences()
    private lazy var lockManager = KeyboardLockManager(preferences: preferences)
    private let hudController = HUDController()
    private lazy var settingsWindowController = SettingsWindowController(
        preferences: preferences,
        lockManager: lockManager
    )

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var lockMouseMenuItem: NSMenuItem!
    private var playSoundMenuItem: NSMenuItem!
    private var languageMenuItem: NSMenuItem!
    private var zhLanguageMenuItem: NSMenuItem!
    private var enLanguageMenuItem: NSMenuItem!
    private var settingsMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var quitMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 避免重复启动多个实例
        if let bundleID = Bundle.main.bundleIdentifier {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.count > 1 {
                NSApp.terminate(nil)
                return
            }
        }

        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        bindCallbacks()

        let firstLaunch = !preferences.hasLaunchedBefore
        let trustedNow = lockManager.checkAccessibility(prompt: false)
        let shouldPrompt = firstLaunch || !trustedNow
        let forceShowSettings = CommandLine.arguments.contains("--show-settings")
        preferences.hasLaunchedBefore = true

        _ = lockManager.start(promptAccessibilityIfNeeded: shouldPrompt)
        updateStatusBarAppearance()

        if shouldPrompt || forceShowSettings {
            settingsWindowController.showAndActivate()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.showAndActivate()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        lockManager.stop()
    }

    // MARK: - 菜单栏构建

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let lang = preferences.language

        let menu = NSMenu()
        menu.delegate = self

        statusMenuItem = NSMenuItem(title: L10n.menuStatusNormal(shortcut: preferences.shortcut.displayString, lang), action: #selector(openSettings), keyEquivalent: "")
        statusMenuItem.target = self
        menu.addItem(statusMenuItem)

        toggleMenuItem = NSMenuItem(title: L10n.menuToggleLock(shortcut: preferences.shortcut.displayString, lang), action: #selector(toggleLockFromMenu), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        lockMouseMenuItem = NSMenuItem(
            title: L10n.menuBlockTrackpad(lang),
            action: #selector(toggleLockMouse),
            keyEquivalent: ""
        )
        lockMouseMenuItem.target = self
        menu.addItem(lockMouseMenuItem)

        playSoundMenuItem = NSMenuItem(
            title: L10n.menuPlaySound(lang),
            action: #selector(togglePlaySound),
            keyEquivalent: ""
        )
        playSoundMenuItem.target = self
        menu.addItem(playSoundMenuItem)

        languageMenuItem = NSMenuItem(title: L10n.menuLanguageTitle(lang), action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        zhLanguageMenuItem = NSMenuItem(title: "简体中文", action: #selector(selectChineseLanguage), keyEquivalent: "")
        zhLanguageMenuItem.target = self
        languageSubmenu.addItem(zhLanguageMenuItem)

        enLanguageMenuItem = NSMenuItem(title: "English", action: #selector(selectEnglishLanguage), keyEquivalent: "")
        enLanguageMenuItem.target = self
        languageSubmenu.addItem(enLanguageMenuItem)
        languageMenuItem.submenu = languageSubmenu
        menu.addItem(languageMenuItem)

        settingsMenuItem = NSMenuItem(
            title: L10n.menuSettings(lang),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)

        launchAtLoginMenuItem = NSMenuItem(
            title: L10n.menuLaunchAtLogin(lang),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(.separator())

        quitMenuItem = NSMenuItem(title: L10n.menuQuit(lang), action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    private func bindCallbacks() {
        preferences.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarAppearance()
                self?.settingsWindowController.refreshUI()
            }
        }

        lockManager.onStatusChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarAppearance()
                self?.settingsWindowController.refreshUI()
            }
        }

        lockManager.stateMachine.onLockStateChanged = { [weak self] locked in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateStatusBarAppearance()
                self.settingsWindowController.refreshUI()
                self.hudController.show(
                    locked: locked,
                    shortcutDisplay: self.preferences.shortcut.displayString,
                    mouseLocked: self.preferences.lockLocalMouseToo,
                    language: self.preferences.language
                )
                self.playToggleSound(locked: locked)
            }
        }

        lockManager.stateMachine.onBlockedCountChanged = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateStatusMenuItems()
                self?.settingsWindowController.refreshUI()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        lockManager.refreshStatus()
        updateStatusMenuItems()
    }

    private func updateStatusBarAppearance() {
        guard let button = statusItem.button else { return }
        let locked = lockManager.stateMachine.isLocked
        let ready = lockManager.isAccessibilityGranted && lockManager.isTapActive
        let lang = preferences.language
        let shortcutText = preferences.shortcut.displayString
        let accessibilityDesc = L10n.statusBarAccessibilityDescription(locked: locked, ready: ready, lang: lang)

        if locked {
            let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: accessibilityDesc)
            image?.isTemplate = true
            button.image = image
            button.title = L10n.statusBarButtonLockedTitle(lang)
            button.toolTip = L10n.statusBarTooltipLocked(shortcut: shortcutText, lang)
        } else if !ready {
            let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: accessibilityDesc)
            image?.isTemplate = true
            button.image = image
            button.title = L10n.statusBarButtonSetupTitle(lang)
            button.toolTip = L10n.statusBarTooltipSetup(lang)
        } else {
            let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: accessibilityDesc)
            image?.isTemplate = true
            button.image = image
            button.title = ""
            button.toolTip = L10n.statusBarTooltipStandby(shortcut: shortcutText, lang)
        }

        updateStatusMenuItems()
    }

    private func updateStatusMenuItems() {
        let locked = lockManager.stateMachine.isLocked
        let ready = lockManager.isAccessibilityGranted && lockManager.isTapActive
        let shortcutText = preferences.shortcut.displayString
        let lang = preferences.language

        if !ready {
            statusMenuItem.title = L10n.menuStatusUnauthorized(lang)
        } else if locked {
            let blocked = lockManager.stateMachine.blockedCountThisSession
            statusMenuItem.title = L10n.menuStatusLocked(blocked: blocked, lang)
        } else {
            statusMenuItem.title = L10n.menuStatusNormal(shortcut: shortcutText, lang)
        }

        toggleMenuItem.title = locked
            ? L10n.menuToggleUnlock(shortcut: shortcutText, lang)
            : L10n.menuToggleLock(shortcut: shortcutText, lang)
        toggleMenuItem.isEnabled = ready

        lockMouseMenuItem.title = L10n.menuBlockTrackpad(lang)
        lockMouseMenuItem.state = preferences.lockLocalMouseToo ? .on : .off

        playSoundMenuItem.title = L10n.menuPlaySound(lang)
        playSoundMenuItem.state = preferences.playSoundOnToggle ? .on : .off

        languageMenuItem.title = L10n.menuLanguageTitle(lang)
        zhLanguageMenuItem.state = (lang == .zhHans) ? .on : .off
        enLanguageMenuItem.state = (lang == .en) ? .on : .off

        settingsMenuItem.title = L10n.menuSettings(lang)

        launchAtLoginMenuItem.title = L10n.menuLaunchAtLogin(lang)
        launchAtLoginMenuItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        quitMenuItem.title = L10n.menuQuit(lang)
    }

    private func playToggleSound(locked: Bool) {
        guard preferences.playSoundOnToggle else { return }
        let name = locked ? NSSound.Name("Tink") : NSSound.Name("Purr")
        NSSound(named: name)?.play()
    }

    // MARK: - 菜单动作

    @objc private func toggleLockFromMenu() {
        lockManager.stateMachine.toggleFromUI()
    }

    @objc private func toggleLockMouse() {
        preferences.lockLocalMouseToo.toggle()
    }

    @objc private func togglePlaySound() {
        preferences.playSoundOnToggle.toggle()
    }

    @objc private func selectChineseLanguage() {
        preferences.language = .zhHans
    }

    @objc private func selectEnglishLanguage() {
        preferences.language = .en
    }

    @objc private func openSettings() {
        settingsWindowController.showAndActivate()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            settingsWindowController.showAndActivate()
        }
        updateStatusMenuItems()
        settingsWindowController.refreshUI()
    }

    @objc private func quitApp() {
        lockManager.stop()
        NSApp.terminate(nil)
    }
}
