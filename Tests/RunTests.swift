import AppKit
import CoreGraphics
import Foundation

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition() {
        fputs("FAIL [\(file):\(line)] \(message)\n", stderr)
        exit(1)
    }
}

func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String, file: String = #file, line: Int = #line) {
    if lhs != rhs {
        fputs("FAIL [\(file):\(line)] \(message): got \(lhs), expected \(rhs)\n", stderr)
        exit(1)
    }
}

func makeKeyEvent(
    keyCode: Int64,
    keyDown: Bool,
    flags: CGEventFlags = [],
    sourcePID: Int64,
    autorepeat: Int64 = 0
) -> CGEvent {
    let ev = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: keyDown)!
    ev.flags = flags
    ev.setIntegerValueField(.eventSourceUnixProcessID, value: sourcePID)
    ev.setIntegerValueField(.keyboardEventAutorepeat, value: autorepeat)
    return ev
}

func makeFlagsChangedEvent(flags: CGEventFlags, sourcePID: Int64) -> CGEvent {
    let ev = CGEvent(source: nil)!
    ev.type = .flagsChanged
    ev.flags = flags
    ev.setIntegerValueField(.eventSourceUnixProcessID, value: sourcePID)
    return ev
}

func makeMouseEvent(type: CGEventType, sourcePID: Int64, subtype: Int64 = 0) -> CGEvent {
    let ev = CGEvent(
        mouseEventSource: nil,
        mouseType: type,
        mouseCursorPosition: CGPoint(x: 100, y: 100),
        mouseButton: type == .rightMouseDown || type == .rightMouseUp ? .right : .left
    )!
    ev.setIntegerValueField(.eventSourceUnixProcessID, value: sourcePID)
    ev.setIntegerValueField(.mouseEventSubtype, value: subtype)
    return ev
}

func makeScrollEvent(units: CGScrollEventUnit, scrollPhase: Int64, sourcePID: Int64) -> CGEvent {
    let ev = CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 1, wheel1: 10, wheel2: 0, wheel3: 0)!
    ev.setIntegerValueField(.scrollWheelEventScrollPhase, value: scrollPhase)
    ev.setIntegerValueField(.eventSourceUnixProcessID, value: sourcePID)
    return ev
}

func makeGestureEvent(rawType: UInt32, sourcePID: Int64) -> (CGEventType, CGEvent) {
    let ev = CGEvent(source: nil)!
    let evType = CGEventType(rawValue: rawType)!
    ev.type = evType
    ev.setIntegerValueField(.eventSourceUnixProcessID, value: sourcePID)
    return (evType, ev)
}

func makeTestPreferences(suiteName: String) -> AppPreferences {
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return AppPreferences(defaults: defaults)
}

@main
struct RunTests {
    static func main() {
        testShortcutDisplayAndValidation()
        testUnlockedPassThrough()
        testPhysicalLockAndUnlockSwallowsShortcutKeyUp()
        testAntiStuckModifiersAfterLock()
        testCatKeySmashBlockedAndCounted()
        testRemoteControlAllowedWhileLocked()
        testAutorepeatAndDebounceProtection()
        testTrackpadBlockedWhileExternalMouseAllowed()
        testLanguagePreferenceDefaultAndSwitch()
        print("ALL 9 TEST SUITES PASSED")
    }

    // 1. 默认快捷键格式化与组合键合法性校验
    static func testShortcutDisplayAndValidation() {
        assertEqual(KeyCombo.defaultShortcut.displayString, "⌃⌥⌘L", "默认快捷键格式应为 ⌃⌥⌘L")

        if case .success = KeyCombo.validate(keyCode: 37, modifiers: []) {
            assertTrue(false, "无修饰键单键应被拒绝")
        }
        if case .success = KeyCombo.validate(keyCode: 55, modifiers: [.maskCommand]) {
            assertTrue(false, "纯修饰键应被拒绝")
        }
        if case .success = KeyCombo.validate(keyCode: 12, modifiers: [.maskCommand]) {
            assertTrue(false, "⌘Q 系统热键应被拒绝")
        }
        if case .success = KeyCombo.validate(keyCode: 12, modifiers: [.maskControl, .maskCommand]) {
            assertTrue(false, "⌃⌘Q 锁屏热键应被拒绝")
        }
        if case .success(let valid) = KeyCombo.validate(keyCode: 40, modifiers: [.maskControl, .maskAlternate]) {
            assertEqual(valid.displayString, "⌃⌥K", "合法组合键应正常返回")
        } else {
            assertTrue(false, "⌃⌥K 应通过校验")
        }
        print("PASS: testShortcutDisplayAndValidation")
    }

    // 2. 未锁定时本地物理按键与远程按键均放行
    static func testUnlockedPassThrough() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.2")
        let sm = KeyboardLockStateMachine(preferences: prefs)
        let remotePID = Int64(getpid())

        assertTrue(sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 0, keyDown: true, sourcePID: 0), now: 1.0), "未锁定时本地按键应放行")
        assertTrue(sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 0, keyDown: true, sourcePID: remotePID), now: 1.1), "未锁定时远程按键应放行")
        assertTrue(!sm.isLocked, "普通按键不应触发锁定")
        print("PASS: testUnlockedPassThrough")
    }

    // 3. 本地按下 ⌃⌥⌘L 瞬间锁定，且 L 的 keyDown/keyUp 均被吞掉
    static func testPhysicalLockAndUnlockSwallowsShortcutKeyUp() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.3")
        let sm = KeyboardLockStateMachine(preferences: prefs)
        let mods: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

        assertTrue(sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: mods, sourcePID: 0), now: 1.0), "按住修饰键应放行")
        let downPassed = sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 37, keyDown: true, flags: mods, sourcePID: 0), now: 1.05)
        assertTrue(!downPassed, "触发锁定的 L keyDown 应被吞掉")
        assertTrue(sm.isLocked, "按下 ⌃⌥⌘L 后应立即进入锁定状态")

        let upPassed = sm.processEvent(type: .keyUp, event: makeKeyEvent(keyCode: 37, keyDown: false, flags: mods, sourcePID: 0), now: 1.10)
        assertTrue(!upPassed, "触发锁定的 L keyUp 也应被吞掉")
        assertEqual(sm.blockedCountThisSession, 0, "触发键本身的 keyDown 不应计入猫踩拦截次数")
        print("PASS: testPhysicalLockAndUnlockSwallowsShortcutKeyUp")
    }

    // 4. 防卡键测试：进入锁定后松开 ⌃⌥⌘ 的递减 flagsChanged 放行直到归零，此后物理修饰键全部拦截
    static func testAntiStuckModifiersAfterLock() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.4")
        let sm = KeyboardLockStateMachine(preferences: prefs)
        let allThree: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let twoMods: CGEventFlags = [.maskControl, .maskCommand]

        _ = sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: allThree, sourcePID: 0), now: 1.0)
        _ = sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 37, keyDown: true, flags: allThree, sourcePID: 0), now: 1.05)
        assertTrue(sm.isLocked, "应处于锁定状态")

        // 用户松开 Option，剩下 Control+Command（递减释放）
        assertTrue(sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: twoMods, sourcePID: 0), now: 1.10), "松开部分修饰键应放行防止卡键")
        // 用户松开所有修饰键归零
        assertTrue(sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: [], sourcePID: 0), now: 1.15), "修饰键归零应放行")

        // 归零之后，猫踩下 Shift 或 Command，必须拦截
        assertTrue(!sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: [.maskShift], sourcePID: 0), now: 2.0), "归零后猫踩 Shift 必须被拦截")
        assertTrue(!sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: [.maskCommand], sourcePID: 0), now: 2.1), "归零后猫踩 Command 必须被拦截")
        print("PASS: testAntiStuckModifiersAfterLock")
    }

    // 5. 锁定状态下猫乱踩任意物理键全部被拦截且精准计数
    static func testCatKeySmashBlockedAndCounted() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.5")
        let sm = KeyboardLockStateMachine(preferences: prefs)
        sm.toggleFromUI(now: 1.0)
        assertTrue(sm.isLocked, "应进入锁定状态")

        // 字母 A、空格、回车、⌘Q
        assertTrue(!sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 0, keyDown: true, sourcePID: 0), now: 1.1), "猫踩 A 应拦截")
        assertTrue(!sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 49, keyDown: true, sourcePID: 0), now: 1.2), "猫踩空格应拦截")
        assertTrue(!sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 36, keyDown: true, sourcePID: 0), now: 1.3), "猫踩回车应拦截")
        assertTrue(!sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 12, keyDown: true, flags: [.maskCommand], sourcePID: 0), now: 1.4), "猫踩 ⌘Q 应拦截")
        // 连发不重复计数
        assertTrue(!sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 0, keyDown: true, sourcePID: 0, autorepeat: 1), now: 1.5), "自动连发应拦截")
        assertTrue(!sm.processEvent(type: .keyUp, event: makeKeyEvent(keyCode: 0, keyDown: false, sourcePID: 0), now: 1.6), "物理 keyUp 应拦截")

        assertEqual(sm.blockedCountThisSession, 4, "本次拦截计数应为 4")
        assertEqual(sm.totalBlockedCount, 4, "总拦截计数应为 4")
        print("PASS: testCatKeySmashBlockedAndCounted")
    }

    // 6. 锁定状态下远程控制（sourcePID > 0）打字、快捷键、鼠标 100% 放行
    static func testRemoteControlAllowedWhileLocked() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.6")
        prefs.lockLocalMouseToo = true
        let sm = KeyboardLockStateMachine(preferences: prefs)
        sm.toggleFromUI(now: 1.0)

        let remotePID = Int64(getpid())
        assertTrue(remotePID > 0, "测试进程 PID 应大于 0")

        assertTrue(sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 0, keyDown: true, sourcePID: remotePID), now: 1.1), "远程普通按键应放行")
        assertTrue(sm.processEvent(type: .keyUp, event: makeKeyEvent(keyCode: 0, keyDown: false, sourcePID: remotePID), now: 1.2), "远程 keyUp 应放行")
        assertTrue(sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 8, keyDown: true, flags: [.maskCommand], sourcePID: remotePID), now: 1.3), "远程 ⌘C 应放行")
        assertTrue(sm.processEvent(type: .flagsChanged, event: makeFlagsChangedEvent(flags: [.maskCommand], sourcePID: remotePID), now: 1.4), "远程修饰键应放行")
        assertTrue(sm.processEvent(type: .leftMouseDown, event: makeMouseEvent(type: .leftMouseDown, sourcePID: remotePID), now: 1.5), "远程鼠标点击应放行")
        assertTrue(sm.processEvent(type: .mouseMoved, event: makeMouseEvent(type: .mouseMoved, sourcePID: remotePID), now: 1.6), "远程鼠标移动应放行")
        assertTrue(sm.isLocked, "远程普通操作不应改变锁定状态")
        print("PASS: testRemoteControlAllowedWhileLocked")
    }

    // 7. 防长按连发与 0.35s 防抖冷却保护，以及正常解锁
    static func testAutorepeatAndDebounceProtection() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.7")
        let sm = KeyboardLockStateMachine(preferences: prefs)
        let mods: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

        // 1.0s 按下 ⌃⌥⌘L 锁定
        _ = sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 37, keyDown: true, flags: mods, sourcePID: 0), now: 1.0)
        assertTrue(sm.isLocked, "应进入锁定")

        // 1.05s 出现长按 autorepeat=1 不得解锁
        _ = sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 37, keyDown: true, flags: mods, sourcePID: 0, autorepeat: 1), now: 1.05)
        assertTrue(sm.isLocked, "长按连发不得解锁")

        // 1.20s 在 0.35s 防抖期内的非连发抖动不得解锁
        _ = sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 37, keyDown: true, flags: mods, sourcePID: 0, autorepeat: 0), now: 1.20)
        assertTrue(sm.isLocked, "0.35s 冷却期内不得翻转状态")

        // 1.50s 超过防抖期后再次按下 ⌃⌥⌘L，应精准解锁并吞掉该键
        let unlockDown = sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 37, keyDown: true, flags: mods, sourcePID: 0, autorepeat: 0), now: 1.50)
        assertTrue(!unlockDown, "解锁时的 L keyDown 应被吞掉")
        assertTrue(!sm.isLocked, "超过防抖期再次按下组合键应解锁")

        let unlockUp = sm.processEvent(type: .keyUp, event: makeKeyEvent(keyCode: 37, keyDown: false, flags: mods, sourcePID: 0), now: 1.55)
        assertTrue(!unlockUp, "解锁时的 L keyUp 也应被吞掉")

        // 解锁后普通打字恢复
        assertTrue(sm.processEvent(type: .keyDown, event: makeKeyEvent(keyCode: 0, keyDown: true, sourcePID: 0), now: 1.60), "解锁后本地打字应恢复放行")
        print("PASS: testAutorepeatAndDebounceProtection")
    }

    // 8. 仅屏蔽内置触控板，外接物理鼠标与远程控制鼠标完全放行
    static func testTrackpadBlockedWhileExternalMouseAllowed() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.8")
        let sm = KeyboardLockStateMachine(preferences: prefs)
        let remotePID = Int64(getpid())

        sm.toggleFromUI(now: 1.0)
        assertTrue(sm.processEvent(type: .leftMouseDown, event: makeMouseEvent(type: .leftMouseDown, sourcePID: 0, subtype: 3), now: 1.1), "未开启触控板锁时，触控板点击应放行")

        prefs.lockLocalMouseToo = true

        // 1) 内置触控板指针/点击/滚轮/多指手势应全部拦截
        assertTrue(!sm.processEvent(type: .leftMouseDown, event: makeMouseEvent(type: .leftMouseDown, sourcePID: 0, subtype: 3), now: 1.2), "触控板左键点击应拦截")
        assertTrue(!sm.processEvent(type: .rightMouseDown, event: makeMouseEvent(type: .rightMouseDown, sourcePID: 0, subtype: 3), now: 1.25), "触控板右键点击应拦截")
        assertTrue(!sm.processEvent(type: .mouseMoved, event: makeMouseEvent(type: .mouseMoved, sourcePID: 0, subtype: 3), now: 1.3), "触控板移动应拦截")
        assertTrue(!sm.processEvent(type: .scrollWheel, event: makeScrollEvent(units: .pixel, scrollPhase: 2, sourcePID: 0), now: 1.35), "触控板双指滚动应拦截")
        for raw in [29, 30, 31] as [UInt32] {
            let (gType, gEv) = makeGestureEvent(rawType: raw, sourcePID: 0)
            assertTrue(!sm.processEvent(type: gType, event: gEv, now: 1.4), "触控板手势事件(\(raw))应拦截")
        }
        assertEqual(sm.blockedCountThisSession, 2, "触控板左右键点击应计入拦截次数")

        // 2) 本地外接物理鼠标 (sourcePID == 0, subtype == 0) 必须 100% 放行
        assertTrue(sm.processEvent(type: .leftMouseDown, event: makeMouseEvent(type: .leftMouseDown, sourcePID: 0, subtype: 0), now: 1.5), "外接鼠标左键点击必须放行")
        assertTrue(sm.processEvent(type: .rightMouseDown, event: makeMouseEvent(type: .rightMouseDown, sourcePID: 0, subtype: 0), now: 1.55), "外接鼠标右键点击必须放行")
        assertTrue(sm.processEvent(type: .mouseMoved, event: makeMouseEvent(type: .mouseMoved, sourcePID: 0, subtype: 0), now: 1.6), "外接鼠标移动必须放行")
        assertTrue(sm.processEvent(type: .leftMouseDragged, event: makeMouseEvent(type: .leftMouseDragged, sourcePID: 0, subtype: 0), now: 1.65), "外接鼠标拖拽必须放行")
        assertTrue(sm.processEvent(type: .scrollWheel, event: makeScrollEvent(units: .line, scrollPhase: 0, sourcePID: 0), now: 1.7), "外接鼠标滚轮必须放行")

        // 3) 远程控制鼠标依然 100% 放行
        assertTrue(sm.processEvent(type: .leftMouseDown, event: makeMouseEvent(type: .leftMouseDown, sourcePID: remotePID, subtype: 3), now: 1.8), "远程鼠标点击必须放行")
        print("PASS: testTrackpadBlockedWhileExternalMouseAllowed")
    }

    // 9. 应用内语言设置默认中文，可切换为英文并持久化、校验错误提示同步双语化
    static func testLanguagePreferenceDefaultAndSwitch() {
        let prefs = makeTestPreferences(suiteName: "CatKeyLock.test.9")
        assertEqual(prefs.language, .zhHans, "首次未设置时默认语言应为简体中文")

        var changeCount = 0
        prefs.onChange = { changeCount += 1 }

        prefs.language = .en
        assertEqual(prefs.language, .en, "切换为英文后应成功读取")
        assertEqual(changeCount, 1, "切换语言应触发 onChange 回调")

        // 重新构造同一 suiteName 实例以验证 UserDefaults 持久化
        let reloaded = AppPreferences(defaults: UserDefaults(suiteName: "CatKeyLock.test.9")!)
        assertEqual(reloaded.language, .en, "语言设置应已持久化到 UserDefaults")

        assertTrue(
            KeyComboValidationError.modifierOnly.message(for: .zhHans).contains("请同时按下"),
            "中文校验提示应为中文"
        )
        assertTrue(
            KeyComboValidationError.modifierOnly.message(for: .en).contains("Please include"),
            "英文校验提示应为英文"
        )
        print("PASS: testLanguagePreferenceDefaultAndSwitch")
    }
}
