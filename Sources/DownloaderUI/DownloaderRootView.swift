import DownloaderCore
import SwiftUI

struct DownloaderRootView: View {
    @ObservedObject private var appState: DownloaderAppState
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DownloaderSidebarView(appState: appState)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(theme.tint)
        .background {
            DownloaderCanvasBackground(theme: theme)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.pasteURLFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }

                Button {
                    Task { await appState.startQueue() }
                } label: {
                    Label("Start Queue", systemImage: "arrow.down.circle")
                }
                .disabled(!appState.canStartQueue)

                Button {
                    appState.stopDownloads()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .disabled(!appState.canStopDownloads)

                Button {
                    appState.openOutputFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }

                Button {
                    Task { await appState.refreshEngineHealth() }
                } label: {
                    Label("Refresh Engine", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isCheckingEngineHealth)

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
        .task {
            await appState.bootstrap()
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appState.selection ?? .overview {
        case .overview:
            DownloaderOverviewView(appState: appState)
        case .queue:
            if let item = appState.selectedQueueItem {
                DownloaderQueueDetailView(appState: appState, item: item)
            } else {
                DownloaderOverviewView(appState: appState)
            }
        case .history:
            if let entry = appState.selectedHistoryEntry {
                DownloaderHistoryDetailView(appState: appState, entry: entry)
            } else {
                DownloaderOverviewView(appState: appState)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.isBinaryInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(appState.isBinaryInstalled ? theme.success : theme.warning)

            Text(appState.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.bodyText)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 8) {
                StatusBarToken(
                    title: "Engine",
                    value: appState.engineHealth.isReady ? "Ready" : "Setup",
                    tint: appState.engineHealth.isReady ? theme.success : theme.warning,
                    theme: theme
                )

                StatusBarToken(
                    title: "yt-dlp",
                    value: appState.isBinaryInstalled ? appState.binaryVersion : "unavailable",
                    tint: appState.isBinaryInstalled ? theme.tint : theme.warning,
                    theme: theme
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.panelStroke.opacity(theme.isLight ? 1 : 0.75))
                .frame(height: 1)
        }
    }
}

private struct StatusBarToken: View {
    let title: String
    let value: String
    let tint: Color
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.mutedText)

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.bodyText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(tint.opacity(theme.isLight ? 0.08 : 0.12))
        }
    }
}
