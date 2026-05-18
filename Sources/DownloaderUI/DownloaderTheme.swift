import DownloaderCore
import SwiftUI

struct DownloaderThemeStyle {
    let preset: DownloaderThemePreset
    let isLight: Bool
    let tint: Color
    let secondaryTint: Color
    let tertiaryTint: Color
    let success: Color
    let warning: Color
    let danger: Color
    let canvasBase: Color
    let canvasEdge: Color
    let panelTint: Color
    let panelStroke: Color
    let heroStart: Color
    let heroMid: Color
    let heroEnd: Color
    let heroPrimaryText: Color
    let heroSecondaryText: Color
    let bodyText: Color
    let mutedText: Color
    let shadowColor: Color

    init(preset: DownloaderThemePreset) {
        self.preset = preset

        switch preset {
        case .skdMidnight:
            isLight = false
            tint = Color(hex: 0x69F5BE)
            secondaryTint = Color(hex: 0x52C7FF)
            tertiaryTint = Color(hex: 0xFFBC66)
            success = Color(hex: 0x6DE4A5)
            warning = Color(hex: 0xFFBC66)
            danger = Color(hex: 0xFF7A6B)
            canvasBase = Color(hex: 0x071118)
            canvasEdge = Color(hex: 0x0B1720)
            panelTint = Color(hex: 0x7CEFD4)
            panelStroke = Color.white.opacity(0.08)
            heroStart = Color(hex: 0x0F2330)
            heroMid = Color(hex: 0x10362F)
            heroEnd = Color(hex: 0x18231A)
            heroPrimaryText = .white
            heroSecondaryText = Color.white.opacity(0.76)
            bodyText = Color(hex: 0xF2F6F7)
            mutedText = Color(hex: 0xA9B8BC)
            shadowColor = Color.black.opacity(0.34)
        case .raycastPulse:
            isLight = false
            tint = Color(hex: 0x55B3FF)
            secondaryTint = Color(hex: 0xFF6363)
            tertiaryTint = Color(hex: 0xFFBC33)
            success = Color(hex: 0x5FC992)
            warning = Color(hex: 0xFFBC33)
            danger = Color(hex: 0xFF6363)
            canvasBase = Color(hex: 0x07080A)
            canvasEdge = Color(hex: 0x111317)
            panelTint = Color(hex: 0x58AFFF)
            panelStroke = Color.white.opacity(0.08)
            heroStart = Color(hex: 0x111317)
            heroMid = Color(hex: 0x171B20)
            heroEnd = Color(hex: 0x1F1820)
            heroPrimaryText = .white
            heroSecondaryText = Color(hex: 0xCDD1D6)
            bodyText = Color(hex: 0xF7F9FA)
            mutedText = Color(hex: 0xA4AAB1)
            shadowColor = Color.black.opacity(0.38)
        case .linearLight:
            isLight = true
            tint = Color(hex: 0x5E6AD2)
            secondaryTint = Color(hex: 0x3E8CF7)
            tertiaryTint = Color(hex: 0x11A4A3)
            success = Color(hex: 0x2AA871)
            warning = Color(hex: 0xD68A00)
            danger = Color(hex: 0xD94A5B)
            canvasBase = Color(hex: 0xF6F7FB)
            canvasEdge = Color(hex: 0xEBEEF5)
            panelTint = Color(hex: 0xB8C0FF)
            panelStroke = Color.black.opacity(0.08)
            heroStart = Color(hex: 0xFFFFFF)
            heroMid = Color(hex: 0xF4F6FB)
            heroEnd = Color(hex: 0xEEF2FA)
            heroPrimaryText = Color(hex: 0x17181C)
            heroSecondaryText = Color(hex: 0x59606C)
            bodyText = Color(hex: 0x1A1A1E)
            mutedText = Color(hex: 0x7A808B)
            shadowColor = Color.black.opacity(0.09)
        case .notionWarm:
            isLight = true
            tint = Color(hex: 0x0075DE)
            secondaryTint = Color(hex: 0x4F8BFF)
            tertiaryTint = Color(hex: 0xE59C47)
            success = Color(hex: 0x2F9F72)
            warning = Color(hex: 0xD6923B)
            danger = Color(hex: 0xD45B4D)
            canvasBase = Color(hex: 0xF6F5F4)
            canvasEdge = Color(hex: 0xEFECE8)
            panelTint = Color(hex: 0xD9E7F6)
            panelStroke = Color.black.opacity(0.08)
            heroStart = Color(hex: 0xFFFFFF)
            heroMid = Color(hex: 0xF7F4EF)
            heroEnd = Color(hex: 0xF1ECE6)
            heroPrimaryText = Color(hex: 0x26231F)
            heroSecondaryText = Color(hex: 0x67625C)
            bodyText = Color(hex: 0x2A2927)
            mutedText = Color(hex: 0x7A736C)
            shadowColor = Color.black.opacity(0.07)
        }
    }

    func statusColor(for status: QueueStatus) -> Color {
        switch status {
        case .queued:
            return warning
        case .downloading:
            return tint
        case .cancelled:
            return mutedText
        case .completed:
            return success
        case .failed:
            return danger
        }
    }

    func statusFill(for status: QueueStatus) -> Color {
        statusColor(for: status).opacity(isLight ? 0.14 : 0.2)
    }

    func modeColor(_ mode: DownloadMode) -> Color {
        mode == .video ? secondaryTint : tint
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroStart, heroMid, heroEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum DownloaderPanelTone {
    case regular
    case accent
    case strong
}

struct DownloaderCanvasBackground: View {
    let theme: DownloaderThemeStyle

    var body: some View {
        ZStack {
            theme.canvasBase

            LinearGradient(
                colors: [
                    theme.canvasEdge.opacity(theme.isLight ? 0.94 : 0.82),
                    theme.canvasBase,
                    theme.canvasEdge.opacity(theme.isLight ? 0.72 : 0.64),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    theme.tint.opacity(theme.isLight ? 0.06 : 0.08),
                    .clear,
                    theme.secondaryTint.opacity(theme.isLight ? 0.035 : 0.045),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension View {
    func downloaderPanel(theme: DownloaderThemeStyle, tone: DownloaderPanelTone = .regular, radius: CGFloat = 14) -> some View {
        background(DownloaderPanelBackground(theme: theme, tone: tone, radius: radius))
    }
}

private struct DownloaderPanelBackground: View {
    let theme: DownloaderThemeStyle
    let tone: DownloaderPanelTone
    let radius: CGFloat

    var body: some View {
        let effectiveRadius = min(radius, 16)
        let tintOpacity: Double
        switch tone {
        case .regular:
            tintOpacity = theme.isLight ? 0.06 : 0.08
        case .accent:
            tintOpacity = theme.isLight ? 0.1 : 0.12
        case .strong:
            tintOpacity = theme.isLight ? 0.13 : 0.16
        }

        return RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                    .fill(theme.panelTint.opacity(tintOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
            }
            .shadow(
                color: theme.shadowColor.opacity(tone == .strong ? 0.38 : 0.22),
                radius: tone == .strong ? 10 : 5,
                x: 0,
                y: tone == .strong ? 5 : 2
            )
    }
}

struct DownloaderThemePreviewCard: View {
    let preset: DownloaderThemePreset
    let isSelected: Bool

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: preset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.bodyText)

                    Text(preset.designReference)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.mutedText)
                }

                Spacer()

                if isSelected {
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(theme.tint.opacity(theme.isLight ? 0.18 : 0.24)))
                        .foregroundStyle(theme.bodyText)
                }
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.heroGradient)
                .frame(height: 72)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Queue Control")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.heroPrimaryText)

                        HStack(spacing: 8) {
                            capsule("Live", tint: theme.tint)
                            capsule("Done", tint: theme.success)
                            capsule("Retry", tint: theme.warning)
                        }
                    }
                    .padding(.horizontal, 14)
                }

            Text(preset.summary)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .downloaderPanel(theme: theme, tone: isSelected ? .strong : .regular, radius: 20)
    }

    private func capsule(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(tint.opacity(theme.isLight ? 0.16 : 0.2)))
            .foregroundStyle(theme.heroPrimaryText)
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
