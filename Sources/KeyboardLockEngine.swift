import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// 纯逻辑键盘锁定状态机（与 CGEventTap 解耦，便于单元测试）。
final class KeyboardLockStateMachine {
    private static let toggleDebounceInterval: TimeInterval = 0.35
    private static let nxSystemDefinedRawType: UInt32 = 14
    private static let nxSubtypeAuxControlButtons: Int16 = 8
    private static let nxSubtypeMouseTouch: Int64 = 3
    private static let trackpadGestureRawTypes: Set<UInt32> = [18, 19, 20, 29, 30, 31, 32, 33, 34, 37]

    let preferences: AppPreferences

    private(set) var isLocked: Bool = false
    private(set) var blockedCountThisSession: Int = 0
    private(set) var totalBlockedCount: Int = 0

    /// 当用户正在设置窗口录制新快捷键时，暂停触发锁键切换
    var isRecordingShortcut: Bool = false

    private var lastPhysicalModifiers: CGEventFlags = []
    private var swallowedKeyCodes: Set<Int64> = []
    private var awaitingModifierReleaseAfterLock: Bool = false
    private var allowedReleaseMods: CGEventFlags = []
    private var lastToggleTimestamp: TimeInterval = -10.0

    var onLockStateChanged: ((Bool) -> Void)?
    var onBlockedCountChanged: ((Int, Int) -> Void)?

    init(preferences: AppPreferences) {
        self.preferences = preferences
    }

    /// 手动切换锁定状态（来自菜单栏或设置界面按钮）。
    func toggleFromUI(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        setLocked(!isLocked, triggeredByPhysical: false, currentMods: [], now: now)
    }

    /// 处理单条 CGEvent。返回 true 表示放行，false 表示拦截吞掉。
    func processEvent(
        type: CGEventType,
        event: CGEvent,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
        let isPhysicalHardware = (sourcePID == 0)
        let relevantMask = KeyCombo.relevantModifierMask

        // 1. 持续追踪物理键盘的修饰键真实状态
        if isPhysicalHardware && type == .flagsChanged {
            lastPhysicalModifiers = event.flags.intersection(relevantMask)
        }

        // 2. 检测是否命中锁定/解锁组合键
        if !isRecordingShortcut && type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            let shortcut = preferences.shortcut

            if isAutorepeat {
                if isLocked || swallowedKeyCodes.contains(keyCode) {
                    return false
                }
            } else {
                let eventMods = event.flags.intersection(relevantMask)
                let effectiveMods: CGEventFlags = isPhysicalHardware
                    ? (eventMods.isEmpty ? lastPhysicalModifiers : eventMods)
                    : eventMods

                if keyCode == shortcut.keyCode && effectiveMods.rawValue == shortcut.modifiersRaw {
                    if now - lastToggleTimestamp >= Self.toggleDebounceInterval {
                        setLocked(
                            !isLocked,
                            triggeredByPhysical: isPhysicalHardware,
                            currentMods: effectiveMods,
                            now: now
                        )
                    }
                    if isPhysicalHardware {
                        swallowedKeyCodes.insert(keyCode)
                    }
                    return false
                }
            }
        }

        // 3. 吞掉被拦截 keyDown 对应的物理 keyUp，避免解锁后泄漏孤立 keyUp
        if isPhysicalHardware && type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if swallowedKeyCodes.remove(keyCode) != nil {
                return false
            }
        }

        // 4. 远程控制软件注入的事件 (sourcePID != 0) 一律放行
        if !isPhysicalHardware {
            return true
        }

        // 5. 未锁定状态下放行所有本地物理事件
        if !isLocked {
            return true
        }

        // 6. 以下均为：已锁定状态 && 本地物理硬件事件 (sourcePID == 0)
        switch type {
        case .flagsChanged:
            return handleLockedPhysicalFlagsChanged(event: event, relevantMask: relevantMask)

        case .keyDown:
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isAutorepeat {
                recordBlockedPress()
            }
            return false

        case .keyUp:
            return false

        default:
            if type.rawValue == Self.nxSystemDefinedRawType {
                return handleLockedSystemDefinedEvent(event)
            }
            return handleLockedTrackpadOrPointerEvent(type: type, event: event)
        }
    }

    /// 已锁定时仅拦截来自内置触控板的触摸、滚动与多指手势，外接鼠标完全放行。
    private func handleLockedTrackpadOrPointerEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard preferences.lockLocalMouseToo else {
            return true
        }

        if Self.trackpadGestureRawTypes.contains(type.rawValue) {
            return false
        }

        if type == .scrollWheel {
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            let hasTouchPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
                || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
            return !(isContinuous && hasTouchPhase)
        }

        if Self.isPointerEvent(type) {
            let subtype = event.getIntegerValueField(.mouseEventSubtype)
            if subtype == Self.nxSubtypeMouseTouch {
                if type == .leftMouseDown || type == .rightMouseDown {
                    recordBlockedPress()
                }
                return false
            }
            return true
        }

        return true
    }

    private func handleLockedPhysicalFlagsChanged(
        event: CGEvent,
        relevantMask: CGEventFlags
    ) -> Bool {
        guard awaitingModifierReleaseAfterLock else {
            return false
        }

        let currentMods = event.flags.intersection(relevantMask)
        if currentMods.isEmpty {
            awaitingModifierReleaseAfterLock = false
            allowedReleaseMods = []
            return true
        }

        if currentMods.isSubset(of: allowedReleaseMods) {
            allowedReleaseMods = currentMods
            return true
        }

        // 猫新踩下了其他修饰键，立即终止释放放行并拦截
        awaitingModifierReleaseAfterLock = false
        allowedReleaseMods = []
        return false
    }

    private func handleLockedSystemDefinedEvent(_ event: CGEvent) -> Bool {
        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == Self.nxSubtypeAuxControlButtons else {
            return true
        }
        // NX_KEYTYPE_STATE: 0x0A 为按下，0x0B 为抬起
        let keyState = (nsEvent.data1 & 0xFF00) >> 8
        if keyState == 0x0A {
            recordBlockedPress()
        }
        return false
    }

    private static func isPointerEvent(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseDown, .leftMouseUp,
             .rightMouseDown, .rightMouseUp,
             .mouseMoved,
             .leftMouseDragged, .rightMouseDragged,
             .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            return true
        default:
            return false
        }
    }

    private func setLocked(
        _ newValue: Bool,
        triggeredByPhysical: Bool,
        currentMods: CGEventFlags,
        now: TimeInterval
    ) {
        lastToggleTimestamp = now
        isLocked = newValue

        if newValue {
            blockedCountThisSession = 0
            if triggeredByPhysical && !currentMods.isEmpty {
                awaitingModifierReleaseAfterLock = true
                allowedReleaseMods = currentMods
            } else {
                awaitingModifierReleaseAfterLock = false
                allowedReleaseMods = []
            }
        } else {
            awaitingModifierReleaseAfterLock = false
            allowedReleaseMods = []
        }

        onLockStateChanged?(newValue)
    }

    private func recordBlockedPress() {
        blockedCountThisSession += 1
        totalBlockedCount += 1
        onBlockedCountChanged?(blockedCountThisSession, totalBlockedCount)
    }
}

/// 负责系统辅助功能权限检测、CGEventTap 挂载与自愈。
final class KeyboardLockManager {
    let stateMachine: KeyboardLockStateMachine

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionPollTimer: Timer?

    private(set) var isAccessibilityGranted: Bool = false
    private(set) var isTapActive: Bool = false

    var onStatusChanged: (() -> Void)?

    init(preferences: AppPreferences) {
        self.stateMachine = KeyboardLockStateMachine(preferences: preferences)
    }

    deinit {
        stop()
    }

    /// 检查系统辅助功能权限；必要时触发系统授权提示并启动自动热挂载轮询。
    @discardableResult
    func start(promptAccessibilityIfNeeded: Bool) -> Bool {
        let granted = checkAccessibility(prompt: promptAccessibilityIfNeeded)
        isAccessibilityGranted = granted

        if granted {
            startEventTapIfNeeded()
            if isTapActive {
                stopPermissionPolling()
            } else {
                startPermissionPolling()
            }
        } else {
            startPermissionPolling()
        }

        onStatusChanged?()
        return granted && isTapActive
    }

    func stop() {
        stopPermissionPolling()
        teardownEventTap()
    }

    func checkAccessibility(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 清除绑定在旧版签名哈希上的失效 TCC 授权记录，并重新发起辅助功能授权请求。
    func resetAccessibilityAndReprompt() {
        teardownEventTap()
        isAccessibilityGranted = false

        let bundleID = Bundle.main.bundleIdentifier ?? "com.jianhe.CatKeyLock"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", bundleID]
        try? task.run()
        task.waitUntilExit()

        onStatusChanged?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            let granted = self.checkAccessibility(prompt: true)
            self.isAccessibilityGranted = granted
            if granted {
                self.startEventTapIfNeeded()
            }
            if !granted || !self.isTapActive {
                self.startPermissionPolling()
                self.openAccessibilityPreferences()
            } else {
                self.stopPermissionPolling()
            }
            self.onStatusChanged?()
        }
    }

    func refreshStatus() {
        let granted = checkAccessibility(prompt: false)
        let changed = (granted != isAccessibilityGranted)
        isAccessibilityGranted = granted

        if granted && !isTapActive {
            startEventTapIfNeeded()
            if isTapActive {
                stopPermissionPolling()
            } else {
                startPermissionPolling()
            }
            onStatusChanged?()
            return
        }

        if !granted && isTapActive {
            teardownEventTap()
            startPermissionPolling()
            onStatusChanged?()
            return
        }

        if changed {
            onStatusChanged?()
        }
    }

    private func startPermissionPolling() {
        guard permissionPollTimer == nil else { return }
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    private func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    private func startEventTapIfNeeded() {
        guard eventTap == nil else {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                isTapActive = CGEvent.tapIsEnabled(tap: tap)
            }
            return
        }

        let mask = Self.buildEventMask()
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardLockEventTapCallback,
            userInfo: userInfo
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardLockEventTapCallback,
            userInfo: userInfo
        )

        guard let tap = tap else {
            isTapActive = false
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isTapActive = CGEvent.tapIsEnabled(tap: tap)
    }

    private func teardownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isTapActive = false
    }

    private static func buildEventMask() -> CGEventMask {
        let types: [UInt32] = [
            CGEventType.keyDown.rawValue,
            CGEventType.keyUp.rawValue,
            CGEventType.flagsChanged.rawValue,
            14, // NX_SYSDEFINED (音量、亮度、媒体键)
            CGEventType.leftMouseDown.rawValue,
            CGEventType.leftMouseUp.rawValue,
            CGEventType.rightMouseDown.rawValue,
            CGEventType.rightMouseUp.rawValue,
            CGEventType.mouseMoved.rawValue,
            CGEventType.leftMouseDragged.rawValue,
            CGEventType.rightMouseDragged.rawValue,
            CGEventType.scrollWheel.rawValue,
            CGEventType.otherMouseDown.rawValue,
            CGEventType.otherMouseUp.rawValue,
            CGEventType.otherMouseDragged.rawValue,
            // 触控板多指手势与 Force Touch 压感事件
            18, 19, 20, 29, 30, 31, 32, 33, 34, 37,
        ]
        return types.reduce(0) { partial, raw in
            partial | (CGEventMask(1) << UInt64(raw))
        }
    }
}

private func keyboardLockEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let manager = Unmanaged<KeyboardLockManager>.fromOpaque(userInfo).takeUnretainedValue()

    // 系统超时或用户禁用保护时自动自愈重启 EventTap
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let shouldPassThrough = manager.stateMachine.processEvent(type: type, event: event)
    return shouldPassThrough ? Unmanaged.passUnretained(event) : nil
}
