import Foundation

enum DungeonDoorDecoder {
    static func decodeDoors(from bitfield: UInt8) -> [String] {
        [
            "north:\(typeName((bitfield >> 0) & 0b11))",
            "south:\(typeName((bitfield >> 2) & 0b11))",
            "west:\(typeName((bitfield >> 4) & 0b11))",
            "east:\(typeName((bitfield >> 6) & 0b11))"
        ]
    }

    private static func typeName(_ value: UInt8) -> String {
        switch value {
        case 0: return "open"
        case 1: return "locked"
        case 2: return "bombable"
        default: return "shutter"
        }
    }
}
