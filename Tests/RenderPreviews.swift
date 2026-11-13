import AppKit
import SwiftUI

func renderViewToPNG<V: View>(_ view: V, appearanceName: NSAppearance.Name, width: CGFloat? = nil, outputURL: URL) {
    let appearance = NSAppearance(named: appearanceName)
    NSApp.appearance = appearance

    let hosting = NSHostingView(rootView: view)
    hosting.appearance = appearance
    let fitting = hosting.fittingSize
    let targetWidth = width ?? fitting.width
    hosting.frame = NSRect(x: 0, y: 0, width: targetWidth, height: fitting.height)
    hosting.layoutSubtreeIfNeeded()

    // 再根据最新宽度重算高度
    let finalSize = NSSize(width: targetWidth, height: hosting.fittingSize.height)
    hosting.frame = NSRect(origin: .zero, size: finalSize)
    hosting.layoutSubtreeIfNeeded()

    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        fputs("Failed to create bitmapImageRep for \(outputURL.lastPathComponent)\n", stderr)
        exit(1)
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to encode PNG for \(outputURL.lastPathComponent)\n", stderr)
        exit(1)
    }
    try! data.write(to: outputURL)
    print("Rendered \(outputURL.lastPathComponent): \(Int(finalSize.width))x\(Int(finalSize.height))")
}

@main
struct RenderPreviews {
    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            fputs("Usage: RenderPreviews <output_dir>\n", stderr)
            exit(1)
        }
        let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
        try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // 1. 浅色 - 待授权态
        let vm1 = SettingsViewModel(previewState: .init(
            isAccessibilityGranted: false,
            isTapActive: false,
            isLocked: false,
            sessionBlockedCount: 0,
            totalBlockedCount: 0
        ))
        renderViewToPNG(
            SettingsContentView(viewModel: vm1),
            appearanceName: .aqua,
            width: 500,
            outputURL: outDir.appendingPathComponent("preview_unauthorized_light.png")
        )

        // 2. 浅色 - 已授权待命态
        let vm2 = SettingsViewModel(previewState: .init(
            isAccessibilityGranted: true,
            isTapActive: true,
            isLocked: false,
            sessionBlockedCount: 0,
            totalBlockedCount: 38,
            playSoundOnToggle: true,
            launchAtLogin: true
        ))
        renderViewToPNG(
            SettingsContentView(viewModel: vm2),
            appearanceName: .aqua,
            width: 500,
            outputURL: outDir.appendingPathComponent("preview_ready_light.png")
        )

        // 3. 深色 - 防猫锁定中且拦截 12 次
        let vm3 = SettingsViewModel(previewState: .init(
            isAccessibilityGranted: true,
            isTapActive: true,
            isLocked: true,
            sessionBlockedCount: 12,
            totalBlockedCount: 147,
            lockLocalMouseToo: true,
            playSoundOnToggle: true
        ))
        renderViewToPNG(
            SettingsContentView(viewModel: vm3),
            appearanceName: .darkAqua,
            width: 500,
            outputURL: outDir.appendingPathComponent("preview_locked_dark.png")
        )

        // 4. 悬浮 HUD 锁定提示条
        let hudDemo = ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.20), Color(red: 0.16, green: 0.20, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            HUDBannerView(locked: true, shortcutDisplay: "⌃⌥⌘L", mouseLocked: false)
                .padding(24)
        }
        renderViewToPNG(
            hudDemo,
            appearanceName: .darkAqua,
            outputURL: outDir.appendingPathComponent("preview_hud_locked.png")
        )
    }
}
