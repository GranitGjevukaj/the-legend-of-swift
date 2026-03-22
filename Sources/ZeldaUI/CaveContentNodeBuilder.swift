import CoreGraphics
import Foundation
import SpriteKit
import ZeldaContent
import ZeldaCore

@MainActor
enum CaveContentNodeBuilder {
    static func buildNodes(
        definition: CaveDefinition?,
        roomFlags: Int,
        spriteSheet: SpriteSheet? = nil,
        paletteBundle: PaletteBundle? = nil
    ) -> [SKNode] {
        guard let definition else {
            return []
        }

        if shouldHideContents(definition: definition, roomFlags: roomFlags) {
            return []
        }

        var nodes: [SKNode] = []

        let personNode = SKSpriteNode(
            texture: personTexture(
                for: definition.personType,
                spriteSheet: spriteSheet,
                paletteBundle: paletteBundle
            )
        )
        personNode.name = "cave-person"
        personNode.size = CGSize(width: 16, height: 16)
        personNode.position = position(x: 0x78, nesY: 0x80)
        personNode.zPosition = 5
        nodes.append(personNode)

        if shouldShowSwordCaveFlames(definition: definition) {
            for (index, x) in [0x58, 0x98].enumerated() {
                let flameNode = SKSpriteNode(
                    texture: flameTexture(
                        spriteSheet: spriteSheet,
                        paletteBundle: paletteBundle
                    )
                )
                flameNode.name = "cave-flame-\(index)"
                flameNode.size = CGSize(width: 16, height: 16)
                flameNode.position = position(x: x, nesY: 0x90)
                flameNode.zPosition = 6
                nodes.append(flameNode)
            }
        }

        let showItems = (definition.caveFlags & 0x04) != 0
        guard showItems else {
            return nodes
        }

        let wareXs = [0x58, 0x78, 0x98]
        for item in definition.items {
            guard item.slot < wareXs.count, let itemId = item.itemId else {
                continue
            }

            let itemNode = SKSpriteNode(
                texture: caveItemTexture(
                    for: itemId,
                    spriteSheet: spriteSheet,
                    paletteBundle: paletteBundle
                )
            )
            itemNode.name = "cave-item-\(item.slot)"
            itemNode.size = CGSize(width: 16, height: 16)
            itemNode.position = position(x: wareXs[item.slot], nesY: swordCaveItemNesY)
            itemNode.zPosition = 6
            nodes.append(itemNode)
        }

        return nodes
    }

    private static func shouldHideContents(definition: CaveDefinition, roomFlags: Int) -> Bool {
        guard (roomFlags & 0x10) != 0 else {
            return false
        }

        return isTakeTypeCave(personType: definition.personType)
    }

    private static func isTakeTypeCave(personType: Int) -> Bool {
        switch personType {
        case 0x6A...0x6D, 0x71, 0x72:
            return true
        default:
            return personType >= 0x7B
        }
    }

    private static func shouldShowSwordCaveFlames(definition: CaveDefinition) -> Bool {
        guard isTakeTypeCave(personType: definition.personType) else {
            return false
        }

        return definition.items.contains(where: { $0.itemId == 0x01 && $0.price == 0 })
    }

    private static func position(x: Int, nesY: Int) -> CGPoint {
        let relativeY = max(0, nesY - 0x40)
        return CGPoint(x: x, y: Room.pixelHeight - relativeY)
    }

    private static func personTexture(
        for personType: Int,
        spriteSheet: SpriteSheet?,
        paletteBundle: PaletteBundle?
    ) -> SKTexture {
        let extractedID = "person_\(String(format: "%02x", personType))"
        if let texture = extractedTexture(
            frameID: extractedID,
            from: spriteSheet,
            palette: personExtractedPalette(from: paletteBundle)
        ) {
            return texture
        }

        if personType >= 0x7B,
           let texture = extractedTexture(
            frameID: "person_7b",
            from: spriteSheet,
            palette: personExtractedPalette(from: paletteBundle)
           ) {
            return texture
        }
        return emptyTexture()
    }

    static func itemTexture(
        for itemId: Int,
        spriteSheet: SpriteSheet? = nil,
        paletteBundle: PaletteBundle? = nil
    ) -> SKTexture {
        if let extracted = extractedItemTexture(
            for: itemId,
            spriteSheet: spriteSheet,
            paletteBundle: paletteBundle
        ) {
            return extracted
        }
        return emptyTexture()
    }

    private static func caveItemTexture(
        for itemId: Int,
        spriteSheet: SpriteSheet?,
        paletteBundle: PaletteBundle?
    ) -> SKTexture {
        let extractedID = "item_\(String(format: "%02x", itemId))"
        if let texture = extractedTexture(
            frameID: extractedID,
            from: spriteSheet,
            palette: caveItemExtractedPalette(for: itemId, from: paletteBundle)
        ) {
            return texture
        }

        return itemTexture(for: itemId, spriteSheet: spriteSheet, paletteBundle: paletteBundle)
    }

    private static func extractedItemTexture(
        for itemId: Int,
        spriteSheet: SpriteSheet?,
        paletteBundle: PaletteBundle?
    ) -> SKTexture? {
        let extractedID = "item_\(String(format: "%02x", itemId))"
        return extractedTexture(
            frameID: extractedID,
            from: spriteSheet,
            palette: itemExtractedPalette(for: itemId, from: paletteBundle)
        )
    }

    private static func flameTexture(
        spriteSheet: SpriteSheet?,
        paletteBundle: PaletteBundle?
    ) -> SKTexture {
        if let texture = extractedTexture(
            frameID: "standing_fire",
            from: spriteSheet,
            palette: flameExtractedPalette(from: paletteBundle)
        ) {
            return texture
        }
        return emptyTexture()
    }

    private static func extractedTexture(
        frameID: String,
        from spriteSheet: SpriteSheet?,
        palette: [RGBA]
    ) -> SKTexture? {
        guard
            let spriteSheet,
            let frame = spriteSheet.frames.first(where: { $0.id == frameID }),
            frame.width == 16,
            frame.height == 16,
            let pixels = frame.pixels,
            pixels.count == 16 * 16
        else {
            return nil
        }

        return texture(from: pixels, width: 16, height: 16, palette: palette)
    }

    private static func personExtractedPalette(from bundle: PaletteBundle?) -> [RGBA] {
        [
            RGBA(r: 0, g: 0, b: 0, a: 0),
            nesColor(bundle: bundle, index: 22, fallback: RGBA(r: 228, g: 0, b: 88, a: 255)),
            nesColor(bundle: bundle, index: 55, fallback: RGBA(r: 252, g: 224, b: 168, a: 255)),
            nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255))
        ]
    }

    private static func flameExtractedPalette(from bundle: PaletteBundle?) -> [RGBA] {
        [
            RGBA(r: 0, g: 0, b: 0, a: 0),
            nesColor(bundle: bundle, index: 6, fallback: RGBA(r: 168, g: 16, b: 0, a: 255)),
            nesColor(bundle: bundle, index: 38, fallback: RGBA(r: 248, g: 120, b: 88, a: 255)),
            nesColor(bundle: bundle, index: 40, fallback: RGBA(r: 248, g: 184, b: 0, a: 255))
        ]
    }

    private static func itemExtractedPalette(for itemId: Int, from bundle: PaletteBundle?) -> [RGBA] {
        switch itemId {
        case 0x02:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 15, fallback: RGBA(r: 0, g: 0, b: 0, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255))
            ]
        case 0x03:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 15, fallback: RGBA(r: 0, g: 0, b: 0, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 33, fallback: RGBA(r: 60, g: 188, b: 252, a: 255))
            ]
        default:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 15, fallback: RGBA(r: 0, g: 0, b: 0, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 23, fallback: RGBA(r: 172, g: 124, b: 0, a: 255))
            ]
        }
    }

    private static func caveItemExtractedPalette(for itemId: Int, from bundle: PaletteBundle?) -> [RGBA] {
        switch itemId {
        case 0x02:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255))
            ]
        case 0x03:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 33, fallback: RGBA(r: 60, g: 188, b: 252, a: 255))
            ]
        default:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 24, fallback: RGBA(r: 172, g: 124, b: 0, a: 255))
            ]
        }
    }

    private static func nesColor(bundle: PaletteBundle?, index: Int, fallback: RGBA) -> RGBA {
        guard let bundle, bundle.nesColors.indices.contains(index) else {
            return fallback
        }

        let hex = bundle.nesColors[index]
        guard let parsed = parseHexColor(hex) else {
            return fallback
        }
        return parsed
    }

    private static func parseHexColor(_ hex: String) -> RGBA? {
        guard hex.count == 7, hex.hasPrefix("#") else {
            return nil
        }

        guard let value = Int(String(hex.dropFirst()), radix: 16) else {
            return nil
        }

        return RGBA(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF),
            a: 255
        )
    }

    private static func texture(from pixels: [UInt8], width: Int, height: Int, palette: [RGBA]) -> SKTexture {
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)
        for (index, slot) in pixels.enumerated() {
            let color = palette.indices.contains(Int(slot)) ? palette[Int(slot)] : palette[0]
            let output = index * 4
            rgba[output] = color.r
            rgba[output + 1] = color.g
            rgba[output + 2] = color.b
            rgba[output + 3] = color.a
        }

        let data = Data(rgba) as CFData
        let provider = CGDataProvider(data: data)!
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func emptyTexture() -> SKTexture {
        texture(
            from: Array(repeating: UInt8(0), count: 16 * 16),
            width: 16,
            height: 16,
            palette: [RGBA(r: 0, g: 0, b: 0, a: 0)]
        )
    }

    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    private static let swordCaveItemNesY = 0x9C

}
