import Foundation

public enum URLInputParser {
    public static func extractSupportedURLs(from input: String) -> [String] {
        let candidateRanges = candidateMatches(in: input)
            .sorted { $0.lowerBound < $1.lowerBound }
        var seen = Set<String>()
        var urls: [String] = []

        for match in candidateRanges {
            let candidate = normalizeSchemeIfNeeded(sanitize(String(input[match])))
            guard isSupportedURL(candidate), seen.insert(candidate).inserted else {
                continue
            }

            urls.append(candidate)
        }

        return urls
    }

    private static func candidateMatches(in input: String) -> [Range<String.Index>] {
        let patterns = [
            #"https?://[^\s<>"']+"#,
            ##"(?:^|[\s\(\[<\{"'])(?:www\.)?[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}(?:[/?#][^\s<>"']*)"##,
        ]
        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)

        return patterns.flatMap { pattern -> [Range<String.Index>] in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return []
            }

            return regex.matches(in: input, range: fullRange).compactMap { match in
                Range(match.range, in: input)
            }
        }
    }

    private static func sanitize(_ value: String) -> String {
        var sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "([<{\"'"))

        while let last = sanitized.unicodeScalars.last, shouldTrimTrailing(last, in: sanitized) {
            sanitized.removeLast()
        }

        return sanitized
    }

    private static func normalizeSchemeIfNeeded(_ value: String) -> String {
        let lowercasedValue = value.lowercased()
        if lowercasedValue.hasPrefix("http://") || lowercasedValue.hasPrefix("https://") {
            return value
        }

        return "https://\(value)"
    }

    private static func shouldTrimTrailing(_ scalar: Unicode.Scalar, in value: String) -> Bool {
        switch scalar {
        case ".", ",", ";", ":", "!", "?":
            return true
        case ")", "]", "}":
            return isUnbalancedClosingCharacter(scalar, in: value)
        default:
            return false
        }
    }

    private static func isUnbalancedClosingCharacter(_ closing: Unicode.Scalar, in value: String) -> Bool {
        let opening: Unicode.Scalar
        switch closing {
        case ")":
            opening = "("
        case "]":
            opening = "["
        case "}":
            opening = "{"
        default:
            return false
        }

        let opens = value.unicodeScalars.filter { $0 == opening }.count
        let closes = value.unicodeScalars.filter { $0 == closing }.count
        return closes > opens
    }

    private static func isSupportedURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else {
            return false
        }

        return true
    }
}
