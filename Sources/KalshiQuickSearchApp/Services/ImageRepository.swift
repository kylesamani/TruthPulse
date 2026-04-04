import AppKit
import CryptoKit
import Foundation

actor ImageRepository {
    static let shared = try? ImageRepository()

    private let memoryCache = NSCache<NSURL, NSImage>()
    private let session: URLSession
    private let cacheDirectory: URL

    init() throws {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
        self.cacheDirectory = try SearchService.makeAppSupportDirectory().appendingPathComponent("ImageCache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 200
    }

    func image(for url: URL) async -> NSImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }

        let path = cacheDirectory.appendingPathComponent(cacheKey(for: url))
        if let data = try? Data(contentsOf: path), let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: url as NSURL)
            return image
        }

        do {
            let (data, _) = try await session.data(from: url)
            try data.write(to: path, options: .atomic)
            let image = NSImage(data: data)
            if let image {
                memoryCache.setObject(image, forKey: url as NSURL)
            }
            return image
        } catch {
            return nil
        }
    }

    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
