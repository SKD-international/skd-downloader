import Foundation

public enum YTDLPOutputParser {
    public static func progress(from line: String) -> DownloadProgress? {
        let pattern = #"download:(\d+\.?\d*)%\s+(\S+)\s+(?:ETA\s+)?(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard
            let match = regex.firstMatch(in: line, range: range),
            let percentRange = Range(match.range(at: 1), in: line),
            let speedRange = Range(match.range(at: 2), in: line),
            let etaRange = Range(match.range(at: 3), in: line),
            let percent = Double(line[percentRange])
        else {
            return nil
        }

        return DownloadProgress(
            percent: percent,
            speed: String(line[speedRange]),
            eta: String(line[etaRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public static func destination(from line: String) -> String? {
        let prefixes = [
            "[download] Destination: ",
            "[Merger] Merging formats into \"",
            "[ExtractAudio] Destination: ",
            "[ffmpeg] Destination: ",
        ]

        for prefix in prefixes {
            guard line.hasPrefix(prefix) else { continue }
            let rawValue = String(line.dropFirst(prefix.count))
            return rawValue.replacingOccurrences(of: "\"", with: "")
        }

        if let range = line.range(of: "Destination: ") {
            let rawValue = String(line[range.upperBound...])
            return rawValue.replacingOccurrences(of: "\"", with: "")
        }

        if line.contains(" has already been downloaded") {
            return line
                .replacingOccurrences(of: "[download] ", with: "")
                .replacingOccurrences(of: " has already been downloaded", with: "")
        }

        return nil
    }

    public static func infoPayload(from output: String) throws -> [VideoInfo] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let entries = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return try entries.map {
            let data = Data($0.utf8)
            return try decoder.decode(VideoInfo.self, from: data)
        }
    }
}
