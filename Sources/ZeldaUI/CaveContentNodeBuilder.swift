import CoreGraphics
import Foundation
import SpriteKit
import ZeldaContent
import ZeldaCore

@MainActor
enum CaveContentNodeBuilder {
    static func buildNodes(definition: CaveDefinition?, roomFlags: Int) -> [SKNode] {
        guard let definition else {
            return []
        }

        if shouldHideContents(definition: definition, roomFlags: roomFlags) {
            return []
        }

        var nodes: [SKNode] = []

        let personNode = SKSpriteNode(texture: personTexture(for: definition.personType))
        personNode.size = CGSize(width: 16, height: 16)
        personNode.position = position(x: 0x78, nesY: 0x80)
        personNode.zPosition = 5
        nodes.append(personNode)

        let showItems = (definition.caveFlags & 0x04) != 0
        guard showItems else {
            return nodes
        }

        let wareXs = [0x58, 0x78, 0x98]
        for item in definition.items {
            guard item.slot < wareXs.count, let itemId = item.itemId else {
                continue
            }

            let itemNode = SKSpriteNode(texture: itemTexture(for: itemId))
            itemNode.size = CGSize(width: 16, height: 16)
            itemNode.position = position(x: wareXs[item.slot], nesY: 0x98)
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

    private static func position(x: Int, nesY: Int) -> CGPoint {
        let relativeY = max(0, nesY - 0x40)
        return CGPoint(x: x, y: Room.pixelHeight - relativeY)
    }

    private static func personTexture(for personType: Int) -> SKTexture {
        let isMoblin = personType >= 0x7B
        let rows = isMoblin ? moblinPixels : oldManPixels
        return texture(from: rows)
    }

    private static func itemTexture(for itemId: Int) -> SKTexture {
        switch itemId {
        case 0x01:
            return texture(from: woodenSwordPixels)
        case 0x02:
            return texture(from: whiteSwordPixels)
        case 0x03:
            return texture(from: magicSwordPixels)
        default:
            return texture(from: genericItemPixels)
        }
    }

    private static func texture(from rows: [[UInt8]]) -> SKTexture {
        let height = rows.count
        let width = rows.first?.count ?? 0
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)

        for (y, row) in rows.enumerated() {
            for (x, slot) in row.enumerated() {
                let color = palette[Int(slot)]
                let index = (((height - 1 - y) * width) + x) * 4
                rgba[index] = color.r
                rgba[index + 1] = color.g
                rgba[index + 2] = color.b
                rgba[index + 3] = color.a
            }
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

    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    private static let palette: [RGBA] = [
        RGBA(r: 0, g: 0, b: 0, a: 0),
        RGBA(r: 0, g: 0, b: 0, a: 255),
        RGBA(r: 248, g: 200, b: 120, a: 255),
        RGBA(r: 221, g: 97, b: 13, a: 255),
        RGBA(r: 176, g: 255, b: 0, a: 255),
        RGBA(r: 80, g: 170, b: 255, a: 255),
        RGBA(r: 255, g: 255, b: 255, a: 255),
        RGBA(r: 146, g: 106, b: 74, a: 255)
    ]

    private static let oldManPixels: [[UInt8]] = [
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,2,2,2,2,2,2,2,2,2,2,1,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,1,2,2,2,2,2,1,2,2,2,1,0],
        [0,1,2,2,2,2,3,2,2,3,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,3,3,3,3,3,3,3,3,3,3,2,1,0],
        [0,1,2,3,4,4,4,3,3,4,4,4,3,2,1,0],
        [0,1,2,3,4,4,4,3,3,4,4,4,3,2,1,0],
        [0,1,2,3,3,3,3,3,3,3,3,3,3,2,1,0],
        [0,1,2,2,2,3,3,3,3,3,3,2,2,2,1,0],
        [0,1,2,2,2,3,3,3,3,3,3,2,2,2,1,0],
        [0,1,2,2,2,3,3,1,1,3,3,2,2,2,1,0],
        [0,0,1,1,2,3,3,0,0,3,3,2,1,1,0,0],
        [0,0,0,1,1,3,3,0,0,3,3,1,1,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0]
    ]

    private static let moblinPixels: [[UInt8]] = [
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,7,7,7,7,2,2,7,7,7,7,1,1,0],
        [0,1,7,7,1,7,7,2,2,7,7,1,7,7,1,0],
        [0,1,7,7,7,7,7,2,2,7,7,7,7,7,1,0],
        [0,1,7,1,7,7,7,2,2,7,7,7,1,7,1,0],
        [0,1,7,7,7,1,7,2,2,7,1,7,7,7,1,0],
        [0,1,7,7,7,7,7,7,7,7,7,7,7,7,1,0],
        [0,1,3,3,3,3,3,7,7,3,3,3,3,3,1,0],
        [0,1,3,4,4,4,3,7,7,3,4,4,4,3,1,0],
        [0,1,3,3,3,3,3,7,7,3,3,3,3,3,1,0],
        [0,1,3,3,3,3,3,7,7,3,3,3,3,3,1,0],
        [0,1,3,3,1,3,3,7,7,3,3,1,3,3,1,0],
        [0,0,1,3,3,3,3,1,1,3,3,3,3,1,0,0],
        [0,0,1,1,3,3,1,0,0,1,3,3,1,1,0,0],
        [0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0]
    ]

    private static let woodenSwordPixels: [[UInt8]] = [
        [0,0,0,0,0,0,6,6,6,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,5,5,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,5,5,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,5,5,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,5,5,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,5,5,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,5,5,6,0,0,0,0,0,0],
        [0,0,0,0,0,6,6,5,5,6,6,0,0,0,0,0],
        [0,0,0,0,0,6,3,3,3,3,6,0,0,0,0,0],
        [0,0,0,0,0,0,6,3,3,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,3,3,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,7,7,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,7,7,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,6,7,7,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,7,7,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0]
    ]

    private static let whiteSwordPixels = woodenSwordPixels.map { row in
        row.map { $0 == 5 ? UInt8(6) : $0 }
    }

    private static let magicSwordPixels = woodenSwordPixels.map { row in
        row.map { $0 == 5 ? UInt8(5) : ($0 == 3 ? UInt8(6) : $0) }
    }

    private static let genericItemPixels: [[UInt8]] = [
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,2,2,2,2,2,2,2,2,1,0,0,0],
        [0,0,1,2,2,2,2,2,2,2,2,2,2,1,0,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,3,3,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,3,3,3,3,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,3,3,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,0,1,2,2,2,2,2,2,2,2,2,2,1,0,0],
        [0,0,0,1,2,2,2,2,2,2,2,2,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0]
    ]
}
