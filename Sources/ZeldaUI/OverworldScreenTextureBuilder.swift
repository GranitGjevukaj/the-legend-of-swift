import CoreGraphics
import Foundation
import SpriteKit
import ZeldaContent
import ZeldaCore

enum OverworldScreenTextureBuilder {
    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    static func buildTexture(screen: OverworldScreen, tileSet: TileSet?, palettes: PaletteBundle?) -> SKTexture {
        let width = Room.pixelWidth
        let height = Room.pixelHeight
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)

        let paletteRows = resolvedPaletteRows(from: palettes)
        let tileCount = max(1, tileSet?.tiles.count ?? 0)

        for tileRow in 0..<Room.rows {
            for tileColumn in 0..<Room.columns {
                let gridIndex = (tileRow * Room.columns) + tileColumn
                guard screen.metatileGrid.indices.contains(gridIndex) else { continue }
                let paletteSelector = screen.paletteSelectorGrid?[gridIndex] ?? 0
                let palette = paletteRows[min(max(0, paletteSelector), paletteRows.count - 1)]
                let roomFlags = screen.roomFlags ?? 0

                let descriptor = abs(screen.metatileGrid[gridIndex])
                let squareTiles = OverworldSquareDecoder.tiles(for: descriptor, roomFlags: roomFlags)

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

    private static func metatileOffset(x: Int, y: Int) -> Int {
        let isRight = x >= 8
        let isBottom = y >= 8

        switch (isRight, isBottom) {
        case (false, false):
            return 0 // top-left
        case (false, true):
            return 1 // bottom-left
        case (true, false):
            return 2 // top-right
        case (true, true):
            return 3 // bottom-right
        }
    }

    private static func resolvedPaletteRows(from palettes: PaletteBundle?) -> [[RGBA]] {
        let fallbackPaletteRow = [
            RGBA(r: 20, g: 20, b: 28, a: 255),
            RGBA(r: 46, g: 84, b: 42, a: 255),
            RGBA(r: 94, g: 160, b: 78, a: 255),
            RGBA(r: 198, g: 216, b: 112, a: 255)
        ]
        let fallbackRows = Array(repeating: fallbackPaletteRow, count: 4)

        guard
            let palettes
        else {
            return fallbackRows
        }

        if
            let rowIndices = palettes.areaPaletteSets?["overworld"],
            rowIndices.count >= 4
        {
            let rows = rowIndices.prefix(4).map { row in
                row.prefix(4).compactMap { color(from: palettes, index: $0) }
            }

            if rows.count == 4, rows.allSatisfy({ $0.count == 4 }) {
                return rows
            }
        }

        guard
            let area = palettes.areaPalettes["overworld"],
            area.count >= 4
        else {
            return fallbackRows
        }

        let colors = area.prefix(4).compactMap { color(from: palettes, index: $0) }
        guard colors.count == 4 else {
            return fallbackRows
        }

        return Array(repeating: colors, count: 4)
    }

    private static func color(from palettes: PaletteBundle, index: Int) -> RGBA? {
        guard palettes.nesColors.indices.contains(index) else {
            return nil
        }

        let hex = palettes.nesColors[index]
        guard hex.count == 7, hex.hasPrefix("#") else {
            return nil
        }

        let valueString = String(hex.dropFirst())
        guard let value = Int(valueString, radix: 16) else {
            return nil
        }

        return RGBA(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF),
            a: 255
        )
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
            return fallbackTexture()
        }

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func fallbackTexture() -> SKTexture {
        let bytes: [UInt8] = [22, 22, 26, 255]
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
