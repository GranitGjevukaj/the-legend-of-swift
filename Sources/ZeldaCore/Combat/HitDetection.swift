import Foundation

public struct Hitbox: Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum HitDetection {
    public static func overlaps(a: Hitbox, b: Hitbox) -> Bool {
        let ax2 = a.x + a.width
        let ay2 = a.y + a.height
        let bx2 = b.x + b.width
        let by2 = b.y + b.height

        return a.x < bx2 && ax2 > b.x && a.y < by2 && ay2 > b.y
    }
}
