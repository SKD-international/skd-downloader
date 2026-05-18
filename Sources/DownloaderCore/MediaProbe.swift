import Foundation

public enum MediaProbe {
    public static func metadata(fromFFProbeJSON data: Data) throws -> MediaAssetMetadata {
        let payload = try JSONDecoder().decode(FFProbePayload.self, from: data)
        let videoStream = payload.streams.first { $0.codecType == "video" }
        let audioStream = payload.streams.first { $0.codecType == "audio" }
        let resolution: MediaResolution?
        if let width = videoStream?.width, let height = videoStream?.height {
            resolution = MediaResolution(width: width, height: height)
        } else {
            resolution = nil
        }

        return MediaAssetMetadata(
            duration: payload.format?.durationValue,
            container: payload.format?.formatName,
            codecs: MediaCodecs(video: videoStream?.codecName, audio: audioStream?.codecName),
            resolution: resolution,
            chapters: payload.chapters.compactMap(\.mediaChapter)
        )
    }

    public static func assetMetadata(fromFFProbeJSON data: Data) throws -> MediaAssetMetadata {
        try metadata(fromFFProbeJSON: data)
    }
}

private struct FFProbePayload: Decodable {
    let streams: [FFProbeStream]
    let format: FFProbeFormat?
    let chapters: [FFProbeChapter]

    enum CodingKeys: String, CodingKey {
        case streams
        case format
        case chapters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.streams = try container.decodeIfPresent([FFProbeStream].self, forKey: .streams) ?? []
        self.format = try container.decodeIfPresent(FFProbeFormat.self, forKey: .format)
        self.chapters = try container.decodeIfPresent([FFProbeChapter].self, forKey: .chapters) ?? []
    }
}

private struct FFProbeStream: Decodable {
    let codecName: String?
    let codecType: String?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case codecName = "codec_name"
        case codecType = "codec_type"
        case width
        case height
    }
}

private struct FFProbeFormat: Decodable {
    let formatName: String?
    let duration: String?

    var durationValue: TimeInterval? {
        duration.flatMap(TimeInterval.init)
    }

    enum CodingKeys: String, CodingKey {
        case formatName = "format_name"
        case duration
    }
}

private struct FFProbeChapter: Decodable {
    let startTime: String?
    let endTime: String?
    let tags: Tags?

    var mediaChapter: MediaChapter? {
        guard
            let startTime,
            let endTime,
            let start = TimeInterval(startTime),
            let end = TimeInterval(endTime)
        else {
            return nil
        }

        return MediaChapter(
            title: tags?.title ?? "",
            startTime: start,
            endTime: end
        )
    }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case tags
    }

    struct Tags: Decodable {
        let title: String?
    }
}
