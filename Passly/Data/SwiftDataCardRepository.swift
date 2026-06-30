import Foundation
import SwiftData

@MainActor
struct SwiftDataCardRepository: CardRepository {
    let context: ModelContext

    func fetchCards() async throws -> [WalletCard] {
        let descriptor = FetchDescriptor<WalletCard>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func save(_ card: WalletCard) async throws {
        card.updatedAt = .now
        context.insert(card)
        try context.save()
    }

    func delete(_ card: WalletCard) async throws {
        card.deletedAt = .now
        card.updatedAt = .now
        try context.save()
    }

    func archive(_ card: WalletCard) async throws {
        card.isArchived = true
        card.updatedAt = .now
        try context.save()
    }

    func search(query: String) async throws -> [WalletCard] {
        let all = try await fetchCards()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        return all.filter { card in
            [card.title, card.subtitle, card.type.displayName, card.barcode?.altText, card.barcode?.value]
                .compactMap(\.self)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}
