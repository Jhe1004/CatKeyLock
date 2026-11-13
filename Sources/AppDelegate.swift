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
    private var launchAtLoginMenuItem: NSMenuItem!

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

        let menu = NSMenu()
        menu.delegate = self

        statusMenuItem = NSMenuItem(title: "状态：本地键盘正常", action: #selector(openSettings), keyEquivalent: "")
        statusMenuItem.target = self
        menu.addItem(statusMenuItem)

        toggleMenuItem = NSMenuItem(title: "立即锁定物理键盘", action: #selector(toggleLockFromMenu), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        lockMouseMenuItem = NSMenuItem(
            title: "锁定时同时屏蔽内置触控板（不影响鼠标）",
            action: #selector(toggleLockMouse),
            keyEquivalent: ""
        )
        lockMouseMenuItem.target = self
        menu.addItem(lockMouseMenuItem)

        playSoundMenuItem = NSMenuItem(
            title: "切换时播放提示音",
            action: #selector(togglePlaySound),
            keyEquivalent: ""
        )
        playSoundMenuItem.target = self
        menu.addItem(playSoundMenuItem)

        let settingsItem = NSMenuItem(
            title: "快捷键与权限设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        launchAtLoginMenuItem = NSMenuItem(
            title: "开机自动启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出防猫锁键", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

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
                    mouseLocked: self.preferences.lockLocalMouseToo
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

        if locked {
            let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "物理键盘已锁定")
            image?.isTemplate = true
            button.image = image
            button.title = " 已锁键"
            button.toolTip = "防猫锁键：物理键盘已锁定（按 \(preferences.shortcut.displayString) 解锁）"
        } else if !ready {
            let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "等待辅助功能授权")
            image?.isTemplate = true
            button.image = image
            button.title = " 待授权"
            button.toolTip = "防猫锁键：尚未授予辅助功能权限，点击打开设置"
        } else {
            let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "防猫锁键待命中")
            image?.isTemplate = true
            button.image = image
            button.title = ""
            button.toolTip = "防猫锁键：按 \(preferences.shortcut.displayString) 锁定本地物理键盘"
        }

        updateStatusMenuItems()
    }

    private func updateStatusMenuItems() {
        let locked = lockManager.stateMachine.isLocked
        let ready = lockManager.isAccessibilityGranted && lockManager.isTapActive
        let shortcutText = preferences.shortcut.displayString

        if !ready {
            statusMenuItem.title = "⚠️ 需授予“辅助功能”权限（点击前往设置）"
        } else if locked {
            let blocked = lockManager.stateMachine.blockedCountThisSession
            statusMenuItem.title = "🔒 已锁定本地键盘（本次拦截 \(blocked) 次）"
        } else {
            statusMenuItem.title = "⌨️ 本地键盘正常（快捷键 \(shortcutText)）"
        }

        toggleMenuItem.title = locked
            ? "解锁物理键盘（\(shortcutText)）"
            : "立即锁定物理键盘（\(shortcutText)）"
        toggleMenuItem.isEnabled = ready

        lockMouseMenuItem.state = preferences.lockLocalMouseToo ? .on : .off
        playSoundMenuItem.state = preferences.playSoundOnToggle ? .on : .off
        launchAtLoginMenuItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
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
