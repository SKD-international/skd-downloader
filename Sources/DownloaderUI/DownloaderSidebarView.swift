import DownloaderCore
import SwiftUI

struct DownloaderSidebarView: View {
    @ObservedObject private var appState: DownloaderAppState

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        List(selection: selectionBinding) {
            Section("Workspace") {
                Label("Overview", systemImage: "square.grid.2x2")
                    .tag(DownloaderSidebarSelection.overview)
            }

            Section("Queue") {
                if appState.sidebarQueueItems.isEmpty {
                    Text("No queued downloads")
                        .font(.caption)
                        .foregroundStyle(theme.mutedText)
                } else {
                    ForEach(appState.sidebarQueueItems) { item in
                        QueueSidebarRow(item: item, theme: theme)
                            .tag(DownloaderSidebarSelection.queue(item.id))
                    }
                }
            }

            if appState.showHistoryInSidebar {
                Section("History") {
                    if appState.sidebarHistoryEntries.isEmpty {
                        Text("No recent history")
                            .font(.caption)
                            .foregroundStyle(theme.mutedText)
                    } else {
                        ForEach(appState.sidebarHistoryEntries) { entry in
                            HistorySidebarRow(entry: entry, theme: theme)
                                .tag(DownloaderSidebarSelection.history(entry.id))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SKD Downloader")
    }

    private var selectionBinding: Binding<DownloaderSidebarSelection?> {
        Binding(
            get: { appState.selection },
            set: { appState.selection = $0 }
        )
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }
}

private struct QueueSidebarRow: View {
    let item: DownloadQueueItem
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(theme.isLight ? 0.14 : 0.18))

                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(sidebarDetail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }
        }
    }

    private var sidebarDetail: String {
        if item.status == .downloading {
            return "\(item.mode.rawValue.capitalized) - \(Int(item.progress))% - \(item.speed)"
        }

        return "\(item.mode.rawValue.capitalized) - \(item.status.title)"
    }

    private var iconName: String {
        switch item.status {
        case .queued:
            return "clock"
        case .downloading:
            return "arrow.down.circle.fill"
        case .cancelled:
            return "stop.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        theme.statusColor(for: item.status)
    }
}

private struct HistorySidebarRow: View {
    let entry: DownloadHistoryEntry
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.mode == .video ? "film.fill" : "waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.modeColor(entry.mode))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(entry.downloadedAt.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }
        }
    }
}
