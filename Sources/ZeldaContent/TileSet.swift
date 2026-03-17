import Foundation

public struct TileSet: Codable, Equatable, Sendable {
    public struct Tile: Codable, Equatable, Sendable {
        public var id: Int
        public var pixels: [UInt8]

        public init(id: Int, pixels: [UInt8]) {
            self.id = id
            self.pixels = pixels
        }
    }

    public var id: String
    public var tiles: [Tile]

    public init(id: String, tiles: [Tile]) {
        self.id = id
        self.tiles = tiles
    }
}
