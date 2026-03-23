import Foundation

public struct TitleScreenData: Codable, Equatable, Sendable {
    public var tileColumns: Int
    public var tileRows: Int
    public var nametable: [UInt8]
    public var attributeTable: [UInt8]
    public var paletteRam: [UInt8]
    public var backgroundPatternTable: [UInt8]

    public init(
        tileColumns: Int,
        tileRows: Int,
        nametable: [UInt8],
        attributeTable: [UInt8],
        paletteRam: [UInt8],
        backgroundPatternTable: [UInt8]
    ) {
        self.tileColumns = tileColumns
        self.tileRows = tileRows
        self.nametable = nametable
        self.attributeTable = attributeTable
        self.paletteRam = paletteRam
        self.backgroundPatternTable = backgroundPatternTable
    }
}
