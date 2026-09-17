import DownloaderCore
import DownloaderUI
import SwiftUI

struct SKDDownloaderNativeApp: App {
    @StateObject private var appState = DownloaderAppState()

    var body: some Scene {
        DownloaderSceneSet(appState: appState)
    }
}

if let command = HeadlessCommand(arguments: CommandLine.arguments) {
    let code = await command.run { line in
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
    exit(code)
} else if CommandLine.arguments.count > 1, CommandLine.arguments[1].hasPrefix("--") {
    FileHandle.standardError.write(Data((HeadlessCommand.usage + "\n").utf8))
    exit(2)
} else {
    SKDDownloaderNativeApp.main()
}
