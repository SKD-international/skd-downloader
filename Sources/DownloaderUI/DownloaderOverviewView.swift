import DownloaderCore
import SwiftUI
import UniformTypeIdentifiers

struct DownloaderOverviewLayout: Equatable {
    let availableWidth: CGFloat

    var horizontalPadding: CGFloat {
        availableWidth < 1_100 ? 18 : 24
    }

    var contentMaxWidth: CGFloat {
        min(max(availableWidth - (horizontalPadding * 2), 0), 1_480)
    }

    var usesInspectorColumn: Bool {
        contentMaxWidth >= 960
    }

    var inspectorWidth: CGFloat {
        guard usesInspectorColumn else {
            return 0
        }

        if contentMaxWidth < 1_120 {
            return 280
        }

        return contentMaxWidth < 1_320 ? 320 : 360
    }

    var columnSpacing: CGFloat {
        usesInspectorColumn ? (contentMaxWidth < 1_120 ? 16 : 18) : 0
    }

    var mainColumnWidth: CGFloat {
        max(contentMaxWidth - inspectorWidth - columnSpacing, 0)
    }

    var sectionSpacing: CGFloat {
        16
    }
}

struct DownloaderOverviewView: View {
    @ObservedObject private var appState: DownloaderAppState

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = DownloaderOverviewLayout(availableWidth: proxy.size.width)
            ScrollView {
                overviewContent(layout: layout)
                    .frame(maxWidth: layout.contentMaxWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.vertical, 20)
            }
        }
        .background {
            DownloaderCanvasBackground(theme: theme)
        }
    }

    private var theme: DownloaderThemeStyle {
        DownloaderThemeStyle(preset: appState.themePreset)
    }

    @ViewBuilder
    private func overviewContent(layout: DownloaderOverviewLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.sectionSpacing) {
            commandHeader

            if layout.usesInspectorColumn {
                HStack(alignment: .top, spacing: layout.columnSpacing) {
                    mainWorkbench
                        .frame(width: layout.mainColumnWidth, alignment: .topLeading)

                    inspectorColumn
                        .frame(width: layout.inspectorWidth, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                    mainWorkbench
                    inspectorColumn
                }
            }
        }
    }

    private var mainWorkbench: some View {
        VStack(alignment: .leading, spacing: 16) {
            composerSection
            queueStateRail
            queueWorkbenchColumn
        }
    }

    private var inspectorColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            engineHealthSection
            recentHistoryColumn
        }
    }

    private var commandHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SKD Downloader")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.bodyText)

                Text(appState.isBinaryInstalled ? appState.binaryPath : "Install yt-dlp and ffmpeg to enable downloads.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    commandStatusChips
                }

                VStack(alignment: .trailing, spacing: 8) {
                    commandStatusChips
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .downloaderPanel(theme: theme, tone: .strong, radius: 14)
    }

    @ViewBuilder
    private var commandStatusChips: some View {
        CommandStatusChip(
            title: appState.engineHealth.isReady ? "Engine" : "Setup",
            value: appState.engineHealth.statusTitle,
            tint: appState.engineHealth.isReady ? theme.success : theme.warning,
            theme: theme
        )

        CommandStatusChip(
            title: "Queue",
            value: "\(appState.queueSummary.total) jobs",
            tint: theme.tint,
            theme: theme
        )
    }

    private var engineHealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(appState.engineHealth.statusTitle, systemImage: appState.engineHealth.isReady ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(appState.engineHealth.isReady ? theme.success : theme.warning)

                Spacer()

                Text(appState.themePreset.displayName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.mutedText)
            }

            Text(appState.engineHealth.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.mutedText)
                .lineLimit(2)

            VStack(spacing: 8) {
                ForEach(appState.engineHealth.tools) { tool in
                    EngineToolPill(tool: tool, theme: theme)
                }
            }

            HStack(spacing: 8) {
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
        .downloaderPanel(theme: theme, radius: 14)
    }

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Add URLs", systemImage: "link.badge.plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.bodyText)

                    Text("Paste links or notes. SKD extracts supported URLs before queueing.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.mutedText)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        appState.pasteURLFromClipboard()
                    } label: {
                        Label("Paste Links", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button(appState.isFetching ? "Fetching..." : "Add to Queue") {
                        Task { await appState.addURL() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isFetching || appState.urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            TextEditor(text: $appState.urlInput)
                .font(.system(size: 14, weight: .medium))
                .frame(minHeight: 112)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.canvasBase.opacity(theme.isLight ? 0.55 : 0.5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(theme.panelStroke, lineWidth: 1)
                        }
                }
                .onDrop(of: [UTType.url.identifier, UTType.plainText.identifier, UTType.text.identifier], isTargeted: nil) { providers in
                    handleDroppedURLProviders(providers)
                }

            downloadOptionControls

            SmartModeSummaryRail(
                preset: appState.selectedDownloadPreset,
                configuration: appState.configuration,
                theme: theme
            )

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
        .padding(18)
        .downloaderPanel(theme: theme, tone: .accent, radius: 14)
    }

    private var downloadOptionControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                smartModePicker
                modePicker
                formatPicker
                qualityPicker
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    smartModePicker
                    modePicker
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: 12) {
                    formatPicker
                    qualityPicker
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var smartModePicker: some View {
        Picker("Smart Mode", selection: Binding(
            get: { appState.selectedDownloadPreset },
            set: { appState.applyDownloadPreset($0) }
        )) {
            ForEach(DownloadPreset.allCases) { preset in
                Text(preset.displayName).tag(preset)
            }
        }
        .frame(width: 210)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $appState.selectedMode) {
            Text("Video").tag(DownloadMode.video)
            Text("Audio").tag(DownloadMode.audio)
        }
        .pickerStyle(.segmented)
        .frame(width: 184)
    }

    private var formatPicker: some View {
        Group {
            if appState.selectedMode == .video {
                Picker("Format", selection: $appState.configuration.videoFormat) {
                    Text("MP4").tag("mp4")
                    Text("MKV").tag("mkv")
                    Text("WebM").tag("webm")
                }
            } else {
                Picker("Format", selection: $appState.configuration.audioFormat) {
                    Text("MP3").tag("mp3")
                    Text("M4A").tag("m4a")
                    Text("FLAC").tag("flac")
                    Text("WAV").tag("wav")
                }
            }
        }
        .frame(width: 150)
    }

    private var qualityPicker: some View {
        Group {
            if appState.selectedMode == .video {
                Picker("Quality", selection: $appState.configuration.videoQuality) {
                    Text("Highest").tag("highest")
                    Text("1080p").tag("1080")
                    Text("720p").tag("720")
                    Text("480p").tag("480")
                }
            } else {
                Picker("Bitrate", selection: $appState.configuration.audioBitrate) {
                    Text("320K").tag("320")
                    Text("256K").tag("256")
                    Text("192K").tag("192")
                    Text("128K").tag("128")
                }
            }
        }
        .frame(width: 150)
    }

    private var queueStateRail: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 1) {
                queueRailSegments
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1),
            ], spacing: 1) {
                queueRailSegments
            }
        }
        .padding(6)
        .downloaderPanel(theme: theme, radius: 14)
    }

    @ViewBuilder
    private var queueRailSegments: some View {
        QueueRailSegment(title: "Queued", value: "\(appState.queueSummary.queued)", symbol: "clock", tint: theme.warning, theme: theme)
        QueueRailSegment(title: "Active", value: "\(appState.queueSummary.active)", symbol: "arrow.down.circle.fill", tint: theme.tint, theme: theme)
        QueueRailSegment(title: "Completed", value: "\(appState.queueSummary.completed)", symbol: "checkmark.circle.fill", tint: theme.success, theme: theme)
        QueueRailSegment(title: "Failed", value: "\(appState.queueSummary.failed)", symbol: "exclamationmark.triangle.fill", tint: theme.danger, theme: theme)
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
        .padding(16)
        .downloaderPanel(theme: theme, radius: 14)
    }

    private var recentHistoryColumn: some View {
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
        .padding(16)
        .downloaderPanel(theme: theme, radius: 14)
    }

    private func previewPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.panelTint.opacity(theme.isLight ? 0.06 : 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.panelStroke, lineWidth: 1)
                    }
            }
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

    private func handleDroppedURLProviders(_ providers: [NSItemProvider]) -> Bool {
        var didScheduleLoad = false
        let appState = appState
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                didScheduleLoad = true
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    let text: String?
                    if let url = item as? URL {
                        text = url.absoluteString
                    } else if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    } else {
                        text = item as? String
                    }
                    appendDroppedURLText(text, appState: appState)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                didScheduleLoad = true
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    let text: String?
                    if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    } else {
                        text = item as? String
                    }
                    appendDroppedURLText(text, appState: appState)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                didScheduleLoad = true
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    let text: String?
                    if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    } else {
                        text = item as? String
                    }
                    appendDroppedURLText(text, appState: appState)
                }
            }
        }

        return didScheduleLoad
    }

    private nonisolated func appendDroppedURLText(_ text: String?, appState: DownloaderAppState) {
        guard let text else {
            return
        }

        Task { @MainActor in
            appState.appendURLTextToComposer(
                text,
                verb: "Dropped",
                emptyMessage: "Dropped content does not contain a supported URL.",
                duplicateMessage: "Dropped URLs are already in the composer."
            )
        }
    }
}

private struct SmartModeSummaryRail: View {
    let preset: DownloadPreset
    let configuration: DownloadConfiguration
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.tint)

                Text(preset.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedText)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                if configuration.embedSubtitles {
                    SmartModeSignalPill(title: "Embedded Subs", symbol: "captions.bubble", tint: theme.secondaryTint, theme: theme)
                }

                if configuration.saveSubtitleFiles {
                    SmartModeSignalPill(title: configuration.subtitleFormat.uppercased(), symbol: "text.badge.checkmark", tint: theme.tint, theme: theme)
                }

                if configuration.writeAutoSubtitles {
                    SmartModeSignalPill(title: "Auto", symbol: "wand.and.sparkles", tint: theme.warning, theme: theme)
                }

                if configuration.downloadArchiveEnabled {
                    SmartModeSignalPill(title: "Archive", symbol: "tray.full", tint: theme.success, theme: theme)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SmartModeSignalPill: View {
    let title: String
    let symbol: String
    let tint: Color
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(tint.opacity(theme.isLight ? 0.09 : 0.13)))
    }
}

private struct CommandStatusChip: View {
    let title: String
    let value: String
    let tint: Color
    let theme: DownloaderThemeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.mutedText)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.bodyText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(theme.isLight ? 0.1 : 0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(theme.isLight ? 0.16 : 0.22), lineWidth: 1)
                }
        }
    }
}

private struct QueueRailSegment: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    let theme: DownloaderThemeStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.mutedText)

            Spacer(minLength: 6)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.bodyText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(theme.isLight ? 0.07 : 0.1))
        }
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(theme.isLight ? 0.08 : 0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(theme.isLight ? 0.12 : 0.16), lineWidth: 1)
                }
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
