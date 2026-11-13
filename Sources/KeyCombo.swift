import AppKit
import CoreGraphics
import Foundation

/// 键盘锁定的快捷键组合模型，以及持久化偏好设置。
struct KeyCombo: Codable, Equatable, Hashable {
    static let relevantModifierMask: CGEventFlags = [
        .maskControl,
        .maskAlternate,
        .maskCommand,
        .maskShift,
    ]

    /// 默认快捷键：⌃⌥⌘L (keyCode 37)
    static let defaultShortcut = KeyCombo(
        keyCode: 37,
        modifiersRaw: CGEventFlags([.maskControl, .maskAlternate, .maskCommand]).rawValue
    )

    var keyCode: Int64
    var modifiersRaw: UInt64

    init(keyCode: Int64, modifiersRaw: UInt64) {
        self.keyCode = keyCode
        self.modifiersRaw = modifiersRaw & KeyCombo.relevantModifierMask.rawValue
    }

    init(keyCode: Int64, flags: CGEventFlags) {
        self.init(keyCode: keyCode, modifiersRaw: flags.intersection(KeyCombo.relevantModifierMask).rawValue)
    }

    var modifiers: CGEventFlags {
        CGEventFlags(rawValue: modifiersRaw).intersection(KeyCombo.relevantModifierMask)
    }

    var keyDisplayName: String {
        Self.keyName(for: keyCode)
    }

    var displayString: String {
        var result = ""
        let flags = modifiers
        if flags.contains(.maskControl) { result += "⌃" }
        if flags.contains(.maskAlternate) { result += "⌥" }
        if flags.contains(.maskShift) { result += "⇧" }
        if flags.contains(.maskCommand) { result += "⌘" }
        result += keyDisplayName
        return result
    }

    var humanReadableDescription: String {
        var parts: [String] = []
        let flags = modifiers
        if flags.contains(.maskControl) { parts.append("Control") }
        if flags.contains(.maskAlternate) { parts.append("Option") }
        if flags.contains(.maskShift) { parts.append("Shift") }
        if flags.contains(.maskCommand) { parts.append("Command") }
        parts.append(keyDisplayName)
        return parts.joined(separator: " + ")
    }

    /// 供立体键帽渲染使用的分段数据。
    var keycapParts: [(symbol: String, title: String)] {
        var parts: [(symbol: String, title: String)] = []
        let flags = modifiers
        if flags.contains(.maskControl) { parts.append(("⌃", "Control")) }
        if flags.contains(.maskAlternate) { parts.append(("⌥", "Option")) }
        if flags.contains(.maskShift) { parts.append(("⇧", "Shift")) }
        if flags.contains(.maskCommand) { parts.append(("⌘", "Command")) }
        parts.append(("", keyDisplayName))
        return parts
    }

    /// 校验用户录制的组合键是否合法且安全。
    static func validate(keyCode: Int64, modifiers: CGEventFlags) -> Result<KeyCombo, KeyComboValidationError> {
        if modifierKeyCodes.contains(keyCode) {
            return .failure(.modifierOnly)
        }

        let clean = modifiers.intersection(relevantModifierMask)
        let hasPrimaryModifier = clean.contains(.maskControl) || clean.contains(.maskAlternate) || clean.contains(.maskCommand)
        if !hasPrimaryModifier {
            return .failure(.missingPrimaryModifier)
        }

        let combo = KeyCombo(keyCode: keyCode, flags: clean)
        if forbiddenShortcuts.contains(combo) {
            return .failure(.systemConflict(combo.displayString))
        }

        return .success(combo)
    }

    static func modifiers(from eventFlags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if eventFlags.contains(.control) { result.insert(.maskControl) }
        if eventFlags.contains(.option) { result.insert(.maskAlternate) }
        if eventFlags.contains(.command) { result.insert(.maskCommand) }
        if eventFlags.contains(.shift) { result.insert(.maskShift) }
        return result
    }

    private static let modifierKeyCodes: Set<Int64> = [
        54, 55, // Right/Left Command
        56, 60, // Left/Right Shift
        57,     // Caps Lock
        58, 61, // Left/Right Option
        59, 62, // Left/Right Control
        63,     // Fn
    ]

    private static let forbiddenShortcuts: Set<KeyCombo> = [
        KeyCombo(keyCode: 12, flags: [.maskCommand]),                 // ⌘Q
        KeyCombo(keyCode: 12, flags: [.maskControl, .maskCommand]),   // ⌃⌘Q (锁屏)
        KeyCombo(keyCode: 13, flags: [.maskCommand]),                 // ⌘W
        KeyCombo(keyCode: 48, flags: [.maskCommand]),                 // ⌘Tab
        KeyCombo(keyCode: 49, flags: [.maskCommand]),                 // ⌘Space
    ]

    static func keyName(for keyCode: Int64) -> String {
        if let name = keyCodeMap[keyCode] {
            return name
        }
        return "Key(\(keyCode))"
    }

    private static let keyCodeMap: [Int64: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        51: "Delete", 53: "Esc",
        64: "F17", 65: "Keypad .", 67: "Keypad *", 69: "Keypad +",
        71: "Clear", 75: "Keypad /", 76: "Enter", 78: "Keypad -",
        79: "F18", 80: "F19", 81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1",
        84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5",
        88: "Keypad 6", 89: "Keypad 7", 90: "F20", 91: "Keypad 8", 92: "Keypad 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "PageUp",
        117: "FwdDel", 118: "F4", 119: "End", 120: "F2", 121: "PageDown",
        122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

enum AppLanguage: String, Codable, CaseIterable, Equatable {
    case zhHans = "zh-Hans"
    case en = "en"
}

enum KeyComboValidationError: Error, Equatable {
    case modifierOnly
    case missingPrimaryModifier
    case systemConflict(String)

    var message: String {
        message(for: .zhHans)
    }

    func message(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.modifierOnly, .zhHans):
            return "请同时按下一个非修饰主键（如 L、K、Space 等）。"
        case (.modifierOnly, .en):
            return "Please include a non-modifier primary key (e.g., L, K, Space)."
        case (.missingPrimaryModifier, .zhHans):
            return "请至少包含 ⌃(Control)、⌥(Option) 或 ⌘(Command) 中的一个修饰键，以免影响正常打字。"
        case (.missingPrimaryModifier, .en):
            return "Include at least one primary modifier (⌃ Control, ⌥ Option, or ⌘ Command) so normal typing is unaffected."
        case (.systemConflict(let name), .zhHans):
            return "组合键 \(name) 与系统常用快捷键冲突，请换一个组合。"
        case (.systemConflict(let name), .en):
            return "Shortcut \(name) conflicts with a reserved system shortcut. Please choose another."
        }
    }
}

/// 应用偏好设置存储，支持依赖注入自定义 UserDefaults（便于测试）。
final class AppPreferences {
    private enum Keys {
        static let shortcutData = "CatKeyLock.shortcutData"
        static let lockLocalMouseToo = "CatKeyLock.lockLocalMouseToo"
        static let playSoundOnToggle = "CatKeyLock.playSoundOnToggle"
        static let hasLaunchedBefore = "CatKeyLock.hasLaunchedBefore"
        static let language = "CatKeyLock.language"
    }

    private let defaults: UserDefaults

    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shortcut: KeyCombo {
        get {
            guard let data = defaults.data(forKey: Keys.shortcutData),
                  let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data) else {
                return .defaultShortcut
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.shortcutData)
                onChange?()
            }
        }
    }

    /// 锁定时是否同时屏蔽内置触控板（保留原有键名以延续已保存的开关状态，不影响外接鼠标）
    var lockLocalMouseToo: Bool {
        get { defaults.bool(forKey: Keys.lockLocalMouseToo) }
        set {
            defaults.set(newValue, forKey: Keys.lockLocalMouseToo)
            onChange?()
        }
    }

    var playSoundOnToggle: Bool {
        get {
            if defaults.object(forKey: Keys.playSoundOnToggle) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.playSoundOnToggle)
        }
        set {
            defaults.set(newValue, forKey: Keys.playSoundOnToggle)
            onChange?()
        }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    var language: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: Keys.language),
                  let parsed = AppLanguage(rawValue: raw) else {
                return .zhHans
            }
            return parsed
        }
        set {
            guard newValue != language else { return }
            defaults.set(newValue.rawValue, forKey: Keys.language)
            onChange?()
        }
    }
}
