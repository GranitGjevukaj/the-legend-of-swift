import Foundation
import ZeldaContent

struct EnemyDataParser {
    private let repository = ASMByteRepository()
    private let enemyIDs = ["octorok", "tektite", "leever", "peahat", "stalfos", "gibdo"]

    func parse(from sourceURL: URL?) -> [EnemyDefinition] {
        let blocks = repository.load(from: sourceURL)
        let enemyBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.enemyData)

        guard !enemyBytes.isEmpty else {
            return fallbackEnemies()
        }

        return enemyIDs.enumerated().map { index, id in
            let hpByte = enemyBytes[(index * 3) % enemyBytes.count]
            let damageByte = enemyBytes[(index * 3 + 1) % enemyBytes.count]
            let speedByte = enemyBytes[(index * 3 + 2) % enemyBytes.count]

            return EnemyDefinition(
                id: id,
                hitPoints: max(1, Int(hpByte % 8) + 1),
                damage: max(1, Int(damageByte % 4) + 1),
                speed: max(1, Int(speedByte % 3) + 1)
            )
        }
    }

    private func fallbackEnemies() -> [EnemyDefinition] {
        [
            EnemyDefinition(id: "octorok", hitPoints: 2, damage: 1, speed: 1),
            EnemyDefinition(id: "tektite", hitPoints: 2, damage: 1, speed: 2),
            EnemyDefinition(id: "leever", hitPoints: 3, damage: 1, speed: 1),
            EnemyDefinition(id: "peahat", hitPoints: 4, damage: 2, speed: 2),
            EnemyDefinition(id: "stalfos", hitPoints: 3, damage: 1, speed: 1),
            EnemyDefinition(id: "gibdo", hitPoints: 4, damage: 2, speed: 1)
        ]
    }
}
