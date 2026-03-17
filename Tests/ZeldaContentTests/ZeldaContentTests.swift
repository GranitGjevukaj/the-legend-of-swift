import Foundation
import XCTest
@testable import ZeldaContent

final class ZeldaContentTests: XCTestCase {
    func testDecodeRoundTripMapData() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let expected = OverworldData(
            width: 16,
            height: 8,
            screens: [
                OverworldScreen(id: "OW_00_00", column: 0, row: 0, metatileGrid: Array(repeating: 0, count: 16 * 11), exits: ["north"])
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(expected)
        try data.write(to: tempDir.appendingPathComponent("overworld.json"))

        let loader = ContentLoader(baseURL: tempDir)
        let decoded: OverworldData = try loader.decode("overworld.json")

        XCTAssertEqual(decoded, expected)
    }
}
