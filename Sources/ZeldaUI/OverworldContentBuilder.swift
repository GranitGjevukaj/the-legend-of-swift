import Foundation
import ZeldaContent
import ZeldaCore

enum OverworldContentBuilder {
    static func build(from data: OverworldData?) -> Overworld {
        var overworld = Overworld.starterOverworld()
        guard let data else {
            return overworld
        }

        for screen in data.screens {
            let coordinate = ScreenCoordinate(column: screen.column, row: screen.row)
            let roomFlags = screen.roomFlags ?? 0
            var collisionMask = Array(repeating: false, count: Room.columns * Room.rows)

            for row in 0..<Room.rows {
                for column in 0..<Room.columns {
                    let sourceIndex = row * Room.columns + column
                    guard screen.metatileGrid.indices.contains(sourceIndex) else { continue }

                    let destinationRow = (Room.rows - 1) - row
                    let destinationIndex = destinationRow * Room.columns + column
                    let descriptor = screen.metatileGrid[sourceIndex]
                    collisionMask[destinationIndex] = OverworldSquareDecoder.isWalkable(
                        descriptor: descriptor,
                        roomFlags: roomFlags
                    )
                }
            }
            overworld.rooms[coordinate] = Room(coordinate: coordinate, collisionMask: collisionMask)
        }

        return overworld
    }
}
