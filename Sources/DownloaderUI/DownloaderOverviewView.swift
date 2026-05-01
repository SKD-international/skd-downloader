import DownloaderCore
import SwiftUI

struct DownloaderOverviewView: View {
    @ObservedObject private var appState: DownloaderAppState

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                commandHeader
                engineHealthSection
                composerSection
                statsSection
                workbenchSection
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

    private var commandHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Download Workbench")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.bodyText)

                Text(appState.isBinaryInstalled ? appState.binaryPath : "yt-dlp unavailable")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { await appState.startQueue() }
            } label: {
                Label("Start", systemImage: "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.canStartQueue)

            Button(role: .destructive) {
                appState.stopDownloads()
            } label: {
                Label("Stop", systemImage: "stop.circle.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!appState.canStopDownloads)

            Button {
                appState.openOutputFolder()
            } label: {
                Label("Folder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .downloaderPanel(theme: theme, tone: .strong, radius: 18)
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text("SKD Downloader")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(theme.heroPrimaryText)

                Text("A native control deck for queueing, converting, and verifying media jobs without leaving the desktop.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.heroSecondaryText)

                HStack(spacing: 8) {
                    heroBadge("Theme: \(appState.themePreset.displayName)", tint: theme.tint)
                    heroBadge("\(appState.queueSummary.total) total jobs", tint: theme.secondaryTint)
                    heroBadge("\(appState.overviewHistoryEntries.count) recent files", tint: theme.tertiaryTint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text(appState.isBinaryInstalled ? "Binary Ready" : "Binary Missing")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.heroPrimaryText)

                Text(appState.isBinaryInstalled ? appState.binaryPath : "Install yt-dlp and ffmpeg to enable downloads.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.heroSecondaryText)
                    .lineLimit(3)

                Divider()
                    .overlay(theme.heroSecondaryText.opacity(0.12))

                Text(appState.themePreset.designReference)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.heroSecondaryText)

                Text(appState.themePreset.summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.heroSecondaryText)
            }
            .frame(width: 280, alignment: .leading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(theme.isLight ? 0.42 : 0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(theme.isLight ? 0.2 : 0.08), lineWidth: 1)
                    }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.heroGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.panelStroke.opacity(theme.isLight ? 0.75 : 0.6), lineWidth: 1)
                }
                .shadow(color: theme.shadowColor.opacity(0.92), radius: 28, x: 0, y: 16)
        }
    }

    private func heroBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.heroPrimaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(tint.opacity(theme.isLight ? 0.14 : 0.2)))
    }

    private var engineHealthSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label(appState.engineHealth.statusTitle, systemImage: appState.engineHealth.isReady ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(appState.engineHealth.isReady ? theme.success : theme.warning)

                Text(appState.engineHealth.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(2)
            }
            .frame(width: 240, alignment: .leading)

            Divider()
                .frame(height: 56)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(appState.engineHealth.tools) { tool in
                    EngineToolPill(tool: tool, theme: theme)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    Task { await appState.refreshEngineHealth() }
                } label: {
                    Label(appState.isCheckingEngineHealth ? "Checking" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(appState.isCheckingEngineHealth)

                Button {
                    appState.copyEngineDiagnostics()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .downloaderPanel(theme: theme, radius: 18)
    }

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add URLs")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.bodyText)

                    Text("Paste one URL per line, choose defaults, then queue everything in one pass.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.mutedText)
                }

                Spacer()

                Button("Paste URL") {
                    appState.pasteURLFromClipboard()
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: $appState.urlInput)
                .font(.system(size: 14, weight: .medium))
                .frame(minHeight: 84)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.canvasBase.opacity(theme.isLight ? 0.55 : 0.5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.panelStroke, lineWidth: 1)
                        }
                }

            HStack(alignment: .top, spacing: 12) {
                Picker("Mode", selection: $appState.selectedMode) {
                    Text("Video").tag(DownloadMode.video)
                    Text("Audio").tag(DownloadMode.audio)
                }
                .pickerStyle(.segmented)
                .frame(width: 184)

                if appState.selectedMode == .video {
                    Picker("Format", selection: $appState.configuration.videoFormat) {
                        Text("MP4").tag("mp4")
                        Text("MKV").tag("mkv")
                        Text("WebM").tag("webm")
                    }
                    .frame(width: 150)

                    Picker("Quality", selection: $appState.configuration.videoQuality) {
                        Text("Highest").tag("highest")
                        Text("1080p").tag("1080")
                        Text("720p").tag("720")
                        Text("480p").tag("480")
                    }
                    .frame(width: 150)
                } else {
                    Picker("Format", selection: $appState.configuration.audioFormat) {
                        Text("MP3").tag("mp3")
                        Text("M4A").tag("m4a")
                        Text("FLAC").tag("flac")
                        Text("WAV").tag("wav")
                    }
                    .frame(width: 150)

                    Picker("Bitrate", selection: $appState.configuration.audioBitrate) {
                        Text("320K").tag("320")
                        Text("256K").tag("256")
                        Text("192K").tag("192")
                        Text("128K").tag("128")
                    }
                    .frame(width: 150)
                }

                Spacer(minLength: 0)

                Button(appState.isFetching ? "Fetching…" : "Add to Queue") {
                    Task { await appState.addURL() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isFetching || appState.urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(appState.isDownloading ? "Downloading…" : "Start Queue") {
                    Task { await appState.startQueue() }
                }
                .buttonStyle(.bordered)
                .disabled(!appState.canStartQueue)

                Button("Stop") {
                    appState.stopDownloads()
                }
                .buttonStyle(.bordered)
                .disabled(!appState.canStopDownloads)
            }

            HStack(spacing: 10) {
                Text(formatHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.mutedText)

                Spacer()

                Button("Retry Failed") {
                    appState.retryFailedAndStopped()
                }
                .buttonStyle(.borderless)

                Button("Clear Finished") {
                    appState.clearFinishedItems()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(22)
        .downloaderPanel(theme: theme, tone: .accent, radius: 18)
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            SummaryMetricCard(title: "Queued", value: "\(appState.queueSummary.queued)", symbol: "clock", tint: theme.warning, theme: theme)
            SummaryMetricCard(title: "Active", value: "\(appState.queueSummary.active)", symbol: "arrow.down.circle.fill", tint: theme.tint, theme: theme)
            SummaryMetricCard(title: "Completed", value: "\(appState.queueSummary.completed)", symbol: "checkmark.circle.fill", tint: theme.success, theme: theme)
            SummaryMetricCard(title: "Failed", value: "\(appState.queueSummary.failed)", symbol: "exclamationmark.triangle.fill", tint: theme.danger, theme: theme)
        }
    }

    private var workbenchSection: some View {
        HStack(alignment: .top, spacing: 18) {
            queueWorkbenchColumn

            previewColumn(
                title: "Recent History",
                emptyState: "No completed downloads yet.",
                content: {
                    ForEach(appState.overviewHistoryEntries) { entry in
                        PreviewHistoryRow(entry: entry, theme: theme)
                    }
                }
            )
        }
    }

    private var queueWorkbenchColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Queue")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.bodyText)

                Spacer()

                Text("\(appState.queueSummary.total) jobs")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
            }

            if appState.queue.isEmpty {
                previewPlaceholder("Queue is empty.")
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.queue.prefix(7)) { item in
                        PreviewQueueRow(item: item, theme: theme) {
                            appState.selection = .queue(item.id)
                        } stop: {
                            appState.stopDownload(item.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewColumn<Content: View>(title: String, emptyState: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.bodyText)

            if title == "Queue Preview", appState.queue.isEmpty {
                previewPlaceholder(emptyState)
            } else if title == "Recent History", appState.overviewHistoryEntries.isEmpty {
                previewPlaceholder(emptyState)
            } else {
                VStack(spacing: 10) {
                    content()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .downloaderPanel(theme: theme, radius: 20)
    }

    private var formatHint: String {
        if appState.selectedMode == .audio {
            return "Audio extracts directly from the selected source and follows your current format and bitrate defaults."
        }

        switch appState.configuration.videoFormat.lowercased() {
        case "mkv":
            return "MKV keeps remuxing explicit. Use VLC if QuickTime refuses the finished file."
        case "webm":
            return "WebM is best for browser workflows. Pick MP4 for the safest Finder and QuickTime playback."
        default:
            return "MP4 is still the safest default for Apple playback and Finder previews."
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    let theme: DownloaderThemeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.mutedText)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.bodyText)

            Capsule(style: .continuous)
                .fill(tint.opacity(theme.isLight ? 0.18 : 0.24))
                .frame(width: 44, height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .downloaderPanel(theme: theme, radius: 20)
    }
}

private struct EngineToolPill: View {
    let tool: EngineToolStatus
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.bodyText)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(theme.isLight ? 0.1 : 0.16))
        }
    }

    private var detail: String {
        switch tool.state {
        case .installed:
            return tool.compactVersion
        case .missing:
            return "Missing"
        case .failed:
            return "Failed"
        }
    }

    private var symbol: String {
        switch tool.state {
        case .installed:
            return "checkmark.circle.fill"
        case .missing:
            return tool.required ? "exclamationmark.triangle.fill" : "minus.circle"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch tool.state {
        case .installed:
            return theme.success
        case .missing:
            return tool.required ? theme.warning : theme.mutedText
        case .failed:
            return theme.danger
        }
    }
}

private struct PreviewQueueRow: View {
    let item: DownloadQueueItem
    let theme: DownloaderThemeStyle
    let select: () -> Void
    let stop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.mode == .video ? "film.fill" : "waveform")
                .foregroundStyle(theme.modeColor(item.mode))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.bodyText)
                    .lineLimit(1)

                Text("\(item.status.title) • \(Int(item.progress))% • \(item.speed)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            if item.status == .downloading || item.status == .queued {
                Button {
                    stop()
                } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.danger)
            }

            Button {
                select()
            } label: {
                Text(item.status.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(theme.statusFill(for: item.status)))
                    .foregroundStyle(theme.bodyText)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .downloaderPanel(theme: theme, radius: 18)
    }
}

private struct PreviewHistoryRow: View {
    let entry: DownloadHistoryEntry
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.mode == .video ? "checkmark.circle.fill" : "waveform.circle.fill")
                .foregroundStyle(theme.modeColor(entry.mode))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.bodyText)
                    .lineLimit(1)

                Text(entry.downloadedAt.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .downloaderPanel(theme: theme, radius: 18)
    }
}
