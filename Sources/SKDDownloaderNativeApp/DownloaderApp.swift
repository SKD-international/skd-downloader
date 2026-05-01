import DownloaderUI
import SwiftUI

@main
struct SKDDownloaderNativeApp: App {
    @StateObject private var appState = DownloaderAppState()

    var body: some Scene {
        DownloaderSceneSet(appState: appState)
    }
}
