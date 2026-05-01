import SwiftUI

public struct DownloaderCommands: Commands {
    private let appState: DownloaderAppState

    public init(appState: DownloaderAppState) {
        self.appState = appState
    }

    public var body: some Commands {
        CommandMenu("Downloads") {
            Button("Show Overview") {
                appState.selectOverview()
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Start Queue") {
                Task { await appState.startQueue() }
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])

            Button("Refresh Binary Status") {
                Task { await appState.refreshBinaryStatus() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Open Output Folder") {
                appState.openOutputFolder()
            }
        }
    }
}
