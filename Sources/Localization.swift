import Foundation

enum ShortcutHintState: Equatable {
    case idle
    case recording
    case updated(KeyCombo)
    case restoredDefault(KeyCombo)
    case validationError(KeyComboValidationError)
}

/// 集中管理应用内的中英文界面文案（默认简体中文，可实时切换为英文）。
enum L10n {
    // MARK: - 窗口与版本

    static func windowTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "防猫锁键 (CatKeyLock)"
        case .en: return "CatKeyLock"
        }
    }

    static let versionBadge = "CatKeyLock v1.1.0"

    // MARK: - 系统菜单栏与下拉菜单

    static func statusBarAccessibilityDescription(locked: Bool, ready: Bool, lang: AppLanguage) -> String {
        switch lang {
        case .zhHans:
            if locked { return "物理键盘已锁定" }
            return ready ? "防猫锁键待命中" : "等待辅助功能授权"
        case .en:
            if locked { return "Built-in Keyboard Locked" }
            return ready ? "CatKeyLock Standby" : "Accessibility Permission Required"
        }
    }

    static func statusBarButtonLockedTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return " 已锁键"
        case .en: return " Locked"
        }
    }

    static func statusBarButtonSetupTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return " 待授权"
        case .en: return " Setup"
        }
    }

    static func statusBarTooltipLocked(shortcut: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "防猫锁键：物理键盘已锁定（按 \(shortcut) 解锁）"
        case .en: return "CatKeyLock: Built-in keyboard locked (press \(shortcut) to unlock)"
        }
    }

    static func statusBarTooltipSetup(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "防猫锁键：尚未授予辅助功能权限，点击打开设置"
        case .en: return "CatKeyLock: Accessibility permission required. Click to open settings."
        }
    }

    static func statusBarTooltipStandby(shortcut: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "防猫锁键：按 \(shortcut) 锁定本地物理键盘"
        case .en: return "CatKeyLock: Press \(shortcut) to lock built-in keyboard"
        }
    }

    static func menuStatusUnauthorized(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "⚠️ 需授予“辅助功能”权限（点击前往设置）"
        case .en: return "⚠️ Accessibility Permission Required (Click to Configure)"
        }
    }

    static func menuStatusLocked(blocked: Int, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "🔒 已锁定本地键盘（本次拦截 \(blocked) 次）"
        case .en: return "🔒 Keyboard Locked (\(blocked) blocked this session)"
        }
    }

    static func menuStatusNormal(shortcut: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "⌨️ 本地键盘正常（快捷键 \(shortcut)）"
        case .en: return "⌨️ Keyboard Active (Shortcut: \(shortcut))"
        }
    }

    static func menuToggleUnlock(shortcut: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "解锁物理键盘（\(shortcut)）"
        case .en: return "Unlock Built-in Keyboard (\(shortcut))"
        }
    }

    static func menuToggleLock(shortcut: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "立即锁定物理键盘（\(shortcut)）"
        case .en: return "Lock Built-in Keyboard Now (\(shortcut))"
        }
    }

    static func menuBlockTrackpad(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "锁定时同时屏蔽内置触控板（不影响鼠标）"
        case .en: return "Also Block Built-in Trackpad (External Mouse Unaffected)"
        }
    }

    static func menuPlaySound(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "切换时播放提示音"
        case .en: return "Play Sound on Toggle"
        }
    }

    static func menuLanguageTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "界面语言 (Language)"
        case .en: return "Language (界面语言)"
        }
    }

    static func menuSettings(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "快捷键与权限设置..."
        case .en: return "Settings & Permissions..."
        }
    }

    static func menuLaunchAtLogin(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "开机自动启动"
        case .en: return "Launch at Login"
        }
    }

    static func menuQuit(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "退出防猫锁键"
        case .en: return "Quit CatKeyLock"
        }
    }

    // MARK: - 设置主面板

    static func heroTitle(locked: Bool, _ lang: AppLanguage) -> String {
        switch (locked, lang) {
        case (true, .zhHans): return "防猫模式运行中 · 键盘已锁定"
        case (true, .en): return "Isolation Active · Keyboard Locked"
        case (false, .zhHans): return "本地键盘正常输入中"
        case (false, .en): return "Built-in Keyboard Active"
        }
    }

    static func heroSubtitle(locked: Bool, shortcut: String, _ lang: AppLanguage) -> String {
        switch (locked, lang) {
        case (true, .zhHans): return "远程控制正常可用 · 再按 \(shortcut) 解锁"
        case (true, .en): return "Remote control active · Press \(shortcut) again to unlock"
        case (false, .zhHans): return "防猫待命 · 按 \(shortcut) 瞬间锁定物理键盘"
        case (false, .en): return "Standby · Press \(shortcut) to lock built-in keyboard"
        }
    }

    static func heroActionTitle(locked: Bool, canInteract: Bool, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans:
            if locked { return "解锁键盘" }
            return canInteract ? "立即锁定" : "待授权"
        case .en:
            if locked { return "Unlock" }
            return canInteract ? "Lock Now" : "Authorize"
        }
    }

    static func statSessionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "本次锁定拦截"
        case .en: return "Blocked (Session)"
        }
    }

    static func statTotalTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "累计防猫拦截"
        case .en: return "Blocked (Total)"
        }
    }

    static func statCountValue(_ count: Int, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "\(count) 次"
        case .en: return "\(count)"
        }
    }

    static func permReadyText(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "辅助功能权限已就绪 · 全局锁键监听运行中"
        case .en: return "Accessibility Ready · Global Event Tap Active"
        }
    }

    static func permRemoteBadge(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "远控自动放行"
        case .en: return "Remote Allowed"
        }
    }

    static func permPendingTitle(isGranted: Bool, _ lang: AppLanguage) -> String {
        switch (isGranted, lang) {
        case (true, .zhHans): return "已获授权，等待事件监听器重连"
        case (true, .en): return "Authorized · Waiting for Event Tap"
        case (false, .zhHans): return "需要开启 macOS 辅助功能权限"
        case (false, .en): return "macOS Accessibility Permission Required"
        }
    }

    static func permPendingBody(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans:
            return "请在“系统设置 → 隐私与安全性 → 辅助功能”中开启「CatKeyLock」开关（开启后 1 秒内自动生效；若开关已开启但仍不生效，请点击右侧“重置记录”重新弹窗授权）。"
        case .en:
            return "Enable \"CatKeyLock\" in System Settings → Privacy & Security → Accessibility (activates within 1s; if already on after an update, click \"Reset TCC\" to re-authorize)."
        }
    }

    static func permOpenButton(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "去开启权限"
        case .en: return "Open Settings"
        }
    }

    static func permResetButton(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "重置记录"
        case .en: return "Reset TCC"
        }
    }

    static func shortcutCardTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "锁定 / 解锁组合键"
        case .en: return "Lock / Unlock Shortcut"
        }
    }

    static func shortcutResetDefault(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "恢复默认"
        case .en: return "Reset Default"
        }
    }

    static func shortcutRecordButton(isRecording: Bool, _ lang: AppLanguage) -> String {
        switch (isRecording, lang) {
        case (true, .zhHans): return "取消录制 (Esc)"
        case (true, .en): return "Cancel (Esc)"
        case (false, .zhHans): return "录制新组合键"
        case (false, .en): return "Record Shortcut"
        }
    }

    static func shortcutRecordingPlaceholder(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "请按下包含 ⌃ / ⌥ / ⌘ 的新组合键…（按 Esc 取消）"
        case .en: return "Press a new shortcut with ⌃ / ⌥ / ⌘… (Esc to cancel)"
        }
    }

    static func shortcutHint(state: ShortcutHintState, _ lang: AppLanguage) -> String {
        switch state {
        case .idle:
            switch lang {
            case .zhHans: return "按下该组合键即可瞬间锁定物理键盘，只有再次按下同一组合键才能解锁。"
            case .en: return "Press this shortcut to lock the built-in keyboard. Repeat the same chord to unlock."
            }
        case .recording:
            switch lang {
            case .zhHans: return "请直接按下新组合键（至少包含 ⌃ / ⌥ / ⌘ 之一），按 Esc 取消。"
            case .en: return "Press a new key combination (with at least ⌃, ⌥, or ⌘). Press Esc to cancel."
            }
        case .updated(let combo):
            switch lang {
            case .zhHans: return "已更新为 \(combo.displayString)（\(combo.humanReadableDescription)）。"
            case .en: return "Updated to \(combo.displayString) (\(combo.humanReadableDescription))."
            }
        case .restoredDefault(let combo):
            switch lang {
            case .zhHans: return "已恢复默认组合键：\(combo.displayString)（\(combo.humanReadableDescription)）。"
            case .en: return "Restored default shortcut: \(combo.displayString) (\(combo.humanReadableDescription))."
            }
        case .validationError(let error):
            return error.message(for: lang)
        }
    }

    static func optTrackpadTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "同时屏蔽内置触控板"
        case .en: return "Also Block Built-in Trackpad"
        }
    }

    static func optTrackpadSubtitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "防猫踩踏触控板误触；外接鼠标与远程控制鼠标均正常可用"
        case .en: return "Prevents paw touches on the trackpad; external mice and remote pointers remain active"
        }
    }

    static func optSoundTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "切换状态时播放轻柔提示音"
        case .en: return "Play Subtle Sound on Toggle"
        }
    }

    static func optSoundSubtitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "锁定时播放清脆提示音，解锁时播放柔和音效"
        case .en: return "Plays a crisp chime when locking and a soft tone when unlocking"
        }
    }

    static func optLoginTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "开机登录时自动启动"
        case .en: return "Launch Automatically at Login"
        }
    }

    static func optLoginSubtitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "登录桌面后静默驻留右上角菜单栏随时待命"
        case .en: return "Runs silently in the menu bar after signing in to macOS"
        }
    }

    static func launchError(_ detail: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans: return "无法更新开机自动启动：\(detail)"
        case .en: return "Failed to update Launch at Login: \(detail)"
        }
    }

    // MARK: - 顶部毛玻璃 HUD

    static func hudTitle(locked: Bool, mouseLocked: Bool, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans:
            if locked {
                return mouseLocked ? "物理键盘与触控板已锁定" : "物理键盘已锁定（防猫模式）"
            }
            return "物理键盘已解锁"
        case .en:
            if locked {
                return mouseLocked ? "Keyboard & Trackpad Locked" : "Built-in Keyboard Locked"
            }
            return "Built-in Keyboard Unlocked"
        }
    }

    static func hudSubtitle(locked: Bool, mouseLocked: Bool, shortcut: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .zhHans:
            if locked {
                return mouseLocked
                    ? "外接鼠标与远程控制正常可用 · 再按 \(shortcut) 解锁"
                    : "远程控制正常可用 · 再按 \(shortcut) 解锁"
            }
            return "本地键盘输入已恢复正常"
        case .en:
            if locked {
                return mouseLocked
                    ? "External mouse & remote active · Press \(shortcut) to unlock"
                    : "Remote control active · Press \(shortcut) to unlock"
            }
            return "Local keyboard & trackpad input restored"
        }
    }
}
