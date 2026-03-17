import Foundation

struct OverworldColumnDecoder {
    let columns: Int
    let rows: Int
    let screenCount: Int

    init(columns: Int = 16, rows: Int = 11, screenCount: Int = 128) {
        self.columns = columns
        self.rows = rows
        self.screenCount = screenCount
    }

    func decodeScreens(from bytes: [UInt8]) -> [[Int]]? {
        guard !bytes.isEmpty else { return nil }

        var cursor = 0
        var screens: [[Int]] = []
        screens.reserveCapacity(screenCount)

        func nextByte() -> UInt8 {
            defer { cursor += 1 }
            return bytes[cursor % bytes.count]
        }

        func peekByte() -> UInt8 {
            bytes[cursor % bytes.count]
        }

        for _ in 0..<screenCount {
            var grid = Array(repeating: 0, count: columns * rows)

            for column in 0..<columns {
                var columnValues: [Int] = []
                var safety = 0

                while columnValues.count < rows, safety < 64 {
                    safety += 1
                    let value = nextByte()

                    if value == 0xFF {
                        break
                    }

                    if value == 0xFE {
                        let literalCount = Int(nextByte())
                        for _ in 0..<literalCount where columnValues.count < rows {
                            columnValues.append(Int(nextByte()))
                        }
                        continue
                    }

                    let tile = Int(value >> 4)
                    let runLength = Int(value & 0x0F) + 1
                    for _ in 0..<runLength where columnValues.count < rows {
                        columnValues.append(tile)
                    }
                }

                if columnValues.isEmpty {
                    columnValues = Array(repeating: 0, count: rows)
                } else if columnValues.count < rows {
                    columnValues.append(contentsOf: Array(repeating: columnValues.last ?? 0, count: rows - columnValues.count))
                }

                if columnValues.count >= rows, peekByte() == 0xFF {
                    _ = nextByte()
                }

                for row in 0..<rows {
                    grid[row * columns + column] = columnValues[row]
                }
            }

            screens.append(grid)
        }

        return screens
    }
}
