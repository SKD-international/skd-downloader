import Foundation

public enum DownloaderThemePreset: String, CaseIterable, Codable, Sendable {
    case skdMidnight
    case raycastPulse
    case linearLight
    case notionWarm

    public var displayName: String {
        switch self {
        case .skdMidnight:
            return "SKD Midnight"
        case .raycastPulse:
            return "Raycast Pulse"
        case .linearLight:
            return "Linear Light"
        case .notionWarm:
            return "Notion Warm"
        }
    }

    public var designReference: String {
        switch self {
        case .skdMidnight:
            return "Custom SKD"
        case .raycastPulse:
            return "awesome-design-md / Raycast"
        case .linearLight:
            return "awesome-design-md / Linear"
        case .notionWarm:
            return "awesome-design-md / Notion"
        }
    }

    public var summary: String {
        switch self {
        case .skdMidnight:
            return "Near-black utility chrome with electric mint, cyan, and amber status accents."
        case .raycastPulse:
            return "Instrument-dark desktop utility surfaces with cold blue structure and restrained hot accents."
        case .linearLight:
            return "Measured light workspace with precise borders, cool neutrals, and disciplined spacing."
        case .notionWarm:
            return "Warm paper surfaces, softer shadows, and an approachable organized-workspace feel."
        }
    }
}
