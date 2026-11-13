import AppKit
import SwiftUI

struct HUDBannerView: View {
    let locked: Bool
    let shortcutDisplay: String
    let mouseLocked: Bool

    private var accentColor: Color {
        locked ? .orange : .green
    }

    private var titleText: String {
        if locked {
            return mouseLocked ? "物理键盘与触控板已锁定" : "物理键盘已锁定（防猫模式）"
        }
        return "物理键盘已解锁"
    }

    private var subtitleText: String {
        if locked {
            return mouseLocked
                ? "外接鼠标与远程控制正常可用 · 再按 \(shortcutDisplay) 解锁"
                : "远程控制正常可用 · 再按 \(shortcutDisplay) 解锁"
        }
        return "本地键盘输入已恢复正常"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(shortcutDisplay)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(accentColor.opacity(0.28), lineWidth: 0.75)
                )
        }
        .padding(.horizontal, 16)
        .frame(width: 420, height: 76)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.20), radius: 14, x: 0, y: 6)
    }
}

/// 顶部居中悬浮毛玻璃提示条（不抢占焦点，不影响任何前台窗口输入）。
final class HUDController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<HUDBannerView>?
    private var hideWorkItem: DispatchWorkItem?

    func show(locked: Bool, shortcutDisplay: String, mouseLocked: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.presentHUD(locked: locked, shortcutDisplay: shortcutDisplay, mouseLocked: mouseLocked)
        }
    }

    private func presentHUD(locked: Bool, shortcutDisplay: String, mouseLocked: Bool) {
        hideWorkItem?.cancel()

        let banner = HUDBannerView(
            locked: locked,
            shortcutDisplay: shortcutDisplay,
            mouseLocked: mouseLocked
        )
        let panel = ensurePanel(initialView: banner)
        hostingView?.rootView = banner

        positionPanelOnActiveScreen(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1.0
        }

        let delay: TimeInterval = locked ? 2.0 : 1.5
        let item = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func fadeOut() {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.28
            panel.animator().alphaValue = 0
        }, completionHandler: {
            if panel.alphaValue == 0 {
                panel.orderOut(nil)
            }
        })
    }

    private func positionPanelOnActiveScreen(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let targetScreen = screen else { return }

        let visible = targetScreen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 28
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func ensurePanel(initialView: HUDBannerView) -> NSPanel {
        if let existing = panel {
            return existing
        }

        let width: CGFloat = 420
        let height: CGFloat = 76
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .statusBar
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = false
        newPanel.ignoresMouseEvents = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let hosting = NSHostingView(rootView: initialView)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        newPanel.contentView = hosting

        self.panel = newPanel
        self.hostingView = hosting
        return newPanel
    }
}
