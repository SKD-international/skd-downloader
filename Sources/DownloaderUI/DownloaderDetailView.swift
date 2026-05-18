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
                formatInspectorCard
                commandPreviewCard
                activityLogCard
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
                Button {
                    appState.openSourceURL(item.url)
                } label: {
                    Label("Open Source", systemImage: "safari")
                }
                .buttonStyle(.bordered)

                Button {
                    appState.revealDestination(for: item)
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                if item.status == .downloading || item.status == .queued {
                    Button(role: .destructive) {
                        appState.stopDownload(item.id)
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                }

                if item.status.errorMessage != nil || item.status == .cancelled {
                    Button {
                        appState.retry(item.id)
                        Task { await appState.startQueue() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                Button(role: .destructive) {
                    appState.removeQueueItem(item.id)
                } label: {
                    Label("Remove", systemImage: "trash")
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

    private var formatInspectorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Format Inspector")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.bodyText)

                    Text(formatInspectorSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.mutedText)
                }

                Spacer()

                if item.mode == .video {
                    Button {
                        Task { await appState.refreshFormats(for: item.id) }
                    } label: {
                        Label(item.isLoadingFormats ? "Loading" : "Load", systemImage: "list.bullet.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(item.isLoadingFormats || item.status == .downloading)

                    Button {
                        appState.selectFormat(nil, for: item.id)
                    } label: {
                        Label("Auto", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.bordered)
                    .disabled(item.selectedFormatID == nil)
                }
            }

            if item.mode == .audio {
                Text("Audio jobs use the app's audio format and bitrate settings. Video format IDs are ignored for extraction jobs.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedText)
            } else {
                if item.isLoadingFormats {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)

                        Text("Reading format list from yt-dlp.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.mutedText)
                    }
                }

                if let formatError = item.formatError {
                    Text(formatError)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.danger)
                        .textSelection(.enabled)
                }

                if !item.availableFormats.isEmpty {
                    Picker("Selected Format", selection: formatSelection) {
                        Text("Automatic best match").tag("")
                        ForEach(item.availableFormats) { option in
                            Text(option.displayTitle).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(spacing: 8) {
                        ForEach(Array(item.availableFormats.prefix(8))) { option in
                            FormatOptionRow(
                                option: option,
                                isSelected: item.selectedFormatID == option.id,
                                theme: theme
                            ) {
                                appState.selectFormat(option.id, for: item.id)
                            }
                        }
                    }
                } else if !item.isLoadingFormats && item.formatError == nil {
                    Text("Load formats to override yt-dlp automatic quality selection for this item.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.mutedText)
                }
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, radius: 22)
    }

    private var commandPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Command Preview")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.bodyText)

                Spacer()

                Button {
                    appState.copyCommandPreview(for: item.id)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Text(appState.commandPreview(for: item))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.bodyText)
                .textSelection(.enabled)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.canvasBase.opacity(theme.isLight ? 0.56 : 0.44))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.panelStroke, lineWidth: 1)
                        }
                }
        }
        .padding(22)
        .downloaderPanel(theme: theme, radius: 22)
    }

    private var activityLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Log")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.bodyText)

                    Text("\(item.activityLog.count) captured line(s)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.mutedText)
                }

                Spacer()

                Button {
                    appState.copyActivityLog(for: item.id)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(item.activityLog.isEmpty)

                Button(role: .destructive) {
                    appState.clearActivityLog(for: item.id)
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(item.activityLog.isEmpty || item.status == .downloading)
            }

            if item.activityLog.isEmpty {
                Text("Download process output will appear here once this item starts.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedText)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(item.activityLog.suffix(80))) { entry in
                            ActivityLogRow(entry: entry, theme: theme)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(minHeight: 140, maxHeight: 260)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.canvasBase.opacity(theme.isLight ? 0.56 : 0.44))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.panelStroke, lineWidth: 1)
                        }
                }
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
            LabeledValue(title: "Format ID", value: item.selectedFormatID ?? "Automatic", theme: theme)

            if let destination = item.destination {
                LabeledValue(title: "Destination", value: destination, monospaced: true, theme: theme)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, radius: 22)
    }

    private var formatInspectorSubtitle: String {
        if item.mode == .audio {
            return "Audio extraction uses app defaults."
        }

        if let selectedFormatID = item.selectedFormatID {
            return "Manual selector: \(selectedFormatID)."
        }

        return "Automatic quality is active."
    }

    private var formatSelection: Binding<String> {
        Binding(
            get: {
                appState.selectedFormatID(for: item.id) ?? ""
            },
            set: { value in
                appState.selectFormat(value, for: item.id)
            }
        )
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    historyActions
                }
                .labelStyle(.titleAndIcon)

                HStack(spacing: 8) {
                    historyActions
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, tone: .strong, radius: 24)
    }

    @ViewBuilder
    private var historyActions: some View {
        Button {
            appState.requeue(entry)
        } label: {
            Label("Requeue", systemImage: "arrow.clockwise.circle")
        }
        .buttonStyle(.borderedProminent)
        .help("Requeue with current Smart Mode settings")

        Button {
            appState.revealDestination(for: entry)
        } label: {
            Label("Reveal", systemImage: "folder")
        }
        .buttonStyle(.bordered)
        .help("Reveal in Finder")

        Button {
            appState.openSourceURL(entry.url)
        } label: {
            Label("Open Source", systemImage: "safari")
        }
        .buttonStyle(.bordered)
        .help("Open source URL")

        Button {
            appState.copyToClipboard(entry.filePath, label: "path")
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .help("Copy downloaded file path")
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

private struct ActivityLogRow: View {
    let entry: DownloadActivityLogEntry
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.timestampLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.mutedText)
                .frame(width: 78, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.bodyText)
                .textSelection(.enabled)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FormatOptionRow: View {
    let option: YTDLPFormatOption
    let isSelected: Bool
    let theme: DownloaderThemeStyle
    let select: () -> Void

    var body: some View {
        Button {
            select()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? theme.tint : theme.mutedText)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.bodyText)
                        .lineLimit(1)

                    Text(option.technicalSummary.isEmpty ? option.downloadSelector : option.technicalSummary)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.mutedText)
                        .lineLimit(1)
                }

                Spacer()

                Text(option.downloadSelector)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((isSelected ? theme.tint : theme.panelTint).opacity(theme.isLight ? 0.08 : 0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? theme.tint.opacity(0.55) : theme.panelStroke, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
