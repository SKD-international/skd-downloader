import DownloaderCore
import SwiftUI

struct DownloaderQueueDetailView: View {
    @ObservedObject private var appState: DownloaderAppState
    let item: DownloadQueueItem

    init(appState: DownloaderAppState, item: DownloadQueueItem) {
        self._appState = ObservedObject(wrappedValue: appState)
        self.item = item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                progressCard
                metadataCard
            }
            .padding(24)
        }
        .background {
            DownloaderCanvasBackground(theme: theme)
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.bodyText)

                    Text(item.url)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.mutedText)
                        .textSelection(.enabled)
                }

                Spacer()

                Text(item.status.title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.bodyText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(theme.statusFill(for: item.status)))
            }

            HStack(spacing: 10) {
                Button("Open Source") {
                    appState.openSourceURL(item.url)
                }
                .buttonStyle(.bordered)

                Button("Reveal in Finder") {
                    appState.revealDestination(for: item)
                }
                .buttonStyle(.bordered)

                if item.status == .downloading || item.status == .queued {
                    Button(role: .destructive) {
                        appState.stopDownload(item.id)
                    } label: {
                        Text("Stop")
                    }
                    .buttonStyle(.bordered)
                }

                if item.status.errorMessage != nil || item.status == .cancelled {
                    Button("Retry") {
                        appState.retry(item.id)
                        Task { await appState.startQueue() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                Button(role: .destructive) {
                    appState.removeQueueItem(item.id)
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, tone: .strong, radius: 24)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.bodyText)

            ProgressView(value: item.progress, total: 100)
                .tint(theme.tint)

            HStack {
                LabeledValue(title: "Percent", value: "\(Int(item.progress))%", theme: theme)
                LabeledValue(title: "Speed", value: item.speed, theme: theme)
                LabeledValue(title: "ETA", value: item.eta, theme: theme)
            }

            if let errorMessage = item.status.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.danger)
                    .textSelection(.enabled)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, radius: 22)
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Metadata")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.bodyText)

            LabeledValue(title: "Mode", value: item.mode.rawValue.capitalized, theme: theme)
            LabeledValue(title: "Format", value: item.format.uppercased(), theme: theme)
            LabeledValue(title: "Quality", value: item.quality.uppercased(), theme: theme)

            if let destination = item.destination {
                LabeledValue(title: "Destination", value: destination, monospaced: true, theme: theme)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, radius: 22)
    }
}

struct DownloaderHistoryDetailView: View {
    @ObservedObject private var appState: DownloaderAppState
    let entry: DownloadHistoryEntry

    init(appState: DownloaderAppState, entry: DownloadHistoryEntry) {
        self._appState = ObservedObject(wrappedValue: appState)
        self.entry = entry
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                recordCard
            }
            .padding(24)
        }
        .background {
            DownloaderCanvasBackground(theme: theme)
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(theme.bodyText)

            Text(entry.filePath)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.mutedText)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button("Reveal in Finder") {
                    appState.revealDestination(for: entry)
                }
                .buttonStyle(.borderedProminent)

                Button("Open Source") {
                    appState.openSourceURL(entry.url)
                }
                .buttonStyle(.bordered)

                Button("Copy Path") {
                    appState.copyToClipboard(entry.filePath, label: "path")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, tone: .strong, radius: 24)
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Download Record")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.bodyText)

            LabeledValue(title: "Mode", value: entry.mode.rawValue.capitalized, theme: theme)
            LabeledValue(title: "Downloaded", value: entry.downloadedAt.formatted(date: .abbreviated, time: .shortened), theme: theme)
            LabeledValue(title: "Source", value: entry.url, monospaced: true, theme: theme)
        }
        .padding(22)
        .downloaderPanel(theme: theme, radius: 22)
    }
}

private struct LabeledValue: View {
    let title: String
    let value: String
    var monospaced = false
    let theme: DownloaderThemeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.mutedText)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: monospaced ? .monospaced : .default))
                .foregroundStyle(theme.bodyText)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
