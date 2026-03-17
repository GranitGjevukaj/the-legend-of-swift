import Foundation
import ZeldaContent

struct ItemTableParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> [ItemData] {
        let base = fallbackItems()
        let blocks = repository.load(from: sourceURL)
        let itemBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.itemData)

        guard !itemBytes.isEmpty else {
            return base
        }

        return base.enumerated().map { index, item in
            let byte = itemBytes[index % itemBytes.count]
            if item.shopPrice == nil {
                return item
            }

            let price = Int(byte) * 2
            return ItemData(id: item.id, name: item.name, shopPrice: max(10, min(255, price)))
        }
    }

    private func fallbackItems() -> [ItemData] {
        [
            ItemData(id: "wooden_sword", name: "Wooden Sword", shopPrice: nil),
            ItemData(id: "white_sword", name: "White Sword", shopPrice: nil),
            ItemData(id: "magic_sword", name: "Magic Sword", shopPrice: nil),
            ItemData(id: "bomb", name: "Bomb", shopPrice: 20),
            ItemData(id: "boomerang", name: "Boomerang", shopPrice: 60),
            ItemData(id: "candle", name: "Blue Candle", shopPrice: 60),
            ItemData(id: "arrow", name: "Arrow", shopPrice: 80)
        ]
    }
}
