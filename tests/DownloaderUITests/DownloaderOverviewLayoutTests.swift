import Testing
@testable import DownloaderUI

@Test
func overviewLayoutCapsUltrawideWorkbenchWidth() {
    let layout = DownloaderOverviewLayout(availableWidth: 2_400)

    #expect(layout.usesInspectorColumn)
    #expect(layout.contentMaxWidth == 1_480)
    #expect(layout.inspectorWidth == 360)
    #expect(layout.horizontalPadding == 24)
}

@Test
func overviewLayoutStacksOnCompactWidths() {
    let layout = DownloaderOverviewLayout(availableWidth: 980)

    #expect(!layout.usesInspectorColumn)
    #expect(layout.contentMaxWidth == 944)
    #expect(layout.horizontalPadding == 18)
    #expect(layout.inspectorWidth == 0)
}

@Test
func overviewLayoutUsesNarrowInspectorOnStandardDesktopWidths() {
    let layout = DownloaderOverviewLayout(availableWidth: 1_200)

    #expect(layout.usesInspectorColumn)
    #expect(layout.contentMaxWidth == 1_152)
    #expect(layout.inspectorWidth == 320)
    #expect(layout.mainColumnWidth == 814)
}

@Test
func overviewLayoutUsesCompactInspectorNearSplitViewBreakpoint() {
    let layout = DownloaderOverviewLayout(availableWidth: 1_080)

    #expect(layout.usesInspectorColumn)
    #expect(layout.contentMaxWidth == 1_044)
    #expect(layout.inspectorWidth == 280)
    #expect(layout.mainColumnWidth == 748)
}

@Test
func nativePackageAndBundleMetadataStaySequoiaCompatible() throws {
    let packageManifest = try String(contentsOfFile: "Package.swift", encoding: .utf8)
    let buildScript = try String(contentsOfFile: "script/build_and_run.sh", encoding: .utf8)

    #expect(packageManifest.contains("platforms: [.macOS(.v14)]"))
    #expect(buildScript.contains("MIN_SYSTEM_VERSION=\"14.0\""))
}
