import Foundation
import ZeldaContent

struct DamageTableParser {
    private let repository = ASMByteRepository()
    private let enemies = ["octorok", "tektite", "leever", "peahat", "stalfos", "gibdo"]
    private let weapons = ["wooden_sword", "white_sword", "magic_sword", "arrow", "bomb"]

    func parse(from sourceURL: URL?) -> [DamageRule] {
        let blocks = repository.load(from: sourceURL)
        let bytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.damageData)

        guard !bytes.isEmpty else {
            return fallbackDamageRules()
        }

        var rules: [DamageRule] = []
        for enemyIndex in enemies.indices {
            for weaponIndex in weapons.indices {
                let index = enemyIndex * weapons.count + weaponIndex
                let byte = bytes[index % bytes.count]
                let amount = max(0, Int(byte % 8))
                rules.append(
                    DamageRule(
                        weapon: weapons[weaponIndex],
                        enemy: enemies[enemyIndex],
                        amount: amount
                    )
                )
            }
        }
        return rules
    }

    private func fallbackDamageRules() -> [DamageRule] {
        let values: [String: Int] = [
            "wooden_sword": 1,
            "white_sword": 2,
            "magic_sword": 4,
            "arrow": 2,
            "bomb": 4
        ]

        var rules: [DamageRule] = []
        for enemy in enemies {
            for weapon in weapons {
                rules.append(DamageRule(weapon: weapon, enemy: enemy, amount: values[weapon] ?? 1))
            }
        }
        return rules
    }
}
