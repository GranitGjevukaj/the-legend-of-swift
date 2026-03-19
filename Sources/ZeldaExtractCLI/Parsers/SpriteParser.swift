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

        let frameIDs = [
            ("horizontal_0", linkAnimationBase + 0),
            ("horizontal_1", linkAnimationBase + 1),
            ("down", linkAnimationBase + 2),
            ("up", linkAnimationBase + 3)
        ]

        let frames = frameIDs.compactMap { id, frameOffset -> SpriteSheet.SpriteFrame? in
            guard objAnimFrameHeap.indices.contains(frameOffset) else {
                return nil
            }

            let leftSpriteTile = Int(objAnimFrameHeap[frameOffset])
            let pixels = composeFrame(leftSpriteTile: leftSpriteTile, spriteCHR: spriteCHR, mirrored: false)
            return SpriteSheet.SpriteFrame(id: id, width: 16, height: 16, pixels: pixels)
        }

        return frames.count == frameIDs.count ? frames : nil
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

        return frames.isEmpty ? nil : frames
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
            let score = nonTransparentPixelCount(personPixels) + nonTransparentPixelCount(firePixels)

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
        let leftPixels = decode8x16Sprite(tileIndex: leftSpriteTile, spriteCHR: spriteCHR)
        let rightPixels: [UInt8]
        if mirrored {
            rightPixels = mirror8x16(leftPixels)
        } else {
            rightPixels = decode8x16Sprite(tileIndex: leftSpriteTile + 2, spriteCHR: spriteCHR)
        }
        var frame = Array(repeating: UInt8(0), count: 16 * 16)

        for row in 0..<16 {
            let leftRowStart = row * 8
            let frameRowStart = row * 16
            frame.replaceSubrange(frameRowStart..<(frameRowStart + 8), with: leftPixels[leftRowStart..<(leftRowStart + 8)])
            frame.replaceSubrange((frameRowStart + 8)..<(frameRowStart + 16), with: rightPixels[leftRowStart..<(leftRowStart + 8)])
        }

        return frame
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

    private let cavePatternCandidates: [String] = [
        "PatternBlockUWSP",
        "PatternBlockUWSP127",
        "PatternBlockUWSP358",
        "PatternBlockUWSP469",
        "PatternBlockOWSP"
    ]
}
