import Foundation

public struct Snapshot: Codable, Equatable, Sendable {
    public struct LinkState: Codable, Equatable, Sendable {
        public var x: Int
        public var y: Int
        public var hearts: Int

        public init(x: Int, y: Int, hearts: Int) {
            self.x = x
            self.y = y
            self.hearts = hearts
        }
    }

    public var timestamp: Date
    public var phase: String
    public var screen: String
    public var link: LinkState
    public var eventCount: Int

    public init(timestamp: Date, phase: String, screen: String, link: LinkState, eventCount: Int) {
        self.timestamp = timestamp
        self.phase = phase
        self.screen = screen
        self.link = link
        self.eventCount = eventCount
    }
}
