import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WalletCard> { $0.deletedAt == nil && !$0.isArchived }, sort: \WalletCard.updatedAt, order: .reverse)
    private var cards: [WalletCard]
    @State private var searchText = ""
    @State private var showPaywall = false
    @State private var showAddCardHub = false
    @State private var showSettings = false
    @State private var selectedCardID: UUID?

    var filteredCards: [WalletCard] {
        guard container.entitlementService.isProUnlocked else { return [] }
        guard !searchText.isEmpty else { return cards }
        return cards.filter { $0.title.localizedCaseInsensitiveContains(searchText) || ($0.subtitle?.localizedCaseInsensitiveContains(searchText) == true) }
    }

    private var expiringCount: Int {
        cards.filter { $0.expiryDate != nil }.count
    }

    private var walletReadyCount: Int {
        cards.filter { $0.status == .walletReady || $0.status == .walletAdded }.count
    }

    private var privateCount: Int {
        cards.filter { $0.requiresBiometricUnlock || $0.fields.contains(where: \.isSensitive) }.count
    }

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchField
                    if !container.entitlementService.isProUnlocked || cards.isEmpty {
                        emptyState
                    } else {
                        insightRail
                        cardStack
                        caseRail
                        passList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(container)
        }
        .navigationDestination(isPresented: $showAddCardHub) {
            AddCardHubView()
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Passly")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PasslyTheme.textPrimary)
                HStack(spacing: 8) {
                    Text(container.entitlementService.isProUnlocked ? "Lifetime Pro" : "Locked")
                    Circle()
                        .fill(PasslyTheme.textSecondary.opacity(0.38))
                        .frame(width: 4, height: 4)
                    Text(container.entitlementService.isProUnlocked ? "\(cards.count) passes" : "Unlock to create")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PasslyTheme.textSecondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                HeaderIcon(symbol: "gearshape")
            }
            .accessibilityLabel("Settings")

            Button {
                if container.entitlementService.isProUnlocked {
                    showAddCardHub = true
                } else {
                    showPaywall = true
                }
            } label: {
                HeaderIcon(symbol: "plus")
            }
            .accessibilityLabel("Add Card")
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PasslyTheme.textSecondary)
            TextField("Search passes", text: $searchText)
                .textInputAutocapitalization(.never)
                .foregroundStyle(PasslyTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PasslyTheme.border, lineWidth: 1)
        )
    }

    private var insightRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                InsightPill(value: "\(cards.count)", label: "Active", symbol: "wallet.pass")
                InsightPill(value: "\(walletReadyCount)", label: "Wallet-ready", symbol: "checkmark.seal")
                InsightPill(value: "\(expiringCount)", label: "Expiring", symbol: "timer")
                InsightPill(value: "\(privateCount)", label: "Private", symbol: "faceid")
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                PremiumPassCardView(card: WalletCard(title: "Cinema Night", subtitle: "Row C, Seat 12", type: .movieTicket, barcode: BarcodePayload(value: "PASSLY-CINEMA", format: .qr, altText: "PASSLY-CINEMA")))
                    .rotationEffect(.degrees(-8))
                    .offset(x: -34, y: 18)
                    .scaleEffect(0.88)
                    .opacity(0.84)
                PremiumPassCardView(card: WalletCard(title: "Coffee Reward", subtitle: "Gold Member", type: .loyalty, barcode: BarcodePayload(value: "PASSLY-DEMO", format: .qr, altText: "PASSLY-DEMO")))
                    .offset(x: 22, y: -8)
            }
            .frame(height: 270)
            .padding(.top, 20)
            Text("Create your first Wallet-ready pass from a code, screenshot, PDF, link, NFC tag, or manual entry.")
                .font(.headline)
                .foregroundStyle(PasslyTheme.textPrimary.opacity(0.86))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                if container.entitlementService.isProUnlocked {
                    showAddCardHub = true
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Add Card", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [PasslyTheme.vividAccent, PasslyTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var cardStack: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(filteredCards) { card in
                        NavigationLink(destination: CardDetailView(card: card)) {
                            PremiumPassCardView(card: card, width: 310, height: 196)
                                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(card.id)
                        .contextMenu {
                            Button(card.isFavorite ? "Remove Favorite" : "Favorite", systemImage: "star") {
                                card.isFavorite.toggle()
                                try? modelContext.save()
                            }
                            Button("Duplicate", systemImage: "doc.on.doc") {
                                let duplicate = WalletCard(title: "\(card.title) Copy", subtitle: card.subtitle, type: card.type, source: .duplicate, barcode: card.barcode, design: card.design, fields: card.fields)
                                modelContext.insert(duplicate)
                                try? modelContext.save()
                            }
                        }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                .opacity(phase.isIdentity ? 1 : 0.78)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedCardID)
            .contentMargins(.trailing, 30, for: .scrollContent)
            .scrollClipDisabled()
            .frame(height: 220)
            .onAppear {
                selectedCardID = selectedCardID ?? filteredCards.first?.id
            }
            .onChange(of: filteredCards.map(\.id)) { _, ids in
                if selectedCardID == nil || !ids.contains(where: { $0 == selectedCardID }) {
                    selectedCardID = ids.first
                }
            }

            HStack(spacing: 6) {
                ForEach(filteredCards.prefix(6)) { card in
                    Capsule()
                        .fill(card.id == selectedCardID ? PasslyTheme.vividAccent : PasslyTheme.quietFill)
                        .frame(width: card.id == selectedCardID ? 18 : 7, height: 7)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var passList: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(searchText.isEmpty ? "All Passes" : "Results")
                    .font(.headline)
                    .foregroundStyle(PasslyTheme.textPrimary)
                Spacer()
                Text("\(filteredCards.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PasslyTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PasslyTheme.controlFill)
                    .clipShape(Capsule())
            }
            VStack(spacing: 10) {
                ForEach(filteredCards) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        ModernPassRow(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var caseRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cases")
                .font(.headline)
                .foregroundStyle(PasslyTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CaseChip(title: "Imports", value: "\(cards.filter { $0.source != .manual }.count)", symbol: "square.and.arrow.down")
                    CaseChip(title: "Ready", value: "\(walletReadyCount)", symbol: "wallet.pass")
                    CaseChip(title: "NFC", value: "\(cards.filter { $0.source == .nfcTag }.count)", symbol: "wave.3.right")
                    CaseChip(title: "Sensitive", value: "\(privateCount)", symbol: "lock.shield")
                }
            }
            .scrollClipDisabled()
        }
    }

}

private struct HeaderIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.headline.weight(.bold))
            .foregroundStyle(PasslyTheme.accent)
            .frame(width: 46, height: 46)
            .background(.thinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(PasslyTheme.border, lineWidth: 1))
            .shadow(color: PasslyTheme.vividAccent.opacity(0.10), radius: 12, x: 0, y: 8)
    }
}

private struct InsightPill: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PasslyTheme.vividAccent)
                .frame(width: 28, height: 28)
                .background(PasslyTheme.controlFill)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PasslyTheme.textPrimary)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PasslyTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PasslyTheme.border, lineWidth: 1))
    }
}

private struct CaseChip: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(PasslyTheme.mint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PasslyTheme.textSecondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PasslyTheme.textPrimary)
            }
        }
        .frame(minWidth: 126, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PasslyTheme.border, lineWidth: 1))
    }
}

private struct ModernPassRow: View {
    let card: WalletCard

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
                Image(systemName: card.type.defaultSymbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(card.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PasslyTheme.textPrimary)
                        .lineLimit(1)
                    if card.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PasslyTheme.amber)
                    }
                }
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(PasslyTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(statusText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.bold))
                .foregroundStyle(PasslyTheme.textSecondary.opacity(0.72))
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PasslyTheme.border, lineWidth: 1))
    }

    private var background: LinearGradient {
        let colors = card.design.gradient?.colors.map(PasslyTheme.color(hex:)) ?? [PasslyTheme.vividAccent, PasslyTheme.accent]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var detailText: String {
        [card.type.displayName, card.subtitle].compactMap { $0 }.joined(separator: " · ")
    }

    private var statusText: String {
        switch card.status {
        case .walletAdded: "Added"
        case .walletReady: "Ready"
        case .generatingPass: "Syncing"
        case .synced: "Synced"
        case .generationFailed: "Issue"
        case .localOnly: "Local"
        }
    }

    private var statusColor: Color {
        switch card.status {
        case .walletAdded, .walletReady, .synced: PasslyTheme.mint
        case .generatingPass: PasslyTheme.accent
        case .generationFailed: PasslyTheme.rose
        case .localOnly: PasslyTheme.amber
        }
    }
}

private struct HomeSection: View {
    let title: String
    let cards: [WalletCard]

    var body: some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PasslyTheme.textPrimary)
                ForEach(cards) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        HStack(spacing: 12) {
                            Image(systemName: card.type.defaultSymbol)
                                .frame(width: 34, height: 34)
                                .background(PasslyTheme.panel)
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(card.title).font(.subheadline.weight(.semibold))
                                Text(card.type.displayName).font(.caption).foregroundStyle(PasslyTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PasslyTheme.textSecondary)
                        }
                        .foregroundStyle(PasslyTheme.textPrimary)
                        .padding(12)
                        .glassPanel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}
