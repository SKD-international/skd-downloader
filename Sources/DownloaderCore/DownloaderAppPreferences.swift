import Foundation

public enum DownloaderAppPreferences {
    public static let showCompletedInSidebarKey = "Downloader.showCompletedInSidebar"
    public static let showHistoryInSidebarKey = "Downloader.showHistoryInSidebar"
    public static let recentHistoryLimitKey = "Downloader.recentHistoryLimit"
    public static let themeKey = "Downloader.theme"
    public static let textScaleKey = "Downloader.textScale"
    public static let textScaleSteps: [Double] = [1.0, 1.15, 1.3, 1.5, 1.75]

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

    /// Multiplier applied to every interface font. Steps match the Text Size menu.
    public static func textScale(_ defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.double(forKey: textScaleKey)
        guard stored > 0 else {
            return 1.0
        }

        return textScaleSteps.min(by: { abs($0 - stored) < abs($1 - stored) }) ?? 1.0
    }

    public static func setTextScale(_ scale: Double, _ defaults: UserDefaults = .standard) {
        defaults.set(scale, forKey: textScaleKey)
    }

    private static func normalized(_ value: Int, fallback: Int, range: ClosedRange<Int>) -> Int {
        guard value != 0 else {
            return fallback
        }

        return min(max(value, range.lowerBound), range.upperBound)
    }
}
