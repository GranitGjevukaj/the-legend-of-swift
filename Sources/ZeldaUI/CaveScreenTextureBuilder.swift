import CoreGraphics
import Foundation
import SpriteKit
import ZeldaContent
import ZeldaCore

enum CaveScreenTextureBuilder {
    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    static func buildTexture(layout: CaveLayout?, tileSet: TileSet?) -> SKTexture {
        guard let layout else {
            return buildFallbackTexture()
        }

        let width = Room.pixelWidth
        let height = Room.pixelHeight
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)
        let tileCount = max(1, tileSet?.tiles.count ?? 0)
        let paletteRows = cavePaletteRows

        for tileRow in 0..<Room.rows {
            for tileColumn in 0..<Room.columns {
                let gridIndex = (tileRow * Room.columns) + tileColumn
                guard layout.metatileGrid.indices.contains(gridIndex) else { continue }

                let descriptor = abs(layout.metatileGrid[gridIndex])
                let paletteSelector = layout.paletteSelectorGrid?[gridIndex] ?? defaultPaletteSelector(for: descriptor)
                let palette = paletteRows[min(max(0, paletteSelector), paletteRows.count - 1)]
                let squareTiles = OverworldSquareDecoder.tiles(for: descriptor)

                for pixelY in 0..<Room.tileSize {
                    for pixelX in 0..<Room.tileSize {
                        let subtileOffset = metatileOffset(x: pixelX, y: pixelY)
                        let sourceTile = squareTiles[subtileOffset]
                        let tileIndex = sourceTile % tileCount
                        let tilePixels = tileSet?.tiles[tileIndex].pixels
                        let colorSlot = sampleColorSlot(
                            descriptor: descriptor,
                            tilePixels: tilePixels,
                            x: pixelX,
                            y: pixelY
                        )
                        let color = palette[colorSlot]
                        let absoluteX = (tileColumn * Room.tileSize) + pixelX
                        let absoluteY = (tileRow * Room.tileSize) + pixelY
                        let outputIndex = ((absoluteY * width) + absoluteX) * 4

                        rgba[outputIndex] = color.r
                        rgba[outputIndex + 1] = color.g
                        rgba[outputIndex + 2] = color.b
                        rgba[outputIndex + 3] = color.a
                    }
                }
            }
        }

        return texture(from: rgba, width: width, height: height)
    }

    private static func buildFallbackTexture() -> SKTexture {
        let width = Room.pixelWidth
        let height = Room.pixelHeight
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)

        let wallDark = RGBA(r: 41, g: 18, b: 10, a: 255)
        let wallLight = RGBA(r: 109, g: 52, b: 18, a: 255)
        let floorBase = RGBA(r: 246, g: 214, b: 151, a: 255)
        let floorShade = RGBA(r: 236, g: 202, b: 138, a: 255)
        let doorway = RGBA(r: 8, g: 8, b: 8, a: 255)

        let wallThickness = Room.tileSize
        let doorwayStart = 6 * Room.tileSize
        let doorwayEnd = 10 * Room.tileSize
        let interiorMinX = wallThickness
        let interiorMaxX = width - wallThickness
        let interiorMinY = wallThickness
        let interiorMaxY = height - wallThickness

        for y in 0..<height {
            for x in 0..<width {
                let color: RGBA

                if y < wallThickness && x >= doorwayStart && x < doorwayEnd {
                    color = doorway
                } else if x < interiorMinX || x >= interiorMaxX || y >= interiorMaxY {
                    color = ((x / 8) + (y / 8)).isMultiple(of: 2) ? wallLight : wallDark
                } else if y < interiorMinY {
                    color = doorway
                } else {
                    color = ((x / 16) + (y / 16)).isMultiple(of: 2) ? floorBase : floorShade
                }

                let index = ((y * width) + x) * 4
                rgba[index] = color.r
                rgba[index + 1] = color.g
                rgba[index + 2] = color.b
                rgba[index + 3] = color.a
            }
        }

        return texture(from: rgba, width: width, height: height)
    }

    private static func defaultPaletteSelector(for descriptor: Int) -> Int {
        switch descriptor {
        case 0, 2, 10:
            return 0
        case 27, 39, 44, 53:
            return 2
        default:
            return 1
        }
    }

    private static func metatileOffset(x: Int, y: Int) -> Int {
        let isRight = x >= 8
        let isBottom = y >= 8

        switch (isRight, isBottom) {
        case (false, false):
            return 0
        case (false, true):
            return 1
        case (true, false):
            return 2
        case (true, true):
            return 3
        }
    }

    private static func sampleColorSlot(
        descriptor: Int,
        tilePixels: [UInt8]?,
        x: Int,
        y: Int
    ) -> Int {
        if let tilePixels, tilePixels.count >= 64 {
            let sourceX = x % 8
            let sourceY = y % 8
            let index = (sourceY * 8) + sourceX
            return Int(tilePixels[index] & 0x03)
        }

        return (descriptor + (x / 4) + (y / 4)) & 0x03
    }

    private static let cavePaletteRows: [[RGBA]] = [
        [
            RGBA(r: 0, g: 0, b: 0, a: 255),
            RGBA(r: 49, g: 20, b: 9, a: 255),
            RGBA(r: 135, g: 61, b: 12, a: 255),
            RGBA(r: 249, g: 221, b: 163, a: 255)
        ],
        [
            RGBA(r: 0, g: 0, b: 0, a: 255),
            RGBA(r: 66, g: 31, b: 8, a: 255),
            RGBA(r: 187, g: 91, b: 18, a: 255),
            RGBA(r: 254, g: 234, b: 180, a: 255)
        ],
        [
            RGBA(r: 0, g: 0, b: 0, a: 255),
            RGBA(r: 24, g: 17, b: 15, a: 255),
            RGBA(r: 84, g: 64, b: 54, a: 255),
            RGBA(r: 196, g: 166, b: 114, a: 255)
        ],
        [
            RGBA(r: 0, g: 0, b: 0, a: 255),
            RGBA(r: 27, g: 12, b: 6, a: 255),
            RGBA(r: 110, g: 42, b: 12, a: 255),
            RGBA(r: 228, g: 189, b: 129, a: 255)
        ]
    ]

    private static func texture(from rgba: [UInt8], width: Int, height: Int) -> SKTexture {
        let data = Data(rgba) as CFData
        guard
            let provider = CGDataProvider(data: data),
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
            )
        else {
            return SKTexture()
        }

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}
