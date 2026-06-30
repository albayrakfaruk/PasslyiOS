import SwiftData
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Query(filter: #Predicate<WalletCard> { $0.deletedAt == nil }, sort: \WalletCard.updatedAt, order: .reverse)
    private var cards: [WalletCard]
    @State private var query = ""
    @State private var showPaywall = false

    private var results: [WalletCard] {
        guard !query.isEmpty else { return cards }
        return cards.filter { card in
            [card.title, card.subtitle, card.type.displayName, card.barcode?.altText, card.barcode?.value]
                .compactMap(\.self)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ZStack {
            PremiumBackground()
            if container.entitlementService.isProUnlocked {
                List(results) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        Label {
                            VStack(alignment: .leading) {
                                Text(card.title)
                                Text(card.type.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: card.type.defaultSymbol)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else {
                LockedFeatureView(
                    title: "Unlock Passly to search passes",
                    message: "Monthly or Lifetime Pro is required before creating, organizing, and searching your pass vault.",
                    action: { showPaywall = true }
                )
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Title, fields, code, tags")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(container)
        }
    }
}
