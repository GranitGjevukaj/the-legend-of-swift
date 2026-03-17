import Foundation

struct TextParser {
    func parseText(from _: URL?) -> [String: String] {
        [
            "old_man_sword": "IT'S DANGEROUS TO GO ALONE! TAKE THIS.",
            "moblin_secret": "IT'S A SECRET TO EVERYBODY.",
            "merchant_bait": "BUY SOMETHIN' WILL YA!",
            "dungeon_hint": "DODONGO DISLIKES SMOKE."
        ]
    }

    func parseAudio(from _: URL?) -> [String: String] {
        [
            "overworld_theme": "tempo:132;instrument:pulse",
            "dungeon_theme": "tempo:118;instrument:triangle",
            "boss_theme": "tempo:150;instrument:noise",
            "sfx_sword": "channel:pulse;length:short"
        ]
    }
}
