import Foundation

public struct GameLoop: Sendable {
    public var fixedTimestep: TimeInterval
    private var accumulator: TimeInterval
    private var lastTimestamp: TimeInterval?

    public init(fixedTimestep: TimeInterval = 1.0 / 60.0) {
        self.fixedTimestep = fixedTimestep
        self.accumulator = 0
        self.lastTimestamp = nil
    }

    public mutating func ticksToSimulate(currentTime: TimeInterval) -> Int {
        guard let lastTimestamp else {
            self.lastTimestamp = currentTime
            return 1
        }

        let delta = max(0, min(currentTime - lastTimestamp, 0.25))
        self.lastTimestamp = currentTime
        accumulator += delta

        var ticks = 0
        while accumulator >= fixedTimestep {
            accumulator -= fixedTimestep
            ticks += 1
        }

        return max(1, ticks)
    }
}
