import PassKit
import SwiftData
import SwiftUI

struct CardDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: WalletCard
    @State private var flipped = false
    @State private var showEditor = false
    @State private var generating = false
    @State private var message: String?
    @State private var unlocked = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                VStack(spacing: 24) {
                    flipCard
                    actionGrid
                    if let barcode = card.barcode {
                        CodeImageView(payload: barcode)
                            .frame(maxHeight: 260)
                            .padding(.horizontal)
                    }
                    WalletPreviewView(card: card)
                    privateFields
                }
                .padding()
            }
        }
        .navigationTitle(card.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { requirePro { showEditor = true } } label: { Image(systemName: "slider.horizontal.3") }
            }
        }
        .sheet(isPresented: $showEditor) { ManualCardEditorView(existingCard: card, source: card.source) }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(container)
        }
        .alert("Passly", isPresented: Binding(get: { message != nil }, set: { _ in message = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private var flipCard: some View {
        ZStack {
            PremiumPassCardView(card: card, isBack: flipped)
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: reduceMotion ? 0 : 0.75)
                .scaleEffect(flipped ? CGSize(width: -1, height: 1) : CGSize(width: 1, height: 1))
        }
        .onTapGesture {
            withAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.55, dampingFraction: 0.82)) {
                flipped.toggle()
            }
        }
        .sensoryFeedback(.selection, trigger: flipped)
        .accessibilityAction(named: flipped ? "Show front" : "Show back") { flipped.toggle() }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
            Button { Task { await generatePass() } } label: {
                Label(generating ? "Generating" : "Add to Wallet", systemImage: "wallet.pass")
                    .frame(maxWidth: .infinity)
            }
            .disabled(generating)
            .buttonStyle(.borderedProminent)

            Button {
                requirePro { showEditor = true }
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                requirePro {
                    let duplicate = WalletCard(title: "\(card.title) Copy", subtitle: card.subtitle, type: card.type, source: .duplicate, barcode: card.barcode, design: card.design, fields: card.fields)
                    modelContext.insert(duplicate)
                    try? modelContext.save()
                }
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                card.isArchived = true
                try? modelContext.save()
            } label: {
                Label("Archive", systemImage: "archivebox")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .tint(PasslyTheme.accent)
    }

    @ViewBuilder
    private var privateFields: some View {
        let sensitive = card.fields.filter(\.isSensitive)
        if !sensitive.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Private")
                        .font(.headline)
                    Spacer()
                    Button(unlocked ? "Lock" : "Unlock") {
                        if unlocked {
                            unlocked = false
                        } else if !container.entitlementService.isProUnlocked {
                            showPaywall = true
                        } else {
                            Task { unlocked = await BiometricGate().authenticate() }
                        }
                    }
                }
                ForEach(sensitive) { field in
                    HStack {
                        Text(field.label)
                        Spacer()
                        Text(unlocked ? field.value : "Hidden")
                            .foregroundStyle(PasslyTheme.textSecondary)
                    }
                    .font(.subheadline)
                }
            }
            .foregroundStyle(PasslyTheme.textPrimary)
            .padding()
            .glassPanel()
        }
    }

    private func generatePass() async {
        guard container.entitlementService.isProUnlocked else {
            showPaywall = true
            return
        }
        guard container.remoteConfig.flags.walletExportEnabled else {
            message = "Wallet export is currently unavailable. Your card is saved."
            return
        }
        generating = true
        card.status = .generatingPass
        container.analytics.track(.walletGenerationStarted)
        do {
            let generated = try await container.passGenerationService.generatePass(for: card)
            card.walletPassSerialNumber = generated.serialNumber
            card.walletPassTypeIdentifier = generated.passTypeIdentifier
            card.walletPassStoragePath = generated.storagePath
            card.status = generated.passData == nil ? .walletReady : .walletAdded
            card.lastWalletUpdateAt = .now
            try? modelContext.save()
            container.analytics.track(.walletGenerationSuccess)
            message = generated.passData == nil
                ? "Mock pass generated. Connect Firebase certificates to download a signed .pkpass."
                : "Your pass is ready."
        } catch {
            card.status = .generationFailed
            container.analytics.track(.walletGenerationFailed)
            message = PasslyError.walletGenerationFailed.localizedDescription
        }
        generating = false
    }

    private func requirePro(_ action: () -> Void) {
        guard container.entitlementService.isProUnlocked else {
            showPaywall = true
            return
        }
        action()
    }
}

struct WalletPreviewView: View {
    let card: WalletCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Wallet Preview")
                    .font(.headline)
                Spacer()
                Text(card.status.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PasslyTheme.accent)
            }
            PremiumPassCardView(card: card)
                .scaleEffect(0.88)
                .frame(height: 190)
            if let barcode = card.barcode, barcode.format.walletCompatibleFormat != barcode.format {
                Label("This code type may not be supported by Apple Wallet. We can convert the value into a QR code instead.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .foregroundStyle(PasslyTheme.textPrimary)
        .padding()
        .glassPanel()
    }
}
