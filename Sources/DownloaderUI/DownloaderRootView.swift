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
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.bodyText)
                .lineLimit(1)

            Spacer()

            Text(appState.isBinaryInstalled ? "yt-dlp \(appState.binaryVersion)" : "yt-dlp unavailable")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.mutedText)
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
