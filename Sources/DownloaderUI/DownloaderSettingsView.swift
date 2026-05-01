import DownloaderCore
import SwiftUI

struct DownloaderSettingsView: View {
    @ObservedObject private var appState: DownloaderAppState

    @AppStorage(DownloaderAppPreferences.showCompletedInSidebarKey)
    private var showCompletedInSidebar = true

    @AppStorage(DownloaderAppPreferences.showHistoryInSidebarKey)
    private var showHistoryInSidebar = true

    @AppStorage(DownloaderAppPreferences.recentHistoryLimitKey)
    private var recentHistoryLimit = 8

    @AppStorage(DownloaderAppPreferences.themeKey)
    private var themeID = DownloaderThemePreset.skdMidnight.rawValue

    init(appState: DownloaderAppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                generalTab
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }

                enhancementsTab
                    .tabItem {
                        Label("Enhancements", systemImage: "wand.and.stars")
                    }

                workspaceTab
                    .tabItem {
                        Label("Workspace", systemImage: "sidebar.left")
                    }

                themesTab
                    .tabItem {
                        Label("Themes", systemImage: "paintpalette")
                    }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.isBinaryInstalled ? "yt-dlp \(appState.binaryVersion)" : "yt-dlp unavailable")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))

                    Text(appState.binaryPath.isEmpty ? "Binary path unavailable." : appState.binaryPath)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Refresh Binary") {
                    Task { await appState.refreshBinaryStatus() }
                }
                .buttonStyle(.bordered)

                Button("Save Changes") {
                    appState.persistConfiguration(showStatusMessage: true)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)
            .background(.bar)
        }
        .frame(width: 760, height: 560)
        .onAppear {
            recentHistoryLimit = DownloaderAppPreferences.recentHistoryLimit()
            themeID = DownloaderAppPreferences.theme().rawValue
        }
        .onChange(of: appState.configuration.cookiesBrowser) { _, _ in
            appState.configuration.cookiesBrowserConfigured = true
        }
        .onDisappear {
            appState.persistConfiguration()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Folders") {
                HStack {
                    TextField("Video Folder", text: $appState.configuration.downloadFolderVideo)
                    Button("Choose…") { appState.pickFolder(for: .video) }
                }

                HStack {
                    TextField("Audio Folder", text: $appState.configuration.downloadFolderAudio)
                    Button("Choose…") { appState.pickFolder(for: .audio) }
                }
            }

            Section("Defaults") {
                Picker("Video Format", selection: $appState.configuration.videoFormat) {
                    Text("MP4").tag("mp4")
                    Text("MKV").tag("mkv")
                    Text("WebM").tag("webm")
                }

                Picker("Video Quality", selection: $appState.configuration.videoQuality) {
                    Text("Highest").tag("highest")
                    Text("1080p").tag("1080")
                    Text("720p").tag("720")
                    Text("480p").tag("480")
                }

                Picker("Audio Format", selection: $appState.configuration.audioFormat) {
                    Text("MP3").tag("mp3")
                    Text("M4A").tag("m4a")
                    Text("FLAC").tag("flac")
                    Text("WAV").tag("wav")
                }

                Picker("Audio Bitrate", selection: $appState.configuration.audioBitrate) {
                    Text("320K").tag("320")
                    Text("256K").tag("256")
                    Text("192K").tag("192")
                    Text("128K").tag("128")
                }

                Picker("Filename Template", selection: $appState.configuration.filenameTemplate) {
                    Text("Title").tag("title")
                    Text("Artist - Title").tag("artist-title")
                }
            }

            Section("Network") {
                Picker("Cookies Browser", selection: $appState.configuration.cookiesBrowser) {
                    Text("Chrome").tag(CookieBrowser.chrome)
                    Text("Safari").tag(CookieBrowser.safari)
                    Text("None").tag(CookieBrowser.none)
                }

                TextField("Proxy", text: $appState.configuration.proxy)

                TextField("Bandwidth Limit (KB/s)", value: $appState.configuration.bandwidthLimit, format: .number)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var enhancementsTab: some View {
        Form {
            Section("Download Behavior") {
                Toggle("SponsorBlock", isOn: $appState.configuration.sponsorBlock)
                Toggle("Embed Subtitles", isOn: $appState.configuration.embedSubtitles)
                Toggle("Embed Thumbnail", isOn: $appState.configuration.embedThumbnail)
                Toggle("Save Thumbnail File", isOn: $appState.configuration.saveThumbnail)
                Toggle("Write Audio Tags", isOn: $appState.configuration.writeTags)
                Toggle("Skip Existing Files", isOn: $appState.configuration.skipExisting)
                Toggle("Remove Emoji", isOn: $appState.configuration.removeEmoji)
            }

            Section("Subtitles") {
                TextField("Subtitle Languages", text: $appState.configuration.subtitleLangs)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var workspaceTab: some View {
        Form {
            Section("Sidebar") {
                Toggle("Show completed downloads in sidebar", isOn: $showCompletedInSidebar)
                Toggle("Show history in sidebar", isOn: $showHistoryInSidebar)
                Stepper(value: $recentHistoryLimit, in: 1...20) {
                    Text("Recent history items: \(recentHistoryLimit)")
                }
            }

            Section("Current State") {
                LabeledContent("Queue Items", value: "\(appState.queueSummary.total)")
                LabeledContent("Recent History", value: "\(appState.history.count)")
                LabeledContent("Selected Mode", value: appState.selectedMode.rawValue.capitalized)
                LabeledContent("Binary", value: appState.isBinaryInstalled ? "Installed" : "Missing")
            }

            Section("Setup") {
                Text("Install requirements with Homebrew:")
                Text("brew install yt-dlp ffmpeg")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)

                Text("Config and history are stored in ~/Library/Application Support/skd-downloader-native/")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var themesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visual Direction")
                        .font(.system(size: 18, weight: .bold))

                    Text("Use the SKD default or switch to desktop-native looks inspired by awesome-design-md references.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Picker("Theme", selection: $themeID) {
                    ForEach(DownloaderThemePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(DownloaderThemePreset.allCases, id: \.rawValue) { preset in
                        DownloaderThemePreviewCard(
                            preset: preset,
                            isSelected: themeID == preset.rawValue
                        )
                        .onTapGesture {
                            themeID = preset.rawValue
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reference Mix")
                        .font(.system(size: 13, weight: .bold))

                    Text("Default recommendation: Linear structure, Raycast mood, SKD color energy. Notion Warm stays available if you want a softer workspace feel.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
}
