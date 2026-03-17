import Foundation
import ZeldaCore

public enum InputPlaybackError: Error {
    case malformedLine(Int)
}

public struct InputPlayback: Sendable {
    public init() {}

    public func parseScript(_ script: String) throws -> [InputState] {
        let lines = script
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return try lines.enumerated().map { index, line in
            let parts = line.split(separator: " ").map(String.init)
            guard let first = parts.first else {
                throw InputPlaybackError.malformedLine(index + 1)
            }

            var input = InputState()
            switch first.lowercased() {
            case "up":
                input.direction = .up
            case "down":
                input.direction = .down
            case "left":
                input.direction = .left
            case "right":
                input.direction = .right
            case "a":
                input.buttonA = true
            case "b":
                input.buttonB = true
            case "start":
                input.start = true
            default:
                throw InputPlaybackError.malformedLine(index + 1)
            }

            for modifier in parts.dropFirst() {
                switch modifier.lowercased() {
                case "a":
                    input.buttonA = true
                case "b":
                    input.buttonB = true
                case "start":
                    input.start = true
                default:
                    break
                }
            }

            return input
        }
    }

    public func replay(inputs: [InputState], state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        for input in inputs {
            events.append(contentsOf: state.tick(input: input))
        }
        return events
    }
}
