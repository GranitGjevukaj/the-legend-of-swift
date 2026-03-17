import Foundation

public struct TelemetryReporter: Sendable {
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func append(snapshot: Snapshot, to fileURL: URL) throws {
        let data = try encoder.encode(snapshot)
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
        } else {
            try data.write(to: fileURL, options: .atomic)
            try Data("\n".utf8).append(to: fileURL)
        }
    }
}

private extension Data {
    func append(to fileURL: URL) throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}
