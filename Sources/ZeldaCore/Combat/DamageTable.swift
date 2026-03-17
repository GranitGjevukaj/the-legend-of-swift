import Foundation

public enum Weapon: Hashable, Sendable {
    case sword(level: Int)
    case arrow(level: Int)
    case bomb
    case boomerang
}

public struct DamageTable: Sendable {
    private var matrix: [Weapon: [Enemy.Kind: Int]]

    public init(matrix: [Weapon: [Enemy.Kind: Int]]) {
        self.matrix = matrix
    }

    public func damage(weapon: Weapon, against enemy: Enemy.Kind) -> Int {
        matrix[weapon]?[enemy] ?? 0
    }

    public static let `default` = DamageTable(
        matrix: [
            .sword(level: 1): [.octorok: 1, .tektite: 1, .leever: 1, .peahat: 0, .stalfos: 1, .gibdo: 1],
            .sword(level: 2): [.octorok: 2, .tektite: 2, .leever: 2, .peahat: 1, .stalfos: 2, .gibdo: 2],
            .sword(level: 3): [.octorok: 4, .tektite: 4, .leever: 4, .peahat: 2, .stalfos: 3, .gibdo: 3],
            .arrow(level: 1): [.octorok: 2, .tektite: 2, .leever: 2, .peahat: 2, .stalfos: 2, .gibdo: 2],
            .bomb: [.octorok: 4, .tektite: 4, .leever: 4, .peahat: 4, .stalfos: 4, .gibdo: 4],
            .boomerang: [.octorok: 0, .tektite: 0, .leever: 0, .peahat: 0, .stalfos: 0, .gibdo: 0]
        ]
    )
}
