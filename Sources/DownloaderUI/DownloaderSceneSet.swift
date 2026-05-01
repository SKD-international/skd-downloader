import SwiftUI

public struct DownloaderSceneSet: Scene {
    private let appState: DownloaderAppState

    public init(appState: DownloaderAppState) {
        self.appState = appState
    }

    public var body: some Scene {
        WindowGroup("SKD Downloader") {
            DownloaderRootView(appState: appState)
        }
        .defaultSize(width: 1220, height: 820)
        .commands {
            DownloaderCommands(appState: appState)
        }

        Settings {
            DownloaderSettingsView(appState: appState)
        }
    }
}
