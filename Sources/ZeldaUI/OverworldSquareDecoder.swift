import Foundation

enum OverworldSquareDecoder {
    private static let primarySquaresOW: [Int] = [
        0x24, 0x6F, 0xF3, 0xFA, 0x98, 0x90, 0x8F, 0x95,
        0x8E, 0x90, 0x74, 0x76, 0xF3, 0x24, 0x26, 0x89,
        0x03, 0x04, 0x70, 0xC8, 0xBC, 0x8D, 0x8F, 0x93,
        0x95, 0xC4, 0xCE, 0xD8, 0xB0, 0xB4, 0xAA, 0xAC,
        0xB8, 0x9C, 0xA6, 0x9A, 0xA2, 0xA0, 0xE5, 0xE6,
        0xE7, 0xE8, 0xE9, 0xEA, 0xC0, 0xE0, 0x78, 0x7A,
        0x7E, 0x80, 0xCC, 0xD0, 0xD4, 0xDC, 0x89, 0x84
    ]

    private static let secondarySquaresOW: [Int] = [
        0x24, 0x24, 0x24, 0x24, 0x6F, 0x6F, 0x6F, 0x6F,
        0xF3, 0xF3, 0xF3, 0xF3, 0xFA, 0xFA, 0xFA, 0xFA,
        0x98, 0x95, 0x26, 0x26, 0x90, 0x95, 0x90, 0x95,
        0x8F, 0x90, 0x8F, 0x90, 0x95, 0x96, 0x95, 0x96,
        0x8E, 0x93, 0x90, 0x95, 0x90, 0x95, 0x92, 0x97,
        0x74, 0x74, 0x75, 0x75, 0x76, 0x77, 0x76, 0x77,
        0xF3, 0x24, 0xF3, 0x24, 0x24, 0x24, 0x24, 0x24,
        0x26, 0x26, 0x26, 0x26, 0x89, 0x88, 0x8B, 0x88
    ]

    static func tiles(for descriptor: Int, roomFlags: Int = 0) -> [Int] {
        let resolved = resolvedSquare(for: descriptor, roomFlags: roomFlags)

        switch resolved {
        case let .secondary(squareIndex):
            let base = squareIndex * 4
            guard base + 3 < secondarySquaresOW.count else {
                return [0, 0, 0, 0]
            }
            return Array(secondarySquaresOW[base...(base + 3)])
        case let .primary(tile):
            let resolvedTile = remappedPrimaryTile(tile)
            return [resolvedTile, resolvedTile + 1, resolvedTile + 2, resolvedTile + 3]
        }
    }

    static func isWalkable(descriptor: Int, roomFlags: Int = 0) -> Bool {
        let resolved = resolvedSquare(for: descriptor, roomFlags: roomFlags)

        switch resolved {
        case let .secondary(squareIndex):
            return walkableSecondarySquares.contains(squareIndex)
        case let .primary(tile):
            return !blockedPrimaryTiles.contains(remappedPrimaryTile(tile))
        }
    }

    private static func resolvedSquare(for descriptor: Int, roomFlags: Int) -> ResolvedSquare {
        let originalSquareIndex = descriptor & 0x3F
        guard originalSquareIndex < primarySquaresOW.count else {
            return .secondary(0)
        }

        let secretFound = (roomFlags & 0x80) != 0
        let originalPrimary = primarySquaresOW[originalSquareIndex]

        var squareIndex = originalSquareIndex
        var primaryTile = originalPrimary

        if secretFound {
            if originalPrimary == 0xE7 || originalPrimary == 0xEA {
                // Turn tree/special armos into stairs square.
                squareIndex = 0x10
                primaryTile = 0x70
            } else if originalPrimary == 0xE6 {
                // Turn rock wall into cave entrance square.
                squareIndex = 0x0C
            }
        }

        if squareIndex < 0x10 {
            return .secondary(squareIndex)
        }

        return .primary(primaryTile)
    }

    private static func remappedPrimaryTile(_ tile: Int) -> Int {
        switch tile {
        case 0xE5: return 0xC8
        case 0xE6: return 0xD8
        case 0xE7: return 0xC4
        case 0xE8: return 0xBC
        case 0xE9: return 0xC0
        case 0xEA: return 0xC0
        default: return tile
        }
    }

    private enum ResolvedSquare {
        case secondary(Int)
        case primary(Int)
    }

    private static let walkableSecondarySquares: Set<Int> = [
        0x0C, // cave opening
        0x0E, // open ground
        0x0F  // open ground variant
    ]

    private static let blockedPrimaryTiles: Set<Int> = [
        0x74, 0x76, 0x78, 0x7A, 0x7E, 0x80,
        0x8D, 0x8E, 0x8F, 0x90, 0x92, 0x93, 0x95, 0x96, 0x97, 0x98, 0x9A, 0x9C,
        0xA0, 0xA2, 0xA6, 0xAA, 0xAC, 0xB0, 0xB4, 0xB8, 0xBC, 0xC0, 0xC4, 0xC8,
        0xCC, 0xCE, 0xD0, 0xD4, 0xD8, 0xDC, 0xE0
    ]
}
