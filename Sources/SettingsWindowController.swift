import AppKit
import ServiceManagement
import SwiftUI

/// 设置窗口状态视图模型，支持真实运行时与离线预览快照两种模式。
final class SettingsViewModel: ObservableObject {
    struct PreviewState {
        var isAccessibilityGranted: Bool
        var isTapActive: Bool
        var isLocked: Bool
        var sessionBlockedCount: Int
        var totalBlockedCount: Int
        var shortcut: KeyCombo = .defaultShortcut
        var isRecordingShortcut: Bool = false
        var lockLocalMouseToo: Bool = false
        var playSoundOnToggle: Bool = true
        var launchAtLogin: Bool = false
        var language: AppLanguage = .zhHans
    }

    private let preferences: AppPreferences?
    private let lockManager: KeyboardLockManager?
    private var keyMonitor: Any?

    @Published var isAccessibilityGranted: Bool = false
    @Published var isTapActive: Bool = false
    @Published var isLocked: Bool = false
    @Published var sessionBlockedCount: Int = 0
    @Published var totalBlockedCount: Int = 0
    @Published var shortcut: KeyCombo = .defaultShortcut
    @Published var isRecordingShortcut: Bool = false
    @Published var language: AppLanguage = .zhHans
    @Published private(set) var hintState: ShortcutHintState = .idle
    @Published var lockLocalMouseToo: Bool = false
    @Published var playSoundOnToggle: Bool = true
    @Published var launchAtLogin: Bool = false
    @Published private var launchErrorDetail: String?

    var statusHintText: String {
        L10n.shortcutHint(state: hintState, language)
    }

    var statusHintIsError: Bool {
        if case .validationError = hintState {
            return true
        }
        return false
    }

    var launchErrorMessage: String? {
        guard let detail = launchErrorDetail else { return nil }
        return L10n.launchError(detail, language)
    }

    init(preferences: AppPreferences, lockManager: KeyboardLockManager) {
        self.preferences = preferences
        self.lockManager = lockManager
        refreshFromModel()
    }

    init(previewState: PreviewState) {
        self.preferences = nil
        self.lockManager = nil
        self.isAccessibilityGranted = previewState.isAccessibilityGranted
        self.isTapActive = previewState.isTapActive
        self.isLocked = previewState.isLocked
        self.sessionBlockedCount = previewState.sessionBlockedCount
        self.totalBlockedCount = previewState.totalBlockedCount
        self.shortcut = previewState.shortcut
        self.isRecordingShortcut = previewState.isRecordingShortcut
        self.lockLocalMouseToo = previewState.lockLocalMouseToo
        self.playSoundOnToggle = previewState.playSoundOnToggle
        self.launchAtLogin = previewState.launchAtLogin
        self.language = previewState.language
    }

    deinit {
        stopRecordingShortcut(resetHint: false)
    }

    func refreshFromModel() {
        guard let preferences = preferences, let lockManager = lockManager else { return }
        isAccessibilityGranted = lockManager.isAccessibilityGranted
        isTapActive = lockManager.isTapActive
        isLocked = lockManager.stateMachine.isLocked
        sessionBlockedCount = lockManager.stateMachine.blockedCountThisSession
        totalBlockedCount = lockManager.stateMachine.totalBlockedCount
        if !isRecordingShortcut {
            shortcut = preferences.shortcut
        }
        language = preferences.language
        lockLocalMouseToo = preferences.lockLocalMouseToo
        playSoundOnToggle = preferences.playSoundOnToggle
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        language = newLanguage
        preferences?.language = newLanguage
    }

    func openAccessibilitySettings() {
        guard let lockManager = lockManager else { return }
        _ = lockManager.checkAccessibility(prompt: true)
        lockManager.openAccessibilityPreferences()
    }

    func resetAccessibilityPermission() {
        lockManager?.resetAccessibilityAndReprompt()
    }

    func toggleLock() {
        guard let lockManager = lockManager else {
            isLocked.toggle()
            return
        }
        lockManager.stateMachine.toggleFromUI()
        refreshFromModel()
    }

    func startOrCancelRecording() {
        if isRecordingShortcut {
            stopRecordingShortcut(resetHint: true)
            return
        }

        isRecordingShortcut = true
        lockManager?.stateMachine.isRecordingShortcut = true
        hintState = .recording

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecordingShortcut else { return event }

            // Esc 取消录制
            if event.keyCode == 53 && event.modifierFlags.intersection([.control, .option, .command, .shift]).isEmpty {
                self.stopRecordingShortcut(resetHint: true)
                return nil
            }

            let modifiers = KeyCombo.modifiers(from: event.modifierFlags)
            switch KeyCombo.validate(keyCode: Int64(event.keyCode), modifiers: modifiers) {
            case .success(let combo):
                self.shortcut = combo
                self.preferences?.shortcut = combo
                self.stopRecordingShortcut(resetHint: false)
                self.hintState = .updated(combo)
                self.refreshFromModel()
            case .failure(let error):
                self.hintState = .validationError(error)
            }

            return nil
        }
    }

    func stopRecordingShortcut(resetHint: Bool) {
        isRecordingShortcut = false
        lockManager?.stateMachine.isRecordingShortcut = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if resetHint {
            hintState = .idle
        }
    }

    func resetShortcutToDefault() {
        stopRecordingShortcut(resetHint: false)
        shortcut = .defaultShortcut
        preferences?.shortcut = .defaultShortcut
        hintState = .restoredDefault(.defaultShortcut)
        refreshFromModel()
    }

    func setLockLocalMouseToo(_ newValue: Bool) {
        lockLocalMouseToo = newValue
        preferences?.lockLocalMouseToo = newValue
    }

    func setPlaySoundOnToggle(_ newValue: Bool) {
        playSoundOnToggle = newValue
        preferences?.playSoundOnToggle = newValue
    }

    func setLaunchAtLogin(_ newValue: Bool) {
        guard preferences != nil else {
            launchAtLogin = newValue
            return
        }
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchErrorDetail = nil
        } catch {
            launchErrorDetail = error.localizedDescription
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }
}

// MARK: - SwiftUI 界面

struct SettingsContentView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TopUtilityBar(
                language: viewModel.language,
                onSelectLanguage: { viewModel.setLanguage($0) }
            )

            HeroStatusBanner(
                isLocked: viewModel.isLocked,
                shortcutDisplay: viewModel.shortcut.displayString,
                isReady: viewModel.isAccessibilityGranted && viewModel.isTapActive,
                language: viewModel.language,
                onToggleLock: { viewModel.toggleLock() }
            )

            HStack(spacing: 12) {
                StatMiniCard(
                    symbolName: "pawprint.fill",
                    symbolColor: .orange,
                    title: L10n.statSessionTitle(viewModel.language),
                    value: L10n.statCountValue(viewModel.sessionBlockedCount, viewModel.language)
                )
                StatMiniCard(
                    symbolName: "shield.checkered",
                    symbolColor: .blue,
                    title: L10n.statTotalTitle(viewModel.language),
                    value: L10n.statCountValue(viewModel.totalBlockedCount, viewModel.language)
                )
            }

            PermissionStatusCard(
                isGranted: viewModel.isAccessibilityGranted,
                isTapActive: viewModel.isTapActive,
                language: viewModel.language,
                onOpenSettings: { viewModel.openAccessibilitySettings() },
                onResetPermission: { viewModel.resetAccessibilityPermission() }
            )

            ShortcutKeycapCard(
                shortcut: viewModel.shortcut,
                isRecording: viewModel.isRecordingShortcut,
                hintText: viewModel.statusHintText,
                hintIsError: viewModel.statusHintIsError,
                language: viewModel.language,
                onRecordToggle: { viewModel.startOrCancelRecording() },
                onResetDefault: { viewModel.resetShortcutToDefault() }
            )

            PreferencesGroupCard(viewModel: viewModel)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .frame(width: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TopUtilityBar: View {
    let language: AppLanguage
    let onSelectLanguage: (AppLanguage) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.versionBadge)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 2) {
                Image(systemName: "globe")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 7)
                    .padding(.trailing, 3)

                LanguageSegmentButton(
                    title: "中文",
                    isSelected: language == .zhHans,
                    action: { onSelectLanguage(.zhHans) }
                )

                LanguageSegmentButton(
                    title: "EN",
                    isSelected: language == .en,
                    action: { onSelectLanguage(.en) }
                )
            }
            .padding(2.5)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
        }
    }
}

private struct LanguageSegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HeroStatusBanner: View {
    let isLocked: Bool
    let shortcutDisplay: String
    let isReady: Bool
    let language: AppLanguage
    let onToggleLock: () -> Void

    private var gradientColors: [Color] {
        if isLocked {
            return [
                Color(red: 0.80, green: 0.34, blue: 0.07),
                Color(red: 0.93, green: 0.50, blue: 0.12),
            ]
        }
        return [
            Color(red: 0.13, green: 0.25, blue: 0.46),
            Color(red: 0.20, green: 0.40, blue: 0.68),
        ]
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: isLocked ? "lock.shield.fill" : "cat.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.heroTitle(locked: isLocked, language))
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.heroSubtitle(locked: isLocked, shortcut: shortcutDisplay, language))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            let canInteract = isReady || isLocked
            Button(action: onToggleLock) {
                Text(L10n.heroActionTitle(locked: isLocked, canInteract: canInteract, language))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(
                        !canInteract
                            ? Color.white.opacity(0.82)
                            : (isLocked ? Color(red: 0.72, green: 0.28, blue: 0.04) : Color(red: 0.12, green: 0.24, blue: 0.45))
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(canInteract ? Color.white : Color.white.opacity(0.18)))
                    .shadow(color: canInteract ? .black.opacity(0.14) : .clear, radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!canInteract)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct StatMiniCard: View {
    let symbolName: String
    let symbolColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(symbolColor.opacity(0.13))
                )

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct PermissionStatusCard: View {
    let isGranted: Bool
    let isTapActive: Bool
    let language: AppLanguage
    let onOpenSettings: () -> Void
    let onResetPermission: () -> Void

    private var isReady: Bool { isGranted && isTapActive }

    var body: some View {
        if isReady {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.green)

                Text(L10n.permReadyText(language))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(L10n.permRemoteBadge(language))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.14)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.green.opacity(0.30), lineWidth: 1)
            )
        } else {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.permPendingTitle(isGranted: isGranted, language))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(L10n.permPendingBody(language))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                VStack(spacing: 6) {
                    Button(L10n.permOpenButton(language), action: onOpenSettings)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)

                    Button(L10n.permResetButton(language), action: onResetPermission)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.orange.opacity(0.38), lineWidth: 1)
            )
        }
    }
}

private struct ShortcutKeycapCard: View {
    let shortcut: KeyCombo
    let isRecording: Bool
    let hintText: String
    let hintIsError: Bool
    let language: AppLanguage
    let onRecordToggle: () -> Void
    let onResetDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.blue)
                Text(L10n.shortcutCardTitle(language))
                    .font(.system(size: 13.5, weight: .semibold))

                Spacer()

                Button(L10n.shortcutResetDefault(language), action: onResetDefault)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(action: onRecordToggle) {
                    Text(L10n.shortcutRecordButton(isRecording: isRecording, language))
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .orange : .accentColor)
                .controlSize(.small)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isRecording ? Color.orange.opacity(0.08) : Color.primary.opacity(0.04))
                    .frame(minHeight: 56)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isRecording ? Color.orange.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35),
                        style: isRecording ? StrokeStyle(lineWidth: 1.5, dash: [5, 4]) : StrokeStyle(lineWidth: 1)
                    )
                    .frame(minHeight: 56)

                if isRecording {
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle")
                            .foregroundStyle(.orange)
                        Text(L10n.shortcutRecordingPlaceholder(language))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                } else {
                    HStack(spacing: 7) {
                        let parts = shortcut.keycapParts
                        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                            if index > 0 {
                                Text("+")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            KeycapBadge(symbol: part.symbol, title: part.title)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            Text(hintText)
                .font(.system(size: 11.5))
                .foregroundStyle(hintIsError ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct KeycapBadge: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            if !symbol.isEmpty {
                Text(symbol)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 0, x: 0, y: 2)
    }
}

private struct PreferencesGroupCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OptionRow(
                symbolName: "hand.tap.fill",
                iconColor: .purple,
                title: L10n.optTrackpadTitle(viewModel.language),
                subtitle: L10n.optTrackpadSubtitle(viewModel.language),
                isOn: Binding(
                    get: { viewModel.lockLocalMouseToo },
                    set: { viewModel.setLockLocalMouseToo($0) }
                )
            )

            Divider()
                .padding(.leading, 54)

            OptionRow(
                symbolName: "speaker.wave.2.fill",
                iconColor: .teal,
                title: L10n.optSoundTitle(viewModel.language),
                subtitle: L10n.optSoundSubtitle(viewModel.language),
                isOn: Binding(
                    get: { viewModel.playSoundOnToggle },
                    set: { viewModel.setPlaySoundOnToggle($0) }
                )
            )

            Divider()
                .padding(.leading, 54)

            OptionRow(
                symbolName: "bolt.horizontal.circle.fill",
                iconColor: .green,
                title: L10n.optLoginTitle(viewModel.language),
                subtitle: L10n.optLoginSubtitle(viewModel.language),
                isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                )
            )

            if let errorMessage = viewModel.launchErrorMessage {
                Text(errorMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct OptionRow: View {
    let symbolName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.gradient)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - 窗口控制器

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: SettingsViewModel
    private let hostingController: NSHostingController<SettingsContentView>

    init(preferences: AppPreferences, lockManager: KeyboardLockManager) {
        let vm = SettingsViewModel(preferences: preferences, lockManager: lockManager)
        self.viewModel = vm

        let hc = NSHostingController(rootView: SettingsContentView(viewModel: vm))
        hc.sizingOptions = []
        self.hostingController = hc

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 610),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.windowTitle(vm.language)
        window.isReleasedWhenClosed = false
        window.contentViewController = hc

        super.init(window: window)
        window.delegate = self

        updateWindowSizeToFit()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        refreshUI()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.stopRecordingShortcut(resetHint: true)
    }

    func refreshUI() {
        viewModel.refreshFromModel()
        window?.title = L10n.windowTitle(viewModel.language)
        updateWindowSizeToFit()
    }

    private func updateWindowSizeToFit() {
        guard let window = window else { return }
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingHeight = hostingController.view.fittingSize.height
        let targetSize = NSSize(width: 500, height: max(540, fittingHeight))
        window.setContentSize(targetSize)
    }
}
