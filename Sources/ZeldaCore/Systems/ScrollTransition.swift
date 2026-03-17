import Foundation

public struct ScrollTransition: Equatable, Sendable {
    public let direction: Direction
    public let origin: ScreenCoordinate
    public let destination: ScreenCoordinate
    public let framesRequired: Int
    public private(set) var frame: Int

    public init(direction: Direction, origin: ScreenCoordinate, destination: ScreenCoordinate, framesRequired: Int = 16, frame: Int = 0) {
        self.direction = direction
        self.origin = origin
        self.destination = destination
        self.framesRequired = framesRequired
        self.frame = frame
    }

    public var progress: Double {
        Double(frame) / Double(framesRequired)
    }

    public var isComplete: Bool {
        frame >= framesRequired
    }

    public mutating func advanceFrame() {
        frame = min(framesRequired, frame + 1)
    }
}
