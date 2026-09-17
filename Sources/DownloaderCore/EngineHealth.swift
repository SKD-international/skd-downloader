import Foundation

public enum EngineToolState: String, Codable, Equatable, Sendable {
    case installed
    case outdated
    case missing
    case failed
}

public struct EngineToolStatus: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let state: EngineToolState
    public let version: String
    public let path: String
    public let required: Bool
    public let message: String
    public let latestVersion: String?

    public init(
        id: String,
        name: String,
        state: EngineToolState,
        version: String,
        path: String,
        required: Bool,
        message: String = "",
        latestVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.version = version
        self.path = path
        self.required = required
        self.message = message
        self.latestVersion = latestVersion
    }

    public var isUsable: Bool {
        state == .installed || state == .outdated
    }

    /// The tool the app can install or update itself, if any.
    public var managedTool: ManagedTool? {
        ManagedTool(rawValue: id)
    }

    public var compactVersion: String {
        let parts = version.split(separator: " ").map(String.init)
        if ["ffmpeg", "ffprobe"].contains(id),
           parts.count >= 3,
           parts[1].localizedCaseInsensitiveCompare("version") == .orderedSame {
            return "\(parts[0]) \(parts[2])"
        }

        if id == "deno", parts.count >= 2, parts[0] == "deno" {
            return parts[1]
        }

        return version
    }

    public static func missing(id: String, name: String, required: Bool, message: String? = nil) -> EngineToolStatus {
        EngineToolStatus(
            id: id,
            name: name,
            state: .missing,
            version: "Missing",
            path: "",
            required: required,
            message: message ?? "\(name) was not found."
        )
    }
}

public struct EngineHealthReport: Codable, Equatable, Sendable {
    public let checkedAt: Date
    public let tools: [EngineToolStatus]

    public init(checkedAt: Date = .now, tools: [EngineToolStatus]) {
        self.checkedAt = checkedAt
        self.tools = tools
    }

    public var requiredTools: [EngineToolStatus] {
        tools.filter(\.required)
    }

    public var missingRequiredTools: [EngineToolStatus] {
        requiredTools.filter { !$0.isUsable }
    }

    public var outdatedTools: [EngineToolStatus] {
        tools.filter { $0.state == .outdated }
    }

    public var isReady: Bool {
        !requiredTools.isEmpty && missingRequiredTools.isEmpty
    }

    public var statusTitle: String {
        if requiredTools.isEmpty {
            return "Checking Engine"
        }

        if !isReady {
            return "Engine Needs Setup"
        }

        return outdatedTools.isEmpty ? "Engine Ready" : "Update Recommended"
    }

    public var statusMessage: String {
        if requiredTools.isEmpty {
            return "Engine health check has not run yet."
        }

        if !isReady {
            let missing = missingRequiredTools.map(\.name).joined(separator: ", ")
            return "Missing required tools: \(missing)."
        }

        if let outdated = outdatedTools.first {
            return outdated.message.isEmpty ? "\(outdated.name) is outdated." : outdated.message
        }

        return "yt-dlp, Deno, ffmpeg, and ffprobe are available."
    }

    public var installCommand: String {
        "brew install ffmpeg"
    }

    public var updateCommand: String {
        "brew upgrade ffmpeg"
    }

    public var diagnosticsText: String {
        let rows = tools.map { tool in
            let location = tool.path.isEmpty ? "path unavailable" : tool.path
            let note = tool.message.isEmpty ? "" : " (\(tool.message))"
            return "\(tool.name): \(tool.state.rawValue) | \(tool.version) | \(location)\(note)"
        }

        return ([
            "SKD Downloader Engine Health",
            "Checked: \(checkedAt.formatted(date: .numeric, time: .standard))",
            "Status: \(statusTitle)",
        ] + rows + [
            "Managed tools: \(ManagedToolchain.defaultBinDirectory.path)",
            "ffmpeg install: \(installCommand)",
        ]).joined(separator: "\n")
    }
}
