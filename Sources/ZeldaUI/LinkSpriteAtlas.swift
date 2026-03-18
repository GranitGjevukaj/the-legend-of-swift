import CoreGraphics
import Foundation
import SpriteKit
import ZeldaContent
import ZeldaCore

enum LinkSpriteAtlas {
    private struct FallbackPalette {
        let outline: RGBA
        let tunic: RGBA
        let skin: RGBA
        let accent: RGBA
    }

    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    static func makeDirectionalTextures(from bundle: PaletteBundle?, spriteSheet: SpriteSheet?) -> [Direction: [SKTexture]] {
        if let extracted = extractedDirectionalTextures(from: spriteSheet, bundle: bundle) {
            return extracted
        }

        let palette = fallbackPalette(from: bundle)
        var textures: [Direction: [SKTexture]] = [:]

        for direction in Direction.allCases {
            textures[direction] = (0..<2).map { step in
                let pixels = fallbackFrame(direction: direction, step: step)
                return texture(from: pixels, fallbackPalette: palette)
            }
        }

        return textures
    }

    private static func extractedDirectionalTextures(from spriteSheet: SpriteSheet?, bundle: PaletteBundle?) -> [Direction: [SKTexture]]? {
        guard
            let spriteSheet,
            let horizontal0 = frame(named: "horizontal_0", in: spriteSheet),
            let horizontal1 = frame(named: "horizontal_1", in: spriteSheet),
            let down = frame(named: "down", in: spriteSheet),
            let up = frame(named: "up", in: spriteSheet)
        else {
            return nil
        }

        let palette = extractedPalette(from: bundle)
        let left0 = mirrorHorizontally(horizontal0)
        let left1 = mirrorHorizontally(horizontal1)
        let downStep1 = mirrorHorizontally(down)
        let upStep1 = mirrorHorizontally(up)

        return [
            .right: [
                texture(from: horizontal0, extractedPalette: palette),
                texture(from: horizontal1, extractedPalette: palette)
            ],
            .left: [
                texture(from: left0, extractedPalette: palette),
                texture(from: left1, extractedPalette: palette)
            ],
            .down: [
                texture(from: up, extractedPalette: palette),
                texture(from: upStep1, extractedPalette: palette)
            ],
            .up: [
                texture(from: down, extractedPalette: palette),
                texture(from: downStep1, extractedPalette: palette)
            ]
        ]
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
            RGBA(r: 24, g: 24, b: 32, a: 255),
            RGBA(r: 0, g: 168, b: 0, a: 255),
            RGBA(r: 240, g: 208, b: 176, a: 255)
        ]

        guard
            let bundle,
            let indices = bundle.spritePalettes["link"],
            indices.count >= 4
        else {
            return fallback
        }

        let slot1 = color(bundle: bundle, index: indices[1]) ?? fallback[1]
        let slot2 = color(bundle: bundle, index: indices[2]) ?? fallback[2]
        let slot3 = color(bundle: bundle, index: indices[3]) ?? fallback[3]
        return [fallback[0], slot1, slot2, slot3]
    }

    private static func fallbackPalette(from bundle: PaletteBundle?) -> FallbackPalette {
        let fallback = FallbackPalette(
            outline: RGBA(r: 18, g: 20, b: 24, a: 255),
            tunic: RGBA(r: 42, g: 138, b: 72, a: 255),
            skin: RGBA(r: 240, g: 202, b: 160, a: 255),
            accent: RGBA(r: 112, g: 78, b: 48, a: 255)
        )

        guard
            let bundle,
            let indices = bundle.spritePalettes["link"],
            indices.count >= 4
        else {
            return fallback
        }

        let outline = color(bundle: bundle, index: indices[0]) ?? fallback.outline
        let tunic = color(bundle: bundle, index: indices[1]) ?? fallback.tunic
        let skin = color(bundle: bundle, index: indices[2]) ?? fallback.skin
        let accent = color(bundle: bundle, index: indices[3]) ?? fallback.accent
        return FallbackPalette(outline: outline, tunic: tunic, skin: skin, accent: accent)
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

    private static func fallbackFrame(direction: Direction, step: Int) -> [UInt8] {
        switch direction {
        case .down:
            return upFrame(step: step)
        case .up:
            return downFrame(step: step)
        case .left:
            return leftFrame(step: step)
        case .right:
            return mirrorHorizontally(leftFrame(step: step))
        }
    }

    private static func downFrame(step: Int) -> [UInt8] {
        var pixels = emptyFrame()

        fill(&pixels, x: 4, y: 0, width: 8, height: 3, color: 2)
        fill(&pixels, x: 5, y: 3, width: 6, height: 3, color: 3)
        fill(&pixels, x: 5, y: 6, width: 6, height: 6, color: 2)
        fill(&pixels, x: 5, y: 9, width: 6, height: 1, color: 4)

        if step == 0 {
            fill(&pixels, x: 3, y: 7, width: 2, height: 3, color: 2)
            fill(&pixels, x: 11, y: 7, width: 2, height: 3, color: 2)
            fill(&pixels, x: 5, y: 12, width: 2, height: 3, color: 3)
            fill(&pixels, x: 9, y: 12, width: 2, height: 3, color: 3)
        } else {
            fill(&pixels, x: 3, y: 8, width: 2, height: 3, color: 2)
            fill(&pixels, x: 11, y: 6, width: 2, height: 3, color: 2)
            fill(&pixels, x: 4, y: 12, width: 2, height: 3, color: 3)
            fill(&pixels, x: 10, y: 12, width: 2, height: 3, color: 3)
        }

        return outlined(pixels)
    }

    private static func upFrame(step: Int) -> [UInt8] {
        var pixels = emptyFrame()

        fill(&pixels, x: 4, y: 0, width: 8, height: 4, color: 2)
        fill(&pixels, x: 6, y: 3, width: 4, height: 1, color: 3)
        fill(&pixels, x: 5, y: 4, width: 6, height: 8, color: 2)
        fill(&pixels, x: 5, y: 8, width: 6, height: 1, color: 4)

        if step == 0 {
            fill(&pixels, x: 4, y: 7, width: 2, height: 3, color: 2)
            fill(&pixels, x: 10, y: 7, width: 2, height: 3, color: 2)
            fill(&pixels, x: 5, y: 12, width: 2, height: 3, color: 3)
            fill(&pixels, x: 9, y: 12, width: 2, height: 3, color: 3)
        } else {
            fill(&pixels, x: 4, y: 6, width: 2, height: 3, color: 2)
            fill(&pixels, x: 10, y: 8, width: 2, height: 3, color: 2)
            fill(&pixels, x: 4, y: 12, width: 2, height: 3, color: 3)
            fill(&pixels, x: 10, y: 12, width: 2, height: 3, color: 3)
        }

        return outlined(pixels)
    }

    private static func leftFrame(step: Int) -> [UInt8] {
        var pixels = emptyFrame()

        fill(&pixels, x: 4, y: 0, width: 7, height: 3, color: 2)
        fill(&pixels, x: 4, y: 3, width: 3, height: 3, color: 3)
        fill(&pixels, x: 5, y: 4, width: 5, height: 8, color: 2)
        fill(&pixels, x: 5, y: 8, width: 5, height: 1, color: 4)
        fill(&pixels, x: 3, y: 7, width: 2, height: 3, color: 2)
        fill(&pixels, x: 10, y: 7, width: 2, height: 2, color: 3)

        if step == 0 {
            fill(&pixels, x: 5, y: 12, width: 2, height: 3, color: 3)
            fill(&pixels, x: 8, y: 12, width: 2, height: 3, color: 3)
        } else {
            fill(&pixels, x: 4, y: 12, width: 2, height: 3, color: 3)
            fill(&pixels, x: 9, y: 12, width: 2, height: 3, color: 3)
        }

        return outlined(pixels)
    }

    private static func emptyFrame() -> [UInt8] {
        Array(repeating: 0, count: 16 * 16)
    }

    private static func fill(
        _ pixels: inout [UInt8],
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        color: UInt8
    ) {
        guard width > 0, height > 0 else { return }

        let minX = max(0, x)
        let minY = max(0, y)
        let maxX = min(16, x + width)
        let maxY = min(16, y + height)

        guard minX < maxX, minY < maxY else { return }

        for row in minY..<maxY {
            for column in minX..<maxX {
                pixels[(row * 16) + column] = color
            }
        }
    }

    private static func mirrorHorizontally(_ pixels: [UInt8]) -> [UInt8] {
        var mirrored = emptyFrame()
        for row in 0..<16 {
            for column in 0..<16 {
                let source = (row * 16) + column
                let destination = (row * 16) + (15 - column)
                mirrored[destination] = pixels[source]
            }
        }
        return mirrored
    }

    private static func outlined(_ pixels: [UInt8]) -> [UInt8] {
        var result = pixels

        for row in 0..<16 {
            for column in 0..<16 {
                let index = (row * 16) + column
                guard pixels[index] > 1 else { continue }

                for yOffset in -1...1 {
                    for xOffset in -1...1 {
                        if xOffset == 0, yOffset == 0 {
                            continue
                        }
                        let x = column + xOffset
                        let y = row + yOffset
                        guard (0..<16).contains(x), (0..<16).contains(y) else { continue }
                        let neighbor = (y * 16) + x
                        if pixels[neighbor] == 0 {
                            result[neighbor] = 1
                        }
                    }
                }
            }
        }

        return result
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

    private static func texture(from pixels: [UInt8], fallbackPalette: FallbackPalette) -> SKTexture {
        var rgba = Array(repeating: UInt8(0), count: 16 * 16 * 4)
        for (index, pixel) in pixels.enumerated() {
            let color: RGBA
            switch pixel {
            case 1:
                color = fallbackPalette.outline
            case 2:
                color = fallbackPalette.tunic
            case 3:
                color = fallbackPalette.skin
            case 4:
                color = fallbackPalette.accent
            default:
                color = RGBA(r: 0, g: 0, b: 0, a: 0)
            }

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
            return fallbackTexture()
        }

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func fallbackTexture() -> SKTexture {
        let bytes: [UInt8] = [255, 255, 255, 255]
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
