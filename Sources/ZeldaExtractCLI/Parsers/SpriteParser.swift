import Foundation
import ZeldaContent

struct SpriteParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> [SpriteSheet] {
        let sourceToken = sourceURL?.lastPathComponent ?? "default"

        let blocks = repository.load(from: sourceURL)
        let linkBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.linkSpriteData)
        let enemyBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.enemySpriteData)

        return [linkSheet(token: sourceToken, bytes: linkBytes), enemySheet(token: sourceToken, bytes: enemyBytes)]
    }

    private func linkSheet(token: String, bytes: [UInt8]) -> SpriteSheet {
        let count = max(4, min(12, max(1, bytes.count / 16)))
        let frames = (0..<count).map { index in
            SpriteSheet.SpriteFrame(id: "link_frame_\(index)", width: 16, height: 16)
        }
        return SpriteSheet(id: "link_\(token)", frames: frames)
    }

    private func enemySheet(token: String, bytes: [UInt8]) -> SpriteSheet {
        let enemyKinds = ["octorok", "tektite", "stalfos", "gibdo"]
        let framesPerEnemy = max(1, min(3, max(1, bytes.count / 64)))
        var frames: [SpriteSheet.SpriteFrame] = []

        for kind in enemyKinds {
            for frame in 0..<framesPerEnemy {
                frames.append(.init(id: "\(kind)_\(frame)", width: 16, height: 16))
            }
        }

        return SpriteSheet(id: "enemies_\(token)", frames: frames)
    }
}
