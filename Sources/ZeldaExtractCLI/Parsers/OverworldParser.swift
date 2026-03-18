import Foundation
import ZeldaContent

struct OverworldParser {
    private let repository = ASMByteRepository()
    private let columnDecoder = OverworldColumnDecoder()
    private let roomPaletteSelectorToNTAttr: [UInt8] = [0x00, 0x55, 0xAA, 0xFF]

    func parse(from sourceURL: URL?) -> OverworldData {
        let blocks = repository.load(from: sourceURL)
        let exitBytes = collectExitBytes(from: blocks)
        let startRoomId = parseStartRoomId(from: blocks)
        let startY = parseStartY(from: blocks)
        var defaultRoomFlags: [Int: Int] = [:]
        if let startRoomId {
            // Seed known always-open cave behavior for start screen.
            defaultRoomFlags[startRoomId] = 0x80
        }

        if let structured = parseStructuredOverworld(from: blocks, exitBytes: exitBytes) {
            var resolved = structured
            resolved.startRoomId = startRoomId
            resolved.startY = startY
            applyRoomFlags(&resolved, defaults: defaultRoomFlags)
            return resolved
        }

        let overworldBytes = collectOverworldBytes(from: blocks)

        guard !overworldBytes.isEmpty else {
            var fallback = seededFallback(from: sourceURL)
            fallback.startRoomId = startRoomId
            fallback.startY = startY
            applyRoomFlags(&fallback, defaults: defaultRoomFlags)
            return fallback
        }

        var parsed = parseFromASMData(overworldBytes: overworldBytes, exitBytes: exitBytes)
        parsed.startRoomId = startRoomId
        parsed.startY = startY
        applyRoomFlags(&parsed, defaults: defaultRoomFlags)
        return parsed
    }

    private func parseFromASMData(overworldBytes: [UInt8], exitBytes: [UInt8]) -> OverworldData {
        let screenCount = 16 * 8
        let tileCount = 16 * 11

        let shouldUseColumnDecoder = overworldBytes.contains(0xFF) || overworldBytes.contains(0xFE)
        let decodedGrids = shouldUseColumnDecoder ? columnDecoder.decodeScreens(from: overworldBytes) : nil

        var screens: [OverworldScreen] = []
        screens.reserveCapacity(screenCount)

        for screenIndex in 0..<screenCount {
            let row = screenIndex / 16
            let column = screenIndex % 16
            let screenID = String(format: "OW_%02d_%02d", row, column)

            let grid: [Int]
            if let decodedGrids, decodedGrids.indices.contains(screenIndex) {
                grid = decodedGrids[screenIndex]
            } else {
                grid = (0..<tileCount).map { tileIndex in
                    let sourceIndex = (screenIndex * tileCount + tileIndex) % overworldBytes.count
                    return Int(overworldBytes[sourceIndex])
                }
            }

            screens.append(
                OverworldScreen(
                    id: screenID,
                    column: column,
                    row: row,
                    metatileGrid: grid,
                    exits: exits(for: screenIndex, exitBytes: exitBytes),
                    paletteSelectorGrid: nil,
                    roomFlags: nil
                )
            )
        }

        return OverworldData(width: 16, height: 8, screens: screens)
    }

    private func parseStructuredOverworld(from blocks: [ASMByteBlock], exitBytes: [UInt8]) -> OverworldData? {
        guard
            let roomLayouts = bytes(for: "RoomLayoutsOW", in: blocks),
            let levelBlockOW = bytes(for: "LevelBlockOW", in: blocks),
            levelBlockOW.count >= 512
        else {
            return nil
        }

        let heaps: [[UInt8]] = (0..<16).compactMap { index in
            let label = "ColumnHeapOW\(String(index, radix: 16, uppercase: true))"
            return bytes(for: label, in: blocks)
        }
        guard heaps.count == 16 else {
            return nil
        }

        let screenCount = 16 * 8
        let descriptorsPerRoom = 16
        let rows = 11
        let columns = 16
        let uniqueRoomMask = 0x3F
        let levelBlockAttrsDOffset = 128 * 3

        guard roomLayouts.count >= descriptorsPerRoom else {
            return nil
        }

        var screens: [OverworldScreen] = []
        screens.reserveCapacity(screenCount)

        for screenIndex in 0..<screenCount {
            let row = screenIndex / 16
            let column = screenIndex % 16
            let screenID = String(format: "OW_%02d_%02d", row, column)

            let roomAttr = levelBlockOW[levelBlockAttrsDOffset + (screenIndex % 128)]
            let uniqueRoomID = Int(roomAttr & UInt8(uniqueRoomMask))
            let roomOffset = uniqueRoomID * descriptorsPerRoom
            let paletteSelectorGrid = paletteSelectorGrid(screenIndex: screenIndex, levelBlockOW: levelBlockOW, rows: rows, columns: columns)

            let metatileGrid: [Int]
            if roomOffset + descriptorsPerRoom <= roomLayouts.count {
                let roomColumns = Array(roomLayouts[roomOffset..<(roomOffset + descriptorsPerRoom)])
                metatileGrid = decodeRoomColumns(roomColumns, heaps: heaps, rows: rows, columns: columns)
            } else {
                metatileGrid = Array(repeating: 0, count: rows * columns)
            }

            screens.append(
                OverworldScreen(
                    id: screenID,
                    column: column,
                    row: row,
                    metatileGrid: metatileGrid,
                    exits: exits(for: screenIndex, exitBytes: exitBytes),
                    paletteSelectorGrid: paletteSelectorGrid,
                    roomFlags: nil
                )
            )
        }

        return OverworldData(width: 16, height: 8, screens: screens)
    }

    private func paletteSelectorGrid(screenIndex: Int, levelBlockOW: [UInt8], rows: Int, columns: Int) -> [Int]? {
        let attrsACount = 128
        let attrsBOffset = attrsACount
        guard levelBlockOW.count >= attrsBOffset + attrsACount else {
            return nil
        }

        let roomOffset = screenIndex % attrsACount
        let outerSelector = Int(levelBlockOW[roomOffset] & 0x03)
        let innerSelector = Int(levelBlockOW[attrsBOffset + roomOffset] & 0x03)
        let playAreaAttrs = buildPlayAreaAttributes(outerSelector: outerSelector, innerSelector: innerSelector)

        var selectors: [Int] = []
        selectors.reserveCapacity(rows * columns)

        for row in 0..<rows {
            for column in 0..<columns {
                let attrRow = min(row / 2, 5)
                let attrColumn = min(column / 2, 7)
                let attrOffset = (attrRow * 8) + attrColumn
                guard playAreaAttrs.indices.contains(attrOffset) else {
                    selectors.append(0)
                    continue
                }

                let attribute = playAreaAttrs[attrOffset]
                let shift: UInt8
                switch (row % 2, column % 2) {
                case (0, 0):
                    shift = 0 // top-left
                case (0, 1):
                    shift = 2 // top-right
                case (1, 0):
                    shift = 4 // bottom-left
                default:
                    shift = 6 // bottom-right
                }

                selectors.append(Int((attribute >> shift) & 0x03))
            }
        }

        return selectors
    }

    private func buildPlayAreaAttributes(outerSelector: Int, innerSelector: Int) -> [UInt8] {
        let outerAttr = roomPaletteSelectorToNTAttr[safe: outerSelector] ?? roomPaletteSelectorToNTAttr[0]
        let innerAttr = roomPaletteSelectorToNTAttr[safe: innerSelector] ?? roomPaletteSelectorToNTAttr[0]
        var attributes = Array(repeating: outerAttr, count: 0x30)

        for offset in 0x09..<0x27 {
            let columnInRow = offset & 0x07
            if columnInRow == 0 || columnInRow == 0x07 {
                continue
            }

            if offset >= 0x21 {
                // Bottom inner attribute row: top half inner, bottom half stays outer.
                attributes[offset] = (attributes[offset] & 0xF0) | (innerAttr & 0x0F)
            } else {
                attributes[offset] = innerAttr
            }
        }

        return attributes
    }

    private func decodeRoomColumns(_ roomColumns: [UInt8], heaps: [[UInt8]], rows: Int, columns: Int) -> [Int] {
        var grid = Array(repeating: 0, count: rows * columns)

        for column in 0..<min(columns, roomColumns.count) {
            let descriptor = roomColumns[column]
            let heapIndex = Int((descriptor & 0xF0) >> 4)
            let columnIndex = Int(descriptor & 0x0F)
            guard heaps.indices.contains(heapIndex) else { continue }

            let columnValues = decodeColumnDescriptors(from: heaps[heapIndex], columnIndex: columnIndex, rows: rows)
            for row in 0..<rows {
                grid[row * columns + column] = columnValues[row]
            }
        }

        return grid
    }

    private func decodeColumnDescriptors(from heap: [UInt8], columnIndex: Int, rows: Int) -> [Int] {
        guard !heap.isEmpty else {
            return Array(repeating: 0, count: rows)
        }

        var startOffsets: [Int] = []
        startOffsets.reserveCapacity(16)
        for (index, value) in heap.enumerated() where (value & 0x80) != 0 {
            startOffsets.append(index)
        }

        guard !startOffsets.isEmpty else {
            return Array(repeating: 0, count: rows)
        }

        let start = startOffsets[min(columnIndex, startOffsets.count - 1)]
        var pointer = start
        var repeatState = 0
        var values: [Int] = []
        values.reserveCapacity(rows)

        for _ in 0..<rows {
            let byte = heap[min(pointer, heap.count - 1)]
            values.append(Int(byte & 0x3F))

            if (byte & 0x40) != 0 {
                repeatState ^= 0x40
                if repeatState == 0 {
                    pointer = min(pointer + 1, heap.count - 1)
                }
            } else {
                pointer = min(pointer + 1, heap.count - 1)
            }
        }

        if values.count < rows {
            values.append(contentsOf: Array(repeating: values.last ?? 0, count: rows - values.count))
        }
        return values
    }

    private func bytes(for label: String, in blocks: [ASMByteBlock]) -> [UInt8]? {
        let direct = blocks.filter { normalize($0.label) == normalize(label) }
        if let first = direct.first(where: { $0.fileURL.lastPathComponent.lowercased().contains("z_05") }) {
            return first.bytes
        }
        if let first = direct.first(where: { $0.fileURL.lastPathComponent.lowercased().contains("z_06") }) {
            return first.bytes
        }
        if let first = direct.first {
            return first.bytes
        }
        return nil
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func exits(for screenIndex: Int, exitBytes: [UInt8]) -> [String] {
        guard !exitBytes.isEmpty else {
            return ["north", "south", "west", "east"]
        }

        let value = exitBytes[screenIndex % exitBytes.count]
        var exits: [String] = []

        if value & 0b0001 != 0 { exits.append("north") }
        if value & 0b0010 != 0 { exits.append("south") }
        if value & 0b0100 != 0 { exits.append("west") }
        if value & 0b1000 != 0 { exits.append("east") }

        if exits.isEmpty {
            return ["north", "south", "west", "east"]
        }

        return exits
    }

    private func collectOverworldBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        let filtered = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.overworldData)

        if filtered.isEmpty {
            return blocks
                .sorted { lhs, rhs in lhs.bytes.count > rhs.bytes.count }
                .prefix(6)
                .flatMap(\.bytes)
        }

        return filtered
    }

    private func collectExitBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.overworldExitData)
    }

    private func parseStartRoomId(from blocks: [ASMByteBlock]) -> Int? {
        guard
            let levelInfo = bytes(for: "LevelInfoOW", in: blocks),
            levelInfo.count > 0x2F
        else {
            return nil
        }
        return Int(levelInfo[0x2F])
    }

    private func parseStartY(from blocks: [ASMByteBlock]) -> Int? {
        guard
            let levelInfo = bytes(for: "LevelInfoOW", in: blocks),
            levelInfo.count > 0x28
        else {
            return nil
        }
        return Int(levelInfo[0x28])
    }

    private func applyRoomFlags(_ overworld: inout OverworldData, defaults: [Int: Int]) {
        guard !defaults.isEmpty else { return }

        for index in overworld.screens.indices {
            let roomId = (overworld.screens[index].row << 4) | overworld.screens[index].column
            guard let flags = defaults[roomId] else { continue }
            overworld.screens[index].roomFlags = flags
        }
    }

    private func seededFallback(from sourceURL: URL?) -> OverworldData {
        let marker: String
        if let sourceURL {
            marker = sourceURL.lastPathComponent.replacingOccurrences(of: " ", with: "_")
        } else {
            marker = "default"
        }

        var screens: [OverworldScreen] = []
        for row in 0..<8 {
            for column in 0..<16 {
                let screenID = String(format: "OW_%02d_%02d", row, column)
                let seed = (row * 16 + column) % 8
                let grid = (0..<(16 * 11)).map { ($0 + seed) % 32 }
                screens.append(
                    OverworldScreen(
                        id: "\(screenID)_\(marker)",
                        column: column,
                        row: row,
                        metatileGrid: grid,
                        exits: ["north", "south", "west", "east"],
                        paletteSelectorGrid: nil,
                        roomFlags: nil
                    )
                )
            }
        }

        return OverworldData(width: 16, height: 8, screens: screens)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
