import Foundation

public struct PaletteBundle: Codable, Equatable, Sendable {
    public var nesColors: [String]
    public var areaPalettes: [String: [Int]]
    public var areaPaletteSets: [String: [[Int]]]?
    public var spritePalettes: [String: [Int]]

    public init(
        nesColors: [String],
        areaPalettes: [String: [Int]],
        areaPaletteSets: [String: [[Int]]]? = nil,
        spritePalettes: [String: [Int]]
    ) {
        self.nesColors = nesColors
        self.areaPalettes = areaPalettes
        self.areaPaletteSets = areaPaletteSets
        self.spritePalettes = spritePalettes
    }
}
