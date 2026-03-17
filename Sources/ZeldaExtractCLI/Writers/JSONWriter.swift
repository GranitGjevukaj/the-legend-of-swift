import Foundation

struct JSONWriter {
    private let encoder: JSONEncoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func write<T: Encodable>(_ value: T, to url: URL) throws -> URL {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
        return url
    }
}
