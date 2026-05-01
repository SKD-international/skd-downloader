import Foundation

public enum DownloaderAppPreferences {
    public static let showCompletedInSidebarKey = "Downloader.showCompletedInSidebar"
    public static let showHistoryInSidebarKey = "Downloader.showHistoryInSidebar"
    public static let recentHistoryLimitKey = "Downloader.recentHistoryLimit"
    public static let themeKey = "Downloader.theme"

    public static func showCompletedInSidebar(_ defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: showCompletedInSidebarKey) == nil {
            return true
        }

        return defaults.bool(forKey: showCompletedInSidebarKey)
    }

    public static func showHistoryInSidebar(_ defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: showHistoryInSidebarKey) == nil {
            return true
        }

        return defaults.bool(forKey: showHistoryInSidebarKey)
    }

    public static func recentHistoryLimit(_ defaults: UserDefaults = .standard) -> Int {
        normalized(defaults.integer(forKey: recentHistoryLimitKey), fallback: 8, range: 1...20)
    }

    public static func theme(_ defaults: UserDefaults = .standard) -> DownloaderThemePreset {
        guard let rawValue = defaults.string(forKey: themeKey),
              let preset = DownloaderThemePreset(rawValue: rawValue)
        else {
            return .skdMidnight
        }

        return preset
    }

    private static func normalized(_ value: Int, fallback: Int, range: ClosedRange<Int>) -> Int {
        guard value != 0 else {
            return fallback
        }

        return min(max(value, range.lowerBound), range.upperBound)
    }
}
