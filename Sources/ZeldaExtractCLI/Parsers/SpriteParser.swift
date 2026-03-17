import Foundation
import ZeldaContent

struct SpriteParser {
    func parse(from sourceURL: URL?) -> [SpriteSheet] {
        let sourceToken = sourceURL?.lastPathComponent ?? "default"

        return [
            SpriteSheet(
                id: "link_\(sourceToken)",
                frames: [
                    .init(id: "walk_up_0", width: 16, height: 16),
                    .init(id: "walk_up_1", width: 16, height: 16),
                    .init(id: "walk_right_0", width: 16, height: 16),
                    .init(id: "attack_right", width: 16, height: 16)
                ]
            ),
            SpriteSheet(
                id: "enemies_\(sourceToken)",
                frames: [
                    .init(id: "octorok_0", width: 16, height: 16),
                    .init(id: "tektite_0", width: 16, height: 16),
                    .init(id: "stalfos_0", width: 16, height: 16)
                ]
            )
        ]
    }
}
