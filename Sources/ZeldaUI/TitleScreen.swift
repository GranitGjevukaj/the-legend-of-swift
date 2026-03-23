import AppKit
import CoreGraphics
import SwiftUI
import ZeldaContent

public struct TitleScreen: View {
    public var titleScreen: TitleScreenData?
    public var palettes: PaletteBundle?
    public var onStart: () -> Void

    private let renderedImage: NSImage?

    public init(
        titleScreen: TitleScreenData? = nil,
        palettes: PaletteBundle? = nil,
        onStart: @escaping () -> Void
    ) {
        self.titleScreen = titleScreen
        self.palettes = palettes
        self.onStart = onStart
        if let titleScreen {
            renderedImage = NESTitleFrameRenderer.makeImage(from: titleScreen, palettes: palettes)
        } else {
            renderedImage = nil
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let renderedImage {
                Image(nsImage: renderedImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(256.0 / 240.0, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fallbackView
            }

            TitleScreenShortcuts(onStart: onStart)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onStart)
    }

    private var fallbackView: some View {
        VStack(spacing: 16) {
            Text("THE LEGEND OF SWIFT")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Button("Start") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct TitleScreenShortcuts: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button("") { onStart() }
                .keyboardShortcut(.return, modifiers: [])
            Button("") { onStart() }
                .keyboardShortcut(.space, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .accessibilityHidden(true)
    }
}

private enum NESTitleFrameRenderer {
    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    static func makeImage(from data: TitleScreenData, palettes: PaletteBundle?) -> NSImage? {
        let tileColumns = max(1, data.tileColumns)
        let tileRows = max(1, data.tileRows)
        let width = tileColumns * 8
        let height = tileRows * 8
        let tileCount = tileColumns * tileRows
        let attributeColumns = (tileColumns + 3) / 4
        let attributeRows = (tileRows + 3) / 4
        let attributeCount = attributeColumns * attributeRows

        guard
            data.nametable.count >= tileCount,
            data.attributeTable.count >= attributeCount,
            data.backgroundPatternTable.count >= 0x1000
        else {
            return nil
        }

        var rgba = Array(repeating: UInt8(0), count: width * height * 4)
        let paletteRows = resolvePaletteRows(paletteRam: data.paletteRam, palettes: palettes)

        for tileY in 0..<tileRows {
            for tileX in 0..<tileColumns {
                let tileIndex = Int(data.nametable[(tileY * tileColumns) + tileX])
                let paletteSelector = paletteSelector(
                    x: tileX,
                    y: tileY,
                    attributeTable: data.attributeTable,
                    attributeColumns: attributeColumns
                )
                let palette = paletteRows[min(max(0, paletteSelector), paletteRows.count - 1)]

                for pixelY in 0..<8 {
                    for pixelX in 0..<8 {
                        let slot = colorSlot(
                            tileIndex: tileIndex,
                            x: pixelX,
                            y: pixelY,
                            patternTable: data.backgroundPatternTable
                        )
                        let color = palette[min(max(0, slot), 3)]
                        let absoluteX = (tileX * 8) + pixelX
                        let absoluteY = (tileY * 8) + pixelY
                        let outputIndex = ((absoluteY * width) + absoluteX) * 4

                        rgba[outputIndex] = color.r
                        rgba[outputIndex + 1] = color.g
                        rgba[outputIndex + 2] = color.b
                        rgba[outputIndex + 3] = color.a
                    }
                }
            }
        }

        guard let cgImage = makeCGImage(rgba: rgba, width: width, height: height) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private static func paletteSelector(
        x: Int,
        y: Int,
        attributeTable: [UInt8],
        attributeColumns: Int
    ) -> Int {
        let attributeX = x / 4
        let attributeY = y / 4
        let attributeIndex = (attributeY * attributeColumns) + attributeX
        guard attributeTable.indices.contains(attributeIndex) else {
            return 0
        }

        let attribute = Int(attributeTable[attributeIndex])
        let quadrantX = (x % 4) / 2
        let quadrantY = (y % 4) / 2
        let shift = (quadrantY * 4) + (quadrantX * 2)
        return (attribute >> shift) & 0x03
    }

    private static func colorSlot(
        tileIndex: Int,
        x: Int,
        y: Int,
        patternTable: [UInt8]
    ) -> Int {
        let tileOffset = tileIndex * 16
        guard tileOffset >= 0, tileOffset + 15 < patternTable.count else {
            return 0
        }

        let low = patternTable[tileOffset + y]
        let high = patternTable[tileOffset + y + 8]
        let bit = 7 - x
        let lowBit = (low >> bit) & 0x01
        let highBit = (high >> bit) & 0x01
        return Int(lowBit | (highBit << 1))
    }

    private static func resolvePaletteRows(paletteRam: [UInt8], palettes: PaletteBundle?) -> [[RGBA]] {
        let colors = palettes?.nesColors ?? fallbackNESColors
        let universalIndex = Int((paletteRam[safe: 0] ?? 0x0F) & 0x3F)
        let universal = rgbaColor(index: universalIndex, nesColors: colors)

        var rows: [[RGBA]] = []
        rows.reserveCapacity(4)

        for row in 0..<4 {
            let base = row * 4
            let c1 = rgbaColor(index: Int((paletteRam[safe: base + 1] ?? 0) & 0x3F), nesColors: colors)
            let c2 = rgbaColor(index: Int((paletteRam[safe: base + 2] ?? 0) & 0x3F), nesColors: colors)
            let c3 = rgbaColor(index: Int((paletteRam[safe: base + 3] ?? 0) & 0x3F), nesColors: colors)
            rows.append([universal, c1, c2, c3])
        }

        return rows
    }

    private static func rgbaColor(index: Int, nesColors: [String]) -> RGBA {
        guard nesColors.indices.contains(index) else {
            return RGBA(r: 0, g: 0, b: 0, a: 255)
        }

        let value = nesColors[index]
        guard value.hasPrefix("#"), value.count == 7 else {
            return RGBA(r: 0, g: 0, b: 0, a: 255)
        }

        let hex = String(value.dropFirst())
        guard let color = Int(hex, radix: 16) else {
            return RGBA(r: 0, g: 0, b: 0, a: 255)
        }

        return RGBA(
            r: UInt8((color >> 16) & 0xFF),
            g: UInt8((color >> 8) & 0xFF),
            b: UInt8(color & 0xFF),
            a: 255
        )
    }

    private static func makeCGImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
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
            return nil
        }

        return image
    }

    private static let fallbackNESColors = [
        "#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000", "#881400",
        "#503000", "#007800", "#006800", "#005800", "#004058", "#000000", "#000000", "#000000",
        "#BCBCBC", "#0078F8", "#0058F8", "#6844FC", "#D800CC", "#E40058", "#F83800", "#E45C10",
        "#AC7C00", "#00B800", "#00A800", "#00A844", "#008888", "#000000", "#000000", "#000000",
        "#F8F8F8", "#3CBCFC", "#6888FC", "#9878F8", "#F878F8", "#F85898", "#F87858", "#FCA044",
        "#F8B800", "#B8F818", "#58D854", "#58F898", "#00E8D8", "#787878", "#000000", "#000000",
        "#FCFCFC", "#A4E4FC", "#B8B8F8", "#D8B8F8", "#F8B8F8", "#F8A4C0", "#F0D0B0", "#FCE0A8",
        "#F8D878", "#D8F878", "#B8F8B8", "#B8F8D8", "#00FCFC", "#F8D8F8", "#000000", "#000000"
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
