import Foundation

struct ZeldaTextDecoder {
    private let table: [UInt8: Character]

    init() {
        var table: [UInt8: Character] = [:]

        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for (index, letter) in letters.enumerated() {
            table[UInt8(index + 1)] = letter
        }

        let digits = Array("0123456789")
        for (index, digit) in digits.enumerated() {
            table[UInt8(0x30 + index)] = digit
        }

        table[0x2A] = "'"
        table[0x2B] = "."
        table[0x2C] = "!"
        table[0x2D] = ","
        table[0x2E] = "-"
        table[0x2F] = " "
        table[0x3A] = ":"

        self.table = table
    }

    func decodeLine(_ bytes: [UInt8]) -> String {
        let mapped: [Character] = bytes.compactMap { byte in
            if let direct = table[byte] {
                return direct
            }

            if (32...126).contains(byte) {
                return Character(UnicodeScalar(byte))
            }

            return nil
        }

        let string = String(mapped)
        return string.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
