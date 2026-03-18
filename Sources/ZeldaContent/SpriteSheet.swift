import Foundation

public struct SpriteSheet: Codable, Equatable, Sendable {
    public struct SpriteFrame: Codable, Equatable, Sendable {
        public var id: String
        public var width: Int
        public var height: Int
        public var pixels: [UInt8]?

        public init(id: String, width: Int, height: Int, pixels: [UInt8]? = nil) {
            self.id = id
            self.width = width
            self.height = height
            self.pixels = pixels
        }
    }

    public var id: String
    public var frames: [SpriteFrame]

    public init(id: String, frames: [SpriteFrame]) {
        self.id = id
        self.frames = frames
    }
}
