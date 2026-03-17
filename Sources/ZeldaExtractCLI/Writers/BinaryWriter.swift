import Foundation

struct BinaryWriter {
    func write(_ data: Data, to url: URL) throws -> URL {
        try data.write(to: url, options: .atomic)
        return url
    }
}
