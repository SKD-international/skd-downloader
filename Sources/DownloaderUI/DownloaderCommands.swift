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

            Button("Refresh Engine") {
                Task { await appState.refreshEngineHealth() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Update yt-dlp") {
                Task { await appState.installManagedTool(.ytDLP) }
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Divider()

            Button("Open Output Folder") {
                appState.openOutputFolder()
            }
        }

        CommandGroup(after: .toolbar) {
            Button("Increase Text Size") {
                appState.stepTextScale(1)
            }
            .keyboardShortcut("+", modifiers: [.command])

            Button("Decrease Text Size") {
                appState.stepTextScale(-1)
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button("Default Text Size") {
                appState.setTextScale(1.0)
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()
        }
    }
}
