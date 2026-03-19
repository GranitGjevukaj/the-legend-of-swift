import Foundation
import ZeldaContent
import ZeldaCore

enum CaveDialogueResolver {
    static func message(
        for state: GameState,
        overworldData: OverworldData?,
        textEntries: [String: String]
    ) -> String? {
        guard
            state.cave != nil,
            let overworldData,
            let screen = overworldData.screens.first(where: {
                $0.column == state.currentScreen.column && $0.row == state.currentScreen.row
            }),
            let caveIndex = screen.caveIndex,
            let definition = overworldData.caveDefinitions?.first(where: { $0.index == caveIndex })
        else {
            return nil
        }

        if shouldHideDialogue(definition: definition, roomFlags: state.currentRoomFlags) {
            return nil
        }

        return resolvedMessage(for: definition, textEntries: textEntries)
    }

    private static func resolvedMessage(for definition: CaveDefinition, textEntries: [String: String]) -> String? {
        if isTakeTypeCave(personType: definition.personType) {
            return textEntries["old_man_sword"] ?? "IT'S DANGEROUS TO GO ALONE! TAKE THIS."
        }

        if isMoblinCave(personType: definition.personType) {
            return textEntries["moblin_secret"] ?? "IT'S A SECRET TO EVERYBODY."
        }

        if isShop(definition: definition) {
            return textEntries["merchant_bait"] ?? "BUY SOMETHIN' WILL YA!"
        }

        return nil
    }

    private static func shouldHideDialogue(definition: CaveDefinition, roomFlags: Int) -> Bool {
        guard (roomFlags & 0x10) != 0 else {
            return false
        }

        return isTakeTypeCave(personType: definition.personType)
    }

    private static func isTakeTypeCave(personType: Int) -> Bool {
        switch personType {
        case 0x6A...0x6D, 0x71, 0x72:
            return true
        default:
            return personType >= 0x7B
        }
    }

    private static func isMoblinCave(personType: Int) -> Bool {
        personType >= 0x7B
    }

    private static func isShop(definition: CaveDefinition) -> Bool {
        definition.items.contains(where: { $0.price > 0 })
    }
}
