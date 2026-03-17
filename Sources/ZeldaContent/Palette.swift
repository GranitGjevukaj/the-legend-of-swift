import Foundation

public struct PaletteBundle: Codable, Equatable, Sendable {
    public var nesColors: [String]
    public var areaPalettes: [String: [Int]]
    public var spritePalettes: [String: [Int]]

    public init(nesColors: [String], areaPalettes: [String: [Int]], spritePalettes: [String: [Int]]) {
        self.nesColors = nesColors
        self.areaPalettes = areaPalettes
        self.spritePalettes = spritePalettes
    }
}
