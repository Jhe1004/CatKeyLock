import AppKit
import SwiftUI

struct CoverPosterView: View {
    let backgroundImage: NSImage
    var isEnglish: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            // 1. 精修猫咪背景图满铺 1280x640（顶部对齐并微调留出完整小皇冠）
            Image(nsImage: backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1280, height: 640, alignment: .top)
                .clipped()

            // 2. 左侧柔和暗色渐变遮罩（保障文字高对比度，右侧保持猫咪与屏幕原貌通透）
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.90), location: 0.0),
                    .init(color: Color(red: 0.06, green: 0.08, blue: 0.13).opacity(0.76), location: 0.34),
                    .init(color: Color(red: 0.06, green: 0.08, blue: 0.13).opacity(0.18), location: 0.56),
                    .init(color: Color.clear, location: 0.72),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // 3. 左侧排版区
            VStack(alignment: .leading, spacing: 0) {
                // 顶部胶囊徽章
                HStack(spacing: 8) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.28))
                    Text("macOS HID Input Isolation Utility")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.45))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                )

                Spacer().frame(height: 24)

                // 超大主标题
                Text("CatKeyLock")
                    .font(.system(size: 68, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.90)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 4)

                Spacer().frame(height: 10)

                // 副标题
                Text(
                    isEnglish
                        ? "Selective Input-Layer Isolation Against\nStochastic Feline (Felis catus) Contact"
                        : "面向偶发性猫科动物接触的输入层隔离工具"
                )
                    .font(.system(size: isEnglish ? 20.5 : 23.5, weight: .bold))
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 14)

                Text(
                    isEnglish
                        ? "Quartz Event Tap routing that drops built-in keyboard & trackpad\nloads while preserving external mice and remote desktop sessions."
                        : "基于 Quartz Event Tap 实现硬件输入源精准分流：\n阻断内置键盘与触控板载荷，保留外接鼠标与远程会话控制。"
                )
                    .font(.system(size: isEnglish ? 14.5 : 16, weight: .medium))
                    .lineSpacing(isEnglish ? 4 : 5)
                    .foregroundStyle(Color.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 30)

                // 立体键帽徽章组
                HStack(spacing: 8) {
                    CoverKeycap(symbol: "⌃", label: "Control")
                    Text("+")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    CoverKeycap(symbol: "⌥", label: "Option")
                    Text("+")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    CoverKeycap(symbol: "⌘", label: "Command")
                    Text("+")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    CoverKeycap(symbol: "", label: "L", accent: true)
                }

                Spacer().frame(height: 14)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.orange.opacity(0.85))
                    Text(
                        isEnglish
                            ? "PID-Based HID Routing · Subtype Discrimination · Modifier Drain"
                            : "PID 级硬件/远控分流 · 触控子类型判别 · 修饰键渐进释放"
                    )
                        .font(.system(size: isEnglish ? 13 : 13.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.70))
                }
            }
            .padding(.leading, 56)
            .padding(.vertical, 56)
            .frame(maxWidth: 600, alignment: .leading)
        }
        .frame(width: 1280, height: 640)
    }
}

private struct CoverKeycap: View {
    let symbol: String
    let label: String
    var accent: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if !symbol.isEmpty {
                Text(symbol)
                    .font(.system(size: 15, weight: .bold))
            }
            Text(label)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(accent ? .white : Color(white: 0.96))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    accent
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.96, green: 0.52, blue: 0.14), Color(red: 0.85, green: 0.36, blue: 0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        : AnyShapeStyle(Color(red: 0.16, green: 0.19, blue: 0.25).opacity(0.92))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    accent ? Color.orange.opacity(0.75) : Color.white.opacity(0.24),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 3)
    }
}

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: make_readme_assets.swift <input_bg> <output_cover.png> [zh|en]\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let lang = CommandLine.arguments.count >= 4 ? CommandLine.arguments[3].lowercased() : "zh"
let isEnglish = (lang == "en")

guard let bgImage = NSImage(contentsOf: inputURL) else {
    fputs("Failed to load background image at \(inputURL.path)\n", stderr)
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
NSApp.appearance = NSAppearance(named: .darkAqua)

let hosting = NSHostingView(rootView: CoverPosterView(backgroundImage: bgImage, isEnglish: isEnglish))
hosting.frame = NSRect(x: 0, y: 0, width: 1280, height: 640)
hosting.layoutSubtreeIfNeeded()

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1280,
    pixelsHigh: 640,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to allocate 1280x640 bitmap\n", stderr)
    exit(1)
}
rep.size = NSSize(width: 1280, height: 640)
hosting.cacheDisplay(in: hosting.bounds, to: rep)

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try data.write(to: outputURL)
print("Generated cover poster: \(outputURL.path) (1280x640)")
