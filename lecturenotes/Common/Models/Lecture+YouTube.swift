import Foundation

extension Lecture {
    /// Link that opens a YouTube import's source video: in the YouTube app when it is
    /// installed (a universal link), otherwise in Safari. `nil` for other lectures and
    /// for imports that have neither a video ID nor a YouTube link.
    var youtubeWatchURL: URL? {
        guard sourceType == .youtube else {
            return nil
        }

        if let videoID = youtubeVideoID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !videoID.isEmpty {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.youtube.com"
            components.path = "/watch"
            components.queryItems = [URLQueryItem(name: "v", value: videoID)]
            return components.url
        }

        guard let sourceURL,
              let scheme = sourceURL.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = sourceURL.host()?.lowercased(),
              host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com") else {
            return nil
        }

        return sourceURL
    }
}
