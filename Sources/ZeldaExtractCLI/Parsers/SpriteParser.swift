import Foundation
import ZeldaContent

struct SpriteParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> [SpriteSheet] {
        let sourceToken = sourceURL?.lastPathComponent ?? "default"

        let blocks = repository.load(from: sourceURL)
        let linkBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.linkSpriteData)
        let enemyBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.enemySpriteData)

        return [linkSheet(token: sourceToken, blocks: blocks, bytes: linkBytes), enemySheet(token: sourceToken, bytes: enemyBytes)]
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

    private func extractedLinkFrames(from blocks: [ASMByteBlock]) -> [SpriteSheet.SpriteFrame]? {
        guard
            let spriteCHR = structuredSpriteCHR(from: blocks),
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
            let pixels = composeFrame(leftSpriteTile: leftSpriteTile, spriteCHR: spriteCHR)
            return SpriteSheet.SpriteFrame(id: id, width: 16, height: 16, pixels: pixels)
        }

        return frames.count == frameIDs.count ? frames : nil
    }

    private func structuredSpriteCHR(from blocks: [ASMByteBlock]) -> [UInt8]? {
        guard let commonSpritePatterns = bytes(for: "CommonSpritePatterns", in: blocks) else {
            return nil
        }

        let overworldSpritePatterns = bytes(for: "PatternBlockOWSP", in: blocks) ?? []
        var chr = Array(repeating: UInt8(0), count: 0x1000)
        copy(commonSpritePatterns, into: &chr, at: 0x0000)
        copy(overworldSpritePatterns, into: &chr, at: 0x08E0)
        return chr
    }

    private func copy(_ source: [UInt8], into target: inout [UInt8], at offset: Int) {
        guard offset < target.count else { return }
        let maxCount = min(source.count, target.count - offset)
        guard maxCount > 0 else { return }
        target.replaceSubrange(offset..<(offset + maxCount), with: source.prefix(maxCount))
    }

    private func composeFrame(leftSpriteTile: Int, spriteCHR: [UInt8]) -> [UInt8] {
        let leftPixels = decode8x16Sprite(tileIndex: leftSpriteTile, spriteCHR: spriteCHR)
        let rightPixels = decode8x16Sprite(tileIndex: leftSpriteTile + 2, spriteCHR: spriteCHR)
        var frame = Array(repeating: UInt8(0), count: 16 * 16)

        for row in 0..<16 {
            let leftRowStart = row * 8
            let frameRowStart = row * 16
            frame.replaceSubrange(frameRowStart..<(frameRowStart + 8), with: leftPixels[leftRowStart..<(leftRowStart + 8)])
            frame.replaceSubrange((frameRowStart + 8)..<(frameRowStart + 16), with: rightPixels[leftRowStart..<(leftRowStart + 8)])
        }

        return frame
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
}
