import CoreGraphics
import Foundation
import SpriteKit
import ZeldaContent
import ZeldaCore

enum LinkSpriteAtlas {
    struct TextureSet {
        let walk: [Direction: [SKTexture]]
        let attack: [Direction: [SKTexture]]
    }

    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    static func makeTextureSet(from bundle: PaletteBundle?, spriteSheet: SpriteSheet?) -> TextureSet {
        guard let extracted = extractedTextureSet(from: spriteSheet, bundle: bundle) else {
            let empty = transparentTexture()
            let emptyDirectional: [Direction: [SKTexture]] = Direction.allCases.reduce(into: [:]) { partial, direction in
                partial[direction] = [empty]
            }
            return TextureSet(walk: emptyDirectional, attack: emptyDirectional)
        }

        return extracted
    }

    private static func extractedTextureSet(from spriteSheet: SpriteSheet?, bundle: PaletteBundle?) -> TextureSet? {
        guard
            let spriteSheet,
            let horizontal0 = frame(named: "horizontal_0", in: spriteSheet),
            let horizontal1 = frame(named: "horizontal_1", in: spriteSheet),
            let down = frame(named: "down", in: spriteSheet),
            let up = frame(named: "up", in: spriteSheet)
        else {
            return nil
        }

        let attackHorizontal0 = frame(named: "horizontal_attack_0", in: spriteSheet) ?? horizontal0
        let attackHorizontal1 = frame(named: "horizontal_attack_1", in: spriteSheet) ?? horizontal1
        let attackDown = frame(named: "down_attack", in: spriteSheet) ?? down
        let attackUp = frame(named: "up_attack", in: spriteSheet) ?? up
        let downStep1 = frame(named: "down_step_1", in: spriteSheet) ?? mirrorHorizontally(down)
        let upStep1 = frame(named: "up_step_1", in: spriteSheet) ?? mirrorHorizontally(up)

        let palette = extractedPalette(from: bundle)

        let walk: [Direction: [SKTexture]] = [
            .right: [
                texture(from: horizontal0, extractedPalette: palette),
                texture(from: horizontal1, extractedPalette: palette)
            ],
            .left: [
                texture(from: mirrorHorizontally(horizontal0), extractedPalette: palette),
                texture(from: mirrorHorizontally(horizontal1), extractedPalette: palette)
            ],
            .down: [
                texture(from: down, extractedPalette: palette),
                texture(from: downStep1, extractedPalette: palette)
            ],
            .up: [
                texture(from: up, extractedPalette: palette),
                texture(from: upStep1, extractedPalette: palette)
            ]
        ]

        let attack: [Direction: [SKTexture]] = [
            .right: [
                texture(from: attackHorizontal0, extractedPalette: palette),
                texture(from: attackHorizontal1, extractedPalette: palette)
            ],
            .left: [
                texture(from: mirrorHorizontally(attackHorizontal0), extractedPalette: palette),
                texture(from: mirrorHorizontally(attackHorizontal1), extractedPalette: palette)
            ],
            .down: [
                texture(from: attackDown, extractedPalette: palette),
                texture(from: attackDown, extractedPalette: palette)
            ],
            .up: [
                texture(from: attackUp, extractedPalette: palette),
                texture(from: attackUp, extractedPalette: palette)
            ]
        ]

        return TextureSet(walk: walk, attack: attack)
    }

    private static func frame(named id: String, in spriteSheet: SpriteSheet) -> [UInt8]? {
        guard
            let frame = spriteSheet.frames.first(where: { $0.id == id }),
            let pixels = frame.pixels,
            pixels.count == 16 * 16
        else {
            return nil
        }
        return pixels
    }

    private static func extractedPalette(from bundle: PaletteBundle?) -> [RGBA] {
        let fallback = [
            RGBA(r: 0, g: 0, b: 0, a: 0),
            RGBA(r: 0, g: 168, b: 0, a: 255),
            RGBA(r: 0, g: 0, b: 0, a: 255),
            RGBA(r: 240, g: 208, b: 176, a: 255)
        ]

        guard
            let bundle,
            let indices = bundle.spritePalettes["link"],
            indices.count >= 4
        else {
            return fallback
        }

        // Sprite pixels map directly to palette slots 1...3.
        let slot1 = color(bundle: bundle, index: indices[1]) ?? fallback[1]
        let slot2 = color(bundle: bundle, index: indices[2]) ?? fallback[2]
        let slot3 = color(bundle: bundle, index: indices[3]) ?? fallback[3]
        return [fallback[0], slot1, slot2, slot3]
    }

    private static func color(bundle: PaletteBundle, index: Int) -> RGBA? {
        guard bundle.nesColors.indices.contains(index) else {
            return nil
        }
        return parseHexColor(bundle.nesColors[index])
    }

    private static func parseHexColor(_ hex: String) -> RGBA? {
        guard hex.count == 7, hex.hasPrefix("#") else {
            return nil
        }

        let valueString = String(hex.dropFirst())
        guard let value = Int(valueString, radix: 16) else {
            return nil
        }

        let r = UInt8((value >> 16) & 0xFF)
        let g = UInt8((value >> 8) & 0xFF)
        let b = UInt8(value & 0xFF)
        return RGBA(r: r, g: g, b: b, a: 255)
    }

    private static func mirrorHorizontally(_ pixels: [UInt8]) -> [UInt8] {
        var mirrored = Array(repeating: UInt8(0), count: 16 * 16)
        for row in 0..<16 {
            for column in 0..<16 {
                let source = (row * 16) + column
                let destination = (row * 16) + (15 - column)
                mirrored[destination] = pixels[source]
            }
        }
        return mirrored
    }

    private static func texture(from pixels: [UInt8], extractedPalette: [RGBA]) -> SKTexture {
        var rgba = Array(repeating: UInt8(0), count: 16 * 16 * 4)
        for (index, pixel) in pixels.enumerated() {
            let color = extractedPalette.indices.contains(Int(pixel)) ? extractedPalette[Int(pixel)] : RGBA(r: 0, g: 0, b: 0, a: 0)
            let base = index * 4
            rgba[base] = color.r
            rgba[base + 1] = color.g
            rgba[base + 2] = color.b
            rgba[base + 3] = color.a
        }

        return texture(from: rgba)
    }

    private static func texture(from rgba: [UInt8]) -> SKTexture {
        let data = Data(rgba) as CFData
        guard
            let provider = CGDataProvider(data: data),
            let image = CGImage(
                width: 16,
                height: 16,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 64,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return transparentTexture()
        }

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func transparentTexture() -> SKTexture {
        let bytes: [UInt8] = [0, 0, 0, 0]
        let data = Data(bytes) as CFData
        let provider = CGDataProvider(data: data)!
        let image = CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
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
}
