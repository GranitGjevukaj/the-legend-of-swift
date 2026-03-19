import Foundation

public struct Position: Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct ScreenCoordinate: Codable, Equatable, Hashable, Sendable {
    public var column: Int
    public var row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

public enum Direction: String, Codable, CaseIterable, Sendable {
    case up
    case down
    case left
    case right
}

public struct InputState: Codable, Equatable, Sendable {
    public var direction: Direction?
    public var buttonA: Bool
    public var buttonB: Bool
    public var start: Bool

    public init(direction: Direction? = nil, buttonA: Bool = false, buttonB: Bool = false, start: Bool = false) {
        self.direction = direction
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.start = start
    }

    public static let idle = InputState()
}

public enum GamePhase: Equatable, Sendable {
    case title
    case fileSelect
    case playing
    case scrolling(ScrollTransition)
    case paused
    case dead
}

public enum GameEvent: Equatable, Sendable {
    case moved(to: Position)
    case enteredScreen(ScreenCoordinate)
    case enteredCave(ScreenCoordinate)
    case exitedCave(ScreenCoordinate)
    case collectedItem(ItemDefinition.Kind)
    case tookDamage(amount: Int)
    case enemyDefeated(Enemy.Kind)
}

public struct GameState: Sendable {
    public private(set) var slot: Int
    public private(set) var overworld: Overworld
    public private(set) var currentScreen: ScreenCoordinate
    public private(set) var cave: CaveState?
    public private(set) var link: Link
    public private(set) var enemies: [Enemy]
    public private(set) var projectiles: [Projectile]
    public private(set) var inventory: Inventory
    public private(set) var phase: GamePhase

    public init(
        slot: Int = 0,
        overworld: Overworld = .starterOverworld(),
        currentScreen: ScreenCoordinate = ScreenCoordinate(column: 7, row: 3),
        cave: CaveState? = nil,
        link: Link = Link.spawnPoint,
        enemies: [Enemy] = [],
        projectiles: [Projectile] = [],
        inventory: Inventory = .empty,
        phase: GamePhase = .title
    ) {
        self.slot = slot
        self.overworld = overworld
        self.currentScreen = currentScreen
        self.cave = cave
        self.link = link
        self.enemies = enemies
        self.projectiles = projectiles
        self.inventory = inventory
        self.phase = phase
    }

    public mutating func startNewGame(slot: Int) {
        startNewGame(slot: slot, startScreen: ScreenCoordinate(column: 7, row: 3))
    }

    public mutating func startNewGame(slot: Int, startScreen: ScreenCoordinate) {
        startNewGame(slot: slot, startScreen: startScreen, startLink: nil)
    }

    public mutating func startNewGame(slot: Int, startScreen: ScreenCoordinate, startLink: Link?) {
        self.slot = slot
        currentScreen = startScreen
        cave = nil
        link = startLink ?? .spawnPoint
        enemies = []
        projectiles = []
        inventory = .starter
        phase = .playing
        loadEnemiesForCurrentScreen()
    }

    @discardableResult
    public mutating func tick(input: InputState) -> [GameEvent] {
        switch phase {
        case .title:
            if input.start {
                phase = .fileSelect
            }
            return []
        case .fileSelect:
            if input.start {
                startNewGame(slot: slot)
            }
            return []
        case .paused, .dead:
            if input.start {
                phase = .playing
            }
            return []
        case .scrolling(var transition):
            transition.advanceFrame()
            if transition.isComplete {
                currentScreen = transition.destination
                phase = .playing
                loadEnemiesForCurrentScreen()
                return [.enteredScreen(currentScreen)]
            }
            phase = .scrolling(transition)
            return []
        case .playing:
            return tickPlaying(input: input)
        }
    }

    public func roomFlags(at coordinate: ScreenCoordinate) -> Int {
        overworld.flags(at: coordinate)
    }

    public var currentRoomFlags: Int {
        roomFlags(at: currentScreen)
    }

    private mutating func tickPlaying(input: InputState) -> [GameEvent] {
        var events: [GameEvent] = []

        if input.start {
            phase = .paused
            return events
        }

        if let direction = input.direction {
            let step = link.speed
            let candidate = link.position.moved(direction: direction, step: step)

            if let cave, cave.shouldExit(candidate: candidate, direction: direction) {
                exitCave(cave)
                events.append(.exitedCave(currentScreen))
                return events
            }

            if cave == nil, shouldStartScroll(candidate: candidate, direction: direction) {
                startScroll(direction: direction)
                return events
            }

            if currentRoom.isWalkable(pixelPosition: candidate) {
                link.facing = direction
                link.position = candidate
                events.append(.moved(to: candidate))

                if
                    cave == nil,
                    direction == .up,
                    let entrance = overworld.caveEntrance(at: currentScreen, pixelPosition: candidate)
                {
                    enterCave(entrance)
                    events.append(.enteredCave(currentScreen))
                    return events
                }

                if
                    cave != nil,
                    (currentRoomFlags & 0x10) == 0,
                    let pickup = overworld.cavePickup(at: currentScreen, pixelPosition: candidate)
                {
                    collectCavePickup(pickup)
                    events.append(.collectedItem(pickup.kind))
                    return events
                }
            }
        }

        if input.buttonA {
            if let defeatedEnemy = resolveSwordHit() {
                events.append(.enemyDefeated(defeatedEnemy))
            }
        }

        tickProjectiles()
        tickEnemies()
        evaluateCollisions(events: &events)
        return events
    }

    private var currentRoom: Room {
        cave?.room ?? overworld.room(at: currentScreen) ?? .starterRoom()
    }

    private mutating func startScroll(direction: Direction) {
        let destination = currentScreen.moved(direction: direction)
        guard overworld.room(at: destination) != nil else { return }
        phase = .scrolling(ScrollTransition(direction: direction, origin: currentScreen, destination: destination))
    }

    private func shouldStartScroll(candidate: Position, direction: Direction) -> Bool {
        switch direction {
        case .left:
            candidate.x < Room.tileSize
        case .right:
            candidate.x >= (Room.pixelWidth - Room.tileSize)
        case .up:
            candidate.y < Room.tileSize
        case .down:
            candidate.y >= (Room.pixelHeight - Room.tileSize)
        }
    }

    private mutating func resolveSwordHit() -> Enemy.Kind? {
        let swordRange = link.swordHitbox
        for (index, enemy) in enemies.enumerated() where HitDetection.overlaps(a: swordRange, b: enemy.hitbox) {
            let damage = DamageTable.default.damage(weapon: .sword(level: inventory.swordLevel), against: enemy.kind)
            var mutableEnemy = enemy
            mutableEnemy.hitPoints -= damage
            if mutableEnemy.hitPoints <= 0 {
                enemies.remove(at: index)
                return enemy.kind
            }
            enemies[index] = mutableEnemy
            return nil
        }
        return nil
    }

    private mutating func tickProjectiles() {
        for (index, projectile) in projectiles.enumerated().reversed() {
            var mutableProjectile = projectile
            mutableProjectile.advance()
            if currentRoom.isWalkable(pixelPosition: mutableProjectile.position) {
                projectiles[index] = mutableProjectile
            } else {
                projectiles.remove(at: index)
            }
        }
    }

    private mutating func tickEnemies() {
        enemies = enemies.map { enemy in
            var mutableEnemy = enemy
            mutableEnemy.tick(towards: link.position, in: currentRoom)
            return mutableEnemy
        }
    }

    private mutating func evaluateCollisions(events: inout [GameEvent]) {
        for enemy in enemies where HitDetection.overlaps(a: link.hitbox, b: enemy.hitbox) {
            link.hearts = max(0, link.hearts - enemy.contactDamage)
            events.append(.tookDamage(amount: enemy.contactDamage))
            if link.hearts == 0 {
                phase = .dead
            }
            break
        }
    }

    private mutating func loadEnemiesForCurrentScreen() {
        if cave != nil {
            enemies = []
        } else {
            enemies = overworld.defaultEnemies(at: currentScreen)
        }
    }

    private mutating func enterCave(_ entrance: CaveEntrance) {
        cave = CaveState(parentScreen: currentScreen, entrance: entrance)
        link.position = CaveState.spawnPosition
        link.facing = .up
        loadEnemiesForCurrentScreen()
    }

    private mutating func exitCave(_ cave: CaveState) {
        self.cave = nil
        link.position = cave.entrance.exteriorSpawnPosition
        link.facing = .down
        loadEnemiesForCurrentScreen()
    }

    private mutating func collectCavePickup(_ pickup: CavePickup) {
        overworld.roomFlags[currentScreen] = currentRoomFlags | 0x10

        switch pickup.kind {
        case .woodenSword:
            inventory.swordLevel = max(inventory.swordLevel, 1)
            inventory.unlockedItems.insert(.woodenSword)
        case .whiteSword:
            inventory.swordLevel = max(inventory.swordLevel, 2)
            inventory.unlockedItems.insert(.whiteSword)
        case .magicSword:
            inventory.swordLevel = max(inventory.swordLevel, 3)
            inventory.unlockedItems.insert(.magicSword)
        case .bomb:
            inventory.bombs += 4
            inventory.unlockedItems.insert(.bomb)
        default:
            inventory.unlockedItems.insert(pickup.kind)
        }
    }
}

extension ScreenCoordinate {
    func moved(direction: Direction) -> ScreenCoordinate {
        switch direction {
        case .up:
            return ScreenCoordinate(column: column, row: row - 1)
        case .down:
            return ScreenCoordinate(column: column, row: row + 1)
        case .left:
            return ScreenCoordinate(column: column - 1, row: row)
        case .right:
            return ScreenCoordinate(column: column + 1, row: row)
        }
    }
}

extension Position {
    func moved(direction: Direction, step: Int) -> Position {
        switch direction {
        case .up:
            return Position(x: x, y: y - step)
        case .down:
            return Position(x: x, y: y + step)
        case .left:
            return Position(x: x - step, y: y)
        case .right:
            return Position(x: x + step, y: y)
        }
    }
}
