import Foundation
import ZeldaExtractCLI

@main
struct ZeldaExtractEntryPoint {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())

        let sourcePath = value(for: "--source", in: arguments)
        let outputPath = value(for: "--output", in: arguments)
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Content/Zelda", isDirectory: true)
                .path()

        let config = ExtractionConfig(
            sourceURL: sourcePath.map { URL(fileURLWithPath: $0, isDirectory: true) },
            outputURL: URL(fileURLWithPath: outputPath, isDirectory: true)
        )

        let writtenFiles = try ZeldaExtractor(config: config).run()

        FileHandle.standardOutput.write(Data("Extracted \(writtenFiles.count) artifacts\n".utf8))
        for file in writtenFiles {
            FileHandle.standardOutput.write(Data("- \(file.path())\n".utf8))
        }
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = index + 1
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}
