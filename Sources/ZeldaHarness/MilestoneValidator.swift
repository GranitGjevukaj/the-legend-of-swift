import Foundation
import ZeldaContent
import ZeldaCore
import ZeldaTelemetry

public struct MilestoneValidationResult: Sendable {
    public var passed: Bool
    public var checks: [String]

    public init(passed: Bool, checks: [String]) {
        self.passed = passed
        self.checks = checks
    }
}

public struct MilestoneValidator: Sendable {
    public init() {}

    public func validateM1(contentRoot: URL) -> MilestoneValidationResult {
        let required = [
            "overworld.json",
            "palettes.json",
            "enemies.json",
            "items.json",
            "damage_table.json",
            "text.json",
            "audio.json",
            "dungeons/dungeon_1.json",
            "dungeons/dungeon_9.json",
            "tilesets/overworld.bin"
        ]

        var checks: [String] = []
        var allPass = true

        for file in required {
            let exists = FileManager.default.fileExists(atPath: contentRoot.appendingPathComponent(file).path())
            checks.append("\(exists ? "PASS" : "FAIL"): \(file)")
            allPass = allPass && exists
        }

        if allPass {
            do {
                _ = try ContentLoader(baseURL: contentRoot).loadAll()
                checks.append("PASS: ContentLoader.loadAll")
            } catch {
                checks.append("FAIL: ContentLoader.loadAll -> \(error.localizedDescription)")
                allPass = false
            }
        }

        return MilestoneValidationResult(passed: allPass, checks: checks)
    }

    public func validateLaunchFlow() -> MilestoneValidationResult {
        var state = GameState()
        _ = state.tick(input: InputState(start: true))
        _ = state.tick(input: InputState(start: true))

        let pass = state.phase == .playing
        let checks = [
            pass ? "PASS: launch -> title -> fileSelect -> playing" : "FAIL: unexpected phase \(state.phase)"
        ]

        return MilestoneValidationResult(passed: pass, checks: checks)
    }

    public func captureSnapshot(for state: GameState, eventCount: Int) -> Snapshot {
        Snapshot(
            timestamp: Date(),
            phase: String(describing: state.phase),
            screen: "\(state.currentScreen.column),\(state.currentScreen.row)",
            link: Snapshot.LinkState(
                x: state.link.position.x,
                y: state.link.position.y,
                hearts: state.link.hearts
            ),
            eventCount: eventCount
        )
    }
}
