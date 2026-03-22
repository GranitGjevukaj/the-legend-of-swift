import Foundation
import ZeldaContent

struct SpriteParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> [SpriteSheet] {
        let sourceToken = sourceURL?.lastPathComponent ?? "default"

        let blocks = repository.load(from: sourceURL)
        let linkBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.linkSpriteData)
        let enemyBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.enemySpriteData)

        return [
            linkSheet(token: sourceToken, blocks: blocks, bytes: linkBytes),
            enemySheet(token: sourceToken, bytes: enemyBytes),
            caveSheet(token: sourceToken, blocks: blocks)
        ]
    }

    private func linkSheet(token: String, blocks: [ASMByteBlock], bytes: [UInt8]) -> SpriteSheet {
        if let extractedFrames = extractedLinkFrames(from: blocks) {
            return SpriteSheet(id: "link_\(token)", frames: extractedFrames)
        }

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

    private func caveSheet(token: String, blocks: [ASMByteBlock]) -> SpriteSheet {
        if let extractedFrames = extractedCaveFrames(from: blocks), !extractedFrames.isEmpty {
            return SpriteSheet(id: "cave_\(token)", frames: extractedFrames)
        }

        let fallbackFrames = [
            SpriteSheet.SpriteFrame(id: "person_6a", width: 16, height: 16),
            SpriteSheet.SpriteFrame(id: "person_7b", width: 16, height: 16),
            SpriteSheet.SpriteFrame(id: "standing_fire", width: 16, height: 16)
        ]
        return SpriteSheet(id: "cave_\(token)", frames: fallbackFrames)
    }

    private func extractedLinkFrames(from blocks: [ASMByteBlock]) -> [SpriteSheet.SpriteFrame]? {
        guard
            let spriteCHR = structuredSpriteCHR(from: blocks, extraPatternLabel: "PatternBlockOWSP"),
            let objAnimations = bytes(for: "ObjAnimations", in: blocks),
            let objAnimFrameHeap = bytes(for: "ObjAnimFrameHeap", in: blocks),
            let linkAnimationBase = objAnimations.first.map(Int.init)
        else {
            return nil
        }

        func leftTile(at offset: Int) -> Int? {
            guard objAnimFrameHeap.indices.contains(offset) else {
                return nil
            }
            return Int(objAnimFrameHeap[offset])
        }

        guard
            let horizontal0Tile = leftTile(at: linkAnimationBase + 0),
            let horizontal1Tile = leftTile(at: linkAnimationBase + 1),
            let downTile = leftTile(at: linkAnimationBase + 2),
            let upTile = leftTile(at: linkAnimationBase + 3),
            let horizontalAttack0Tile = leftTile(at: linkAnimationBase + 4),
            let horizontalAttack1Tile = leftTile(at: linkAnimationBase + 5),
            let downAttackTile = leftTile(at: linkAnimationBase + 6),
            let upAttackTile = leftTile(at: linkAnimationBase + 7)
        else {
            return nil
        }

        // Zelda patches Link's down-facing frame to shield tiles (58/5A)
        // when rendering the regular (non-magic) shield.
        let downShieldTileOffset = 0x50

        let frames: [SpriteSheet.SpriteFrame] = [
            SpriteSheet.SpriteFrame(
                id: "horizontal_0",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: horizontal0Tile,
                    rightSpriteTile: horizontal0Tile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "horizontal_1",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: horizontal1Tile,
                    rightSpriteTile: horizontal1Tile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "down",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: downTile + downShieldTileOffset,
                    rightSpriteTile: downTile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "up",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: upTile,
                    rightSpriteTile: upTile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "horizontal_attack_0",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: horizontalAttack0Tile,
                    rightSpriteTile: horizontalAttack0Tile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "horizontal_attack_1",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: horizontalAttack1Tile,
                    rightSpriteTile: horizontalAttack1Tile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "down_attack",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: downAttackTile,
                    rightSpriteTile: downAttackTile + 2,
                    spriteCHR: spriteCHR
                )
            ),
            SpriteSheet.SpriteFrame(
                id: "up_attack",
                width: 16,
                height: 16,
                pixels: composeFrame(
                    leftSpriteTile: upAttackTile,
                    rightSpriteTile: upAttackTile + 2,
                    spriteCHR: spriteCHR
                )
            )
        ]

        return frames
    }

    private func composeFrame(
        leftSpriteTile: Int,
        rightSpriteTile: Int,
        spriteCHR: [UInt8],
        leftMirrored: Bool = false,
        rightMirrored: Bool = false
    ) -> [UInt8] {
        let decodedLeft = decode8x16Sprite(tileIndex: leftSpriteTile, spriteCHR: spriteCHR)
        let decodedRight = decode8x16Sprite(tileIndex: rightSpriteTile, spriteCHR: spriteCHR)
        let leftPixels = leftMirrored ? mirror8x16(decodedLeft) : decodedLeft
        let rightPixels = rightMirrored ? mirror8x16(decodedRight) : decodedRight

        var frame = Array(repeating: UInt8(0), count: 16 * 16)
        for row in 0..<16 {
            let leftRowStart = row * 8
            let frameRowStart = row * 16
            frame.replaceSubrange(frameRowStart..<(frameRowStart + 8), with: leftPixels[leftRowStart..<(leftRowStart + 8)])
            frame.replaceSubrange((frameRowStart + 8)..<(frameRowStart + 16), with: rightPixels[leftRowStart..<(leftRowStart + 8)])
        }
        return frame
    }

    private func extractedCaveFrames(from blocks: [ASMByteBlock]) -> [SpriteSheet.SpriteFrame]? {
        guard
            let objAnimations = bytes(for: "ObjAnimations", in: blocks),
            let objAnimFrameHeap = bytes(for: "ObjAnimFrameHeap", in: blocks)
        else {
            return nil
        }

        guard let spriteCHR = selectedCaveSpriteCHR(
            from: blocks,
            objAnimations: objAnimations,
            objAnimFrameHeap: objAnimFrameHeap
        ) else {
            return nil
        }
        let itemSpriteCHR = structuredSpriteCHR(from: blocks, extraPatternLabel: "PatternBlockOWSP") ?? spriteCHR

        var frames: [SpriteSheet.SpriteFrame] = []
        for objectType in cavePersonObjectTypes {
            guard let pixels = objectFrame(
                for: objectType,
                frame: 0,
                mirrored: objectType < 0x7B,
                objAnimations: objAnimations,
                objAnimFrameHeap: objAnimFrameHeap,
                spriteCHR: spriteCHR
            ) else {
                continue
            }

            frames.append(
                .init(
                    id: "person_\(hexIdentifier(objectType))",
                    width: 16,
                    height: 16,
                    pixels: pixels
                )
            )
        }

        if let firePixels = objectFrame(
            for: standingFireObjectType,
            frame: 0,
            mirrored: false,
            objAnimations: objAnimations,
            objAnimFrameHeap: objAnimFrameHeap,
            spriteCHR: spriteCHR
        ) {
            frames.append(
                .init(
                    id: "standing_fire",
                    width: 16,
                    height: 16,
                    pixels: firePixels
                )
            )
        }

        frames.append(
            contentsOf: extractedCaveItemFrames(
                from: blocks,
                spriteCHR: itemSpriteCHR
            )
        )

        return frames.isEmpty ? nil : frames
    }

    private func extractedCaveItemFrames(
        from blocks: [ASMByteBlock],
        spriteCHR: [UInt8]
    ) -> [SpriteSheet.SpriteFrame] {
        guard
            let itemIdToSlot = bytes(for: "ItemIdToSlot", in: blocks),
            let itemFrameOffsets = bytes(for: "Anim_ItemFrameOffsets", in: blocks),
            let itemFrameTiles = bytes(for: "Anim_ItemFrameTiles", in: blocks)
        else {
            return []
        }

        return caveItemIDs.compactMap { itemID in
            guard
                itemIdToSlot.indices.contains(itemID),
                itemFrameOffsets.indices.contains(Int(itemIdToSlot[itemID]))
            else {
                return nil
            }

            let slot = Int(itemIdToSlot[itemID])
            let frameOffset = Int(itemFrameOffsets[slot])
            guard itemFrameTiles.indices.contains(frameOffset) else {
                return nil
            }

            let firstTile = Int(itemFrameTiles[frameOffset])
            let pixels = composeItemFrame(firstTile: firstTile, spriteCHR: spriteCHR)
            return SpriteSheet.SpriteFrame(
                id: "item_\(hexIdentifier(itemID))",
                width: 16,
                height: 16,
                pixels: pixels
            )
        }
    }

    private func selectedCaveSpriteCHR(
        from blocks: [ASMByteBlock],
        objAnimations: [UInt8],
        objAnimFrameHeap: [UInt8]
    ) -> [UInt8]? {
        var bestCandidate: ([UInt8], Int)?

        for label in cavePatternCandidates {
            guard let chr = structuredSpriteCHR(from: blocks, extraPatternLabel: label) else {
                continue
            }

            let personPixels = objectFrame(
                for: 0x6A,
                frame: 0,
                mirrored: true,
                objAnimations: objAnimations,
                objAnimFrameHeap: objAnimFrameHeap,
                spriteCHR: chr
            ) ?? []
            let firePixels = objectFrame(
                for: standingFireObjectType,
                frame: 0,
                mirrored: false,
                objAnimations: objAnimations,
                objAnimFrameHeap: objAnimFrameHeap,
                spriteCHR: chr
            ) ?? []
            let itemPixels = extractedCaveItemFrames(from: blocks, spriteCHR: chr)
                .first(where: { $0.id == "item_01" })?
                .pixels ?? []

            let score =
                nonTransparentPixelCount(personPixels) +
                nonTransparentPixelCount(firePixels) +
                itemVisualScore(itemPixels)

            if let current = bestCandidate {
                if score > current.1 {
                    bestCandidate = (chr, score)
                }
            } else {
                bestCandidate = (chr, score)
            }
        }

        return bestCandidate?.0
    }

    private func itemVisualScore(_ pixels: [UInt8]) -> Int {
        guard pixels.count == 16 * 16 else {
            return 0
        }

        let rowCounts = (0..<16).map { row in
            (0..<16).reduce(into: 0) { count, column in
                if pixels[(row * 16) + column] != 0 {
                    count += 1
                }
            }
        }

        let maxWidth = rowCounts.max() ?? 0
        let distinctWidths = Set(rowCounts.filter { $0 > 0 }).count
        let nonTransparent = nonTransparentPixelCount(pixels)

        // Prefer candidates where the item has visible shape variation
        // (e.g., guard/hilt), not just a thin uniform strip.
        return nonTransparent + (maxWidth * 8) + (distinctWidths * 12)
    }

    private func structuredSpriteCHR(from blocks: [ASMByteBlock], extraPatternLabel: String) -> [UInt8]? {
        guard let commonSpritePatterns = bytes(for: "CommonSpritePatterns", in: blocks) else {
            return nil
        }

        let areaSpritePatterns = bytes(for: extraPatternLabel, in: blocks) ?? []
        var chr = Array(repeating: UInt8(0), count: 0x1000)
        copy(commonSpritePatterns, into: &chr, at: 0x0000)
        copy(areaSpritePatterns, into: &chr, at: 0x08E0)
        return chr
    }

    private func copy(_ source: [UInt8], into target: inout [UInt8], at offset: Int) {
        guard offset < target.count else { return }
        let maxCount = min(source.count, target.count - offset)
        guard maxCount > 0 else { return }
        target.replaceSubrange(offset..<(offset + maxCount), with: source.prefix(maxCount))
    }

    private func composeFrame(leftSpriteTile: Int, spriteCHR: [UInt8], mirrored: Bool) -> [UInt8] {
        // Cave person types with mirrored=true reuse one 8x16 tile and mirror
        // it for the right half; they do not decode a separate right tile.
        if mirrored {
            return composeFrame(
                leftSpriteTile: leftSpriteTile,
                rightSpriteTile: leftSpriteTile,
                spriteCHR: spriteCHR,
                rightMirrored: true
            )
        }

        return composeFrame(
            leftSpriteTile: leftSpriteTile,
            rightSpriteTile: leftSpriteTile + 2,
            spriteCHR: spriteCHR
        )
    }

    private func composeItemFrame(firstTile: Int, spriteCHR: [UInt8]) -> [UInt8] {
        let leftPixels = decode8x16Sprite(tileIndex: firstTile, spriteCHR: spriteCHR)
        var frame = Array(repeating: UInt8(0), count: 16 * 16)

        if isNarrowItemTile(firstTile) {
            blit8x16(leftPixels, into: &frame, atX: 4)
            return frame
        }

        let rightPixels: [UInt8]
        let separation: Int
        switch firstTile {
        case ..<0x6C:
            rightPixels = mirror8x16(leftPixels)
            separation = 7
        case ..<0x7C:
            rightPixels = mirror8x16(leftPixels)
            separation = 8
        default:
            rightPixels = decode8x16Sprite(tileIndex: firstTile + 2, spriteCHR: spriteCHR)
            separation = 8
        }

        blit8x16(leftPixels, into: &frame, atX: 0)
        blit8x16(rightPixels, into: &frame, atX: separation)
        return frame
    }

    private func blit8x16(_ sprite: [UInt8], into frame: inout [UInt8], atX originX: Int) {
        guard sprite.count == 8 * 16 else {
            return
        }

        for row in 0..<16 {
            for column in 0..<8 {
                let destinationX = originX + column
                guard (0..<16).contains(destinationX) else {
                    continue
                }

                let source = (row * 8) + column
                let destination = (row * 16) + destinationX
                frame[destination] = sprite[source]
            }
        }
    }

    private func isNarrowItemTile(_ tile: Int) -> Bool {
        tile == 0xF3 || (tile >= 0x20 && tile < 0x62)
    }

    private func mirror8x16(_ pixels: [UInt8]) -> [UInt8] {
        guard pixels.count == 8 * 16 else {
            return pixels
        }

        var mirrored = Array(repeating: UInt8(0), count: 8 * 16)
        for row in 0..<16 {
            for column in 0..<8 {
                let source = (row * 8) + column
                let destination = (row * 8) + (7 - column)
                mirrored[destination] = pixels[source]
            }
        }
        return mirrored
    }

    private func objectFrame(
        for objectType: Int,
        frame: Int,
        mirrored: Bool,
        objAnimations: [UInt8],
        objAnimFrameHeap: [UInt8],
        spriteCHR: [UInt8]
    ) -> [UInt8]? {
        let animationIndex = objectType + 1
        guard objAnimations.indices.contains(animationIndex) else {
            return nil
        }

        let frameHeapIndex = Int(objAnimations[animationIndex]) + frame
        guard objAnimFrameHeap.indices.contains(frameHeapIndex) else {
            return nil
        }

        let leftSpriteTile = Int(objAnimFrameHeap[frameHeapIndex])
        return composeFrame(leftSpriteTile: leftSpriteTile, spriteCHR: spriteCHR, mirrored: mirrored)
    }

    private func decode8x16Sprite(tileIndex: Int, spriteCHR: [UInt8]) -> [UInt8] {
        let topTile = decode8x8Tile(tileIndex: tileIndex, spriteCHR: spriteCHR)
        let bottomTile = decode8x8Tile(tileIndex: tileIndex + 1, spriteCHR: spriteCHR)
        return topTile + bottomTile
    }

    private func decode8x8Tile(tileIndex: Int, spriteCHR: [UInt8]) -> [UInt8] {
        let start = tileIndex * 16
        guard start >= 0, start + 16 <= spriteCHR.count else {
            return Array(repeating: 0, count: 64)
        }

        let tileBytes = Array(spriteCHR[start..<(start + 16)])
        var pixels = Array(repeating: UInt8(0), count: 64)

        for row in 0..<8 {
            let low = tileBytes[row]
            let high = tileBytes[row + 8]
            for column in 0..<8 {
                let bit = 7 - column
                let lowBit = (low >> bit) & 0x01
                let highBit = (high >> bit) & 0x01
                pixels[(row * 8) + column] = lowBit | (highBit << 1)
            }
        }

        return pixels
    }

    private func bytes(for label: String, in blocks: [ASMByteBlock]) -> [UInt8]? {
        blocks.first(where: { normalize($0.label) == normalize(label) })?.bytes
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func nonTransparentPixelCount(_ pixels: [UInt8]) -> Int {
        pixels.reduce(into: 0) { count, value in
            if value != 0 {
                count += 1
            }
        }
    }

    private func hexIdentifier(_ value: Int) -> String {
        String(format: "%02x", value)
    }

    private let standingFireObjectType = 0x40

    private let cavePersonObjectTypes: [Int] = [
        0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74,
        0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C
    ]

    private let caveItemIDs = [0x01, 0x02, 0x03]

    private let cavePatternCandidates: [String] = [
        "PatternBlockUWSP",
        "PatternBlockUWSP127",
        "PatternBlockUWSP358",
        "PatternBlockUWSP469",
        "PatternBlockOWSP"
    ]
}
