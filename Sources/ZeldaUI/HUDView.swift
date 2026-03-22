import SwiftUI
import ZeldaContent
import ZeldaCore

public struct HUDView: View {
    public let state: GameState
    public let paletteBundle: PaletteBundle?
    public let caveSpriteSheet: SpriteSheet?

    public init(
        state: GameState,
        paletteBundle: PaletteBundle? = nil,
        caveSpriteSheet: SpriteSheet? = nil
    ) {
        self.state = state
        self.paletteBundle = paletteBundle
        self.caveSpriteSheet = caveSpriteSheet
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Self.backgroundColor)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Self.frameColor)
                    .frame(height: 2)

                Rectangle()
                    .fill(Self.shadowColor)
                    .frame(height: 1)

                ViewThatFits(in: .horizontal) {
                    wideLayout
                    compactLayout
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Self.Metrics.horizontalInset)
                .padding(.vertical, Self.Metrics.verticalInset)
            }
        }
        .frame(height: Self.Metrics.hudHeight, alignment: .top)
        .clipped()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: Self.Metrics.sectionSpacing) {
            MiniMapPanel(
                screen: state.currentScreen,
                size: Self.Metrics.mapSizeWide
            )

            VStack(alignment: .leading, spacing: Self.Metrics.counterSpacing) {
                HUDCounter(
                    label: "X\(state.inventory.rupees)",
                    color: Self.rupeeColor,
                    icon: {
                        PixelBitmapGlyph(
                            pixels: Bitmaps.rupee,
                            color: Self.rupeeColor,
                            size: Self.Metrics.counterIconSize
                        )
                    }
                )

                HUDCounter(
                    label: "X\(state.inventory.keys)",
                    color: Self.keyColor,
                    icon: {
                        PixelBitmapGlyph(
                            pixels: Bitmaps.key,
                            color: Self.keyColor,
                            size: Self.Metrics.counterIconSize
                        )
                    }
                )

                HUDCounter(
                    label: "X\(state.inventory.bombs)",
                    color: Self.bombColor,
                    icon: {
                        PixelBitmapGlyph(
                            pixels: Bitmaps.bomb,
                            color: Self.bombColor,
                            size: Self.Metrics.counterIconSize
                        )
                    }
                )
            }
            .fixedSize(horizontal: true, vertical: true)

            HStack(spacing: Self.Metrics.slotSpacing) {
                ItemSlotView(
                    title: "B",
                    accent: Self.slotAccent
                )

                ItemSlotView(
                    title: "A",
                    accent: Self.slotAccent,
                    item: aSlotItem
                )
            }
            .fixedSize(horizontal: true, vertical: true)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: Self.Metrics.lifeSpacing) {
                HUDPixelText(
                    "-LIFE-",
                    pixelSize: Self.Metrics.labelPixelSize,
                    color: Self.lifeColor
                )

                HeartsRow(
                    current: state.link.hearts,
                    maximum: state.link.maxHearts
                )
            }
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Self.Metrics.compactSectionSpacing) {
            HStack(alignment: .top, spacing: Self.Metrics.compactSectionSpacing) {
                MiniMapPanel(
                    screen: state.currentScreen,
                    size: Self.Metrics.mapSizeCompact
                )

                VStack(alignment: .leading, spacing: Self.Metrics.counterSpacing) {
                    HUDCounter(
                        label: "X\(state.inventory.rupees)",
                        color: Self.rupeeColor,
                        icon: {
                            PixelBitmapGlyph(
                                pixels: Bitmaps.rupee,
                                color: Self.rupeeColor,
                                size: Self.Metrics.counterIconSize
                            )
                        }
                    )

                    HUDCounter(
                        label: "X\(state.inventory.keys)",
                        color: Self.keyColor,
                        icon: {
                            PixelBitmapGlyph(
                                pixels: Bitmaps.key,
                                color: Self.keyColor,
                                size: Self.Metrics.counterIconSize
                            )
                        }
                    )

                    HUDCounter(
                        label: "X\(state.inventory.bombs)",
                        color: Self.bombColor,
                        icon: {
                            PixelBitmapGlyph(
                                pixels: Bitmaps.bomb,
                                color: Self.bombColor,
                                size: Self.Metrics.counterIconSize
                            )
                        }
                    )
                }
                .fixedSize(horizontal: true, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: Self.Metrics.sectionSpacing) {
                HStack(spacing: Self.Metrics.slotSpacing) {
                    ItemSlotView(
                        title: "B",
                        accent: Self.slotAccent
                    )

                    ItemSlotView(
                        title: "A",
                        accent: Self.slotAccent,
                        item: aSlotItem
                    )
                }
                .fixedSize(horizontal: true, vertical: true)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: Self.Metrics.lifeSpacing) {
                    HUDPixelText(
                        "-LIFE-",
                        pixelSize: Self.Metrics.labelPixelSize,
                        color: Self.lifeColor
                    )

                    HeartsRow(
                        current: state.link.hearts,
                        maximum: state.link.maxHearts
                    )
                }
                .fixedSize(horizontal: true, vertical: true)
            }
        }
    }

    private var swordKind: ItemDefinition.Kind? {
        Self.swordKind(for: state.inventory.swordLevel)
    }

    private var aSlotItem: HUDItemSprite? {
        guard let swordKind else {
            return nil
        }
        return Self.itemSprite(
            for: swordKind,
            caveSpriteSheet: caveSpriteSheet,
            paletteBundle: paletteBundle
        )
    }

    static func swordKind(for level: Int) -> ItemDefinition.Kind? {
        switch level {
        case 3:
            return .magicSword
        case 2:
            return .whiteSword
        case 1:
            return .woodenSword
        default:
            return nil
        }
    }

    private static func itemSprite(
        for kind: ItemDefinition.Kind,
        caveSpriteSheet: SpriteSheet?,
        paletteBundle: PaletteBundle?
    ) -> HUDItemSprite? {
        guard let itemID = swordItemID(for: kind) else {
            return nil
        }

        guard
            let frame = itemFrame(for: itemID, in: caveSpriteSheet),
            let pixels = frame.pixels,
            pixels.count == 16 * 16
        else {
            return nil
        }

        return HUDItemSprite(
            pixels: pixels,
            palette: itemPalette(for: itemID, bundle: paletteBundle)
        )
    }

    private static func swordItemID(for kind: ItemDefinition.Kind) -> Int? {
        switch kind {
        case .woodenSword:
            return 0x01
        case .whiteSword:
            return 0x02
        case .magicSword:
            return 0x03
        default:
            return nil
        }
    }

    private static func itemFrame(for itemID: Int, in spriteSheet: SpriteSheet?) -> SpriteSheet.SpriteFrame? {
        guard let spriteSheet else {
            return nil
        }

        let exact = "item_\(String(format: "%02x", itemID))"
        return spriteSheet.frames.first(where: { $0.id == exact })
    }

    private static func itemPalette(for itemID: Int, bundle: PaletteBundle?) -> [Color] {
        let rgba: [RGBA]
        switch itemID {
        case 0x02:
            rgba = [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255))
            ]
        case 0x03:
            rgba = [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 33, fallback: RGBA(r: 60, g: 188, b: 252, a: 255))
            ]
        default:
            rgba = [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(bundle: bundle, index: 48, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(bundle: bundle, index: 41, fallback: RGBA(r: 184, g: 248, b: 24, a: 255)),
                nesColor(bundle: bundle, index: 24, fallback: RGBA(r: 172, g: 124, b: 0, a: 255))
            ]
        }

        return rgba.map {
            Color(
                red: Double($0.r) / 255.0,
                green: Double($0.g) / 255.0,
                blue: Double($0.b) / 255.0,
                opacity: Double($0.a) / 255.0
            )
        }
    }

    private static func nesColor(bundle: PaletteBundle?, index: Int, fallback: RGBA) -> RGBA {
        guard let bundle, bundle.nesColors.indices.contains(index) else {
            return fallback
        }

        guard let parsed = parseHexColor(bundle.nesColors[index]) else {
            return fallback
        }
        return parsed
    }

    private static func parseHexColor(_ hex: String) -> RGBA? {
        guard hex.count == 7, hex.hasPrefix("#"), let value = Int(String(hex.dropFirst()), radix: 16) else {
            return nil
        }
        return RGBA(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF),
            a: 255
        )
    }

    private static let backgroundColor = Color(red: 0.00, green: 0.00, blue: 0.00)
    private static let frameColor = Color(red: 0.47, green: 0.47, blue: 0.47)
    private static let shadowColor = Color(red: 0.18, green: 0.18, blue: 0.18)
    private static let rupeeColor = Color(red: 0.95, green: 0.74, blue: 0.30)
    private static let keyColor = Color(red: 0.88, green: 0.66, blue: 0.25)
    private static let bombColor = Color(red: 0.30, green: 0.38, blue: 0.92)
    private static let lifeColor = Color(red: 0.83, green: 0.36, blue: 0.26)
    private static let slotAccent = Color(red: 0.32, green: 0.36, blue: 0.95)

    private enum Metrics {
        static let horizontalInset: CGFloat = 18
        static let verticalInset: CGFloat = 8
        static let sectionSpacing: CGFloat = 14
        static let compactSectionSpacing: CGFloat = 10
        static let counterSpacing: CGFloat = 5
        static let lifeSpacing: CGFloat = 3
        static let slotSpacing: CGFloat = 8
        static let labelPixelSize: CGFloat = 2
        static let counterIconSize = CGSize(width: 16, height: 16)
        static let mapSizeWide = CGSize(width: 128, height: 64)
        static let mapSizeCompact = CGSize(width: 96, height: 48)
        static let hudHeight: CGFloat = 96
    }

    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }
}

private struct HUDItemSprite {
    let pixels: [UInt8]
    let palette: [Color]
}

private struct MiniMapPanel: View {
    let screen: ScreenCoordinate
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let columns = CGFloat(Overworld.width)
            let rows = CGFloat(Overworld.height)
            let cellSize = floor(min(canvasSize.width / columns, canvasSize.height / rows))
            let mapWidth = columns * cellSize
            let mapHeight = rows * cellSize
            let originX = (canvasSize.width - mapWidth) / 2
            let originY = (canvasSize.height - mapHeight) / 2
            let boardRect = CGRect(x: originX, y: originY, width: mapWidth, height: mapHeight)

            context.fill(Path(boardRect), with: .color(Color(red: 0.22, green: 0.22, blue: 0.22)))

            for row in 0..<Overworld.height {
                for column in 0..<Overworld.width {
                    let rect = CGRect(
                        x: originX + CGFloat(column) * cellSize,
                        y: originY + CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )

                    let isCurrent = screen.column == column && screen.row == row
                    let fillColor = isCurrent
                        ? Color(red: 0.56, green: 0.83, blue: 0.16)
                        : Color(red: 0.55, green: 0.55, blue: 0.55)
                    context.fill(Path(rect.insetBy(dx: 1, dy: 1)), with: .color(fillColor))
                    context.stroke(Path(rect), with: .color(Color(red: 0.12, green: 0.12, blue: 0.12)), lineWidth: 1)
                }
            }

            let markerRect = CGRect(
                x: originX + CGFloat(screen.column) * cellSize + 2,
                y: originY + CGFloat(screen.row) * cellSize + 2,
                width: max(0, cellSize - 4),
                height: max(0, cellSize - 4)
            )
            context.fill(Path(markerRect), with: .color(Color(red: 0.82, green: 0.96, blue: 0.42)))
            context.stroke(Path(markerRect), with: .color(Color.black), lineWidth: 1)
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            Rectangle()
                .stroke(Color(red: 0.47, green: 0.47, blue: 0.47), lineWidth: 2)
        )
    }
}

private struct HUDCounter<Icon: View>: View {
    let label: String
    let color: Color
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            icon()
            HUDPixelText(label, pixelSize: 2, color: .white)
        }
        .frame(width: 72, alignment: .leading)
    }
}

private struct ItemSlotView: View {
    let title: String
    let accent: Color
    var item: HUDItemSprite? = nil

    var body: some View {
        VStack(spacing: 2) {
            HUDPixelText(title, pixelSize: 2, color: .white)

            ZStack {
                Rectangle()
                    .fill(Color.black)

                Rectangle()
                    .stroke(accent, lineWidth: 2)

                Rectangle()
                    .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 1)
                    .padding(1)

                if let item {
                    ExtractedItemGlyph(item: item)
                }
            }
            .frame(width: 44, height: 52)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

private struct HeartsRow: View {
    let current: Int
    let maximum: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maximum, id: \.self) { index in
                HeartIcon(filled: index < current)
            }
        }
    }
}

private struct HeartIcon: View {
    let filled: Bool

    var body: some View {
        PixelBitmapGlyph(
            pixels: filled ? Bitmaps.fullHeart : Bitmaps.emptyHeart,
            color: filled ? Color(red: 0.83, green: 0.36, blue: 0.26) : Color(red: 0.55, green: 0.18, blue: 0.18),
            size: CGSize(width: 16, height: 16)
        )
    }
}

private struct ExtractedItemGlyph: View {
    let item: HUDItemSprite

    var body: some View {
        Canvas { context, canvasSize in
            let columns = 16
            let rows = 16
            let cellSize = floor(min(canvasSize.width / CGFloat(columns), canvasSize.height / CGFloat(rows)))
            let glyphWidth = CGFloat(columns) * cellSize
            let glyphHeight = CGFloat(rows) * cellSize
            let originX = (canvasSize.width - glyphWidth) / 2
            let originY = (canvasSize.height - glyphHeight) / 2

            for row in 0..<rows {
                for column in 0..<columns {
                    let index = row * columns + column
                    guard item.pixels.indices.contains(index) else {
                        continue
                    }

                    let paletteSlot = Int(item.pixels[index])
                    guard item.palette.indices.contains(paletteSlot) else {
                        continue
                    }

                    guard paletteSlot != 0 else {
                        continue
                    }
                    let color = item.palette[paletteSlot]

                    let rect = CGRect(
                        x: originX + CGFloat(column) * cellSize,
                        y: originY + CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: 32, height: 32)
    }
}

private struct PixelBitmapGlyph: View {
    let pixels: [UInt8]
    let color: Color
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let columns = 8
            let rows = 8
            let cellSize = floor(min(canvasSize.width / CGFloat(columns), canvasSize.height / CGFloat(rows)))
            let glyphWidth = CGFloat(columns) * cellSize
            let glyphHeight = CGFloat(rows) * cellSize
            let originX = (canvasSize.width - glyphWidth) / 2
            let originY = (canvasSize.height - glyphHeight) / 2

            for row in 0..<rows {
                for column in 0..<columns {
                    guard pixelIsSet(row: row, column: column) else {
                        continue
                    }

                    let rect = CGRect(
                        x: originX + CGFloat(column) * cellSize,
                        y: originY + CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func pixelIsSet(row: Int, column: Int) -> Bool {
        if pixels.count == 8 {
            guard pixels.indices.contains(row) else {
                return false
            }
            let mask = UInt8(1 << (7 - column))
            return (pixels[row] & mask) != 0
        }

        let index = row * 8 + column
        guard pixels.indices.contains(index) else {
            return false
        }
        return pixels[index] != 0
    }
}

private struct HUDPixelText: View {
    let string: String
    let pixelSize: CGFloat
    let color: Color

    init(_ string: String, pixelSize: CGFloat, color: Color) {
        self.string = string
        self.pixelSize = pixelSize
        self.color = color
    }

    private let glyphWidth = 5
    private let glyphHeight = 7
    private let characterAdvance = 6
    private let lineAdvance = 8

    var body: some View {
        let metrics = canvasMetrics()

        Canvas { context, _ in
            for (characterIndex, character) in string.uppercased().enumerated() {
                let glyph = HUDGlyphFont.glyph(for: character)
                let originX = CGFloat(characterIndex * characterAdvance) * pixelSize

                for (row, rowBits) in glyph.enumerated() {
                    for column in 0..<glyphWidth {
                        let mask = UInt8(1 << (glyphWidth - 1 - column))
                        guard (rowBits & mask) != 0 else {
                            continue
                        }

                        let rect = CGRect(
                            x: originX + CGFloat(column) * pixelSize,
                            y: CGFloat(row) * pixelSize,
                            width: pixelSize,
                            height: pixelSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: metrics.width, height: metrics.height, alignment: .topLeading)
    }

    private func canvasMetrics() -> CGSize {
        let widthUnits = max(1, (string.uppercased().count * characterAdvance) - 1)
        let heightUnits = max(1, lineAdvance - (lineAdvance - glyphHeight))
        return CGSize(width: CGFloat(widthUnits) * pixelSize, height: CGFloat(heightUnits) * pixelSize)
    }
}

private enum HUDGlyphFont {
    static func glyph(for character: Character) -> [UInt8] {
        let normalized = Character(String(character).uppercased())
        return glyphs[normalized] ?? glyphs["?"]!
    }

    private static let glyphs: [Character: [UInt8]] = [
        " ": [0, 0, 0, 0, 0, 0, 0],
        "-": [0, 0, 0, 0x0E, 0, 0, 0],
        "?": [0x0E, 0x11, 0x01, 0x02, 0x04, 0, 0x04],
        "A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
        "E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
        "F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
        "I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
        "X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
        "0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
        "1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
        "3": [0x1E, 0x01, 0x01, 0x0E, 0x01, 0x01, 0x1E],
        "4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
        "5": [0x1F, 0x10, 0x10, 0x1E, 0x01, 0x01, 0x1E],
        "6": [0x0E, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x0E],
        "7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        "8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        "9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E]
    ]
}

private enum Bitmaps {
    static let rupee: [UInt8] = [
        0b00011000,
        0b00111100,
        0b01111110,
        0b00111100,
        0b00011000,
        0b00011000,
        0b00111100,
        0b01111110
    ]

    static let key: [UInt8] = [
        0b00000000,
        0b00111000,
        0b01111100,
        0b01100110,
        0b00111100,
        0b00011000,
        0b00111110,
        0b00011000
    ]

    static let bomb: [UInt8] = [
        0b00011000,
        0b00111100,
        0b01111110,
        0b01111110,
        0b01111110,
        0b00111100,
        0b00011000,
        0b00010000
    ]

    static let fullHeart: [UInt8] = [
        0b00100100,
        0b01111110,
        0b11111111,
        0b11111111,
        0b11111111,
        0b01111110,
        0b00111100,
        0b00011000
    ]

    static let emptyHeart: [UInt8] = [
        0b00100100,
        0b01011010,
        0b10111101,
        0b10111101,
        0b10111101,
        0b01011010,
        0b00111100,
        0b00011000
    ]

    static let boomerang: [UInt8] = [
        0b00000000,
        0b00111100,
        0b01100110,
        0b00110000,
        0b00011000,
        0b00001100,
        0b01100110,
        0b00111100
    ]

    static let candle: [UInt8] = [
        0b00011000,
        0b00111100,
        0b00111100,
        0b00011000,
        0b00011000,
        0b00111100,
        0b00111100,
        0b00011000
    ]

    static let bow: [UInt8] = [
        0b00011000,
        0b00111100,
        0b01100110,
        0b11000011,
        0b11000011,
        0b01100110,
        0b00111100,
        0b00011000
    ]

    static let block: [UInt8] = [
        0b00111100,
        0b01111110,
        0b01111110,
        0b01111110,
        0b01111110,
        0b01111110,
        0b01111110,
        0b00111100
    ]
}
