import SwiftData
import SwiftUI

struct ManualCardEditorView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingCard: WalletCard?
    let source: CardSource

    @State private var title: String
    @State private var subtitle: String
    @State private var type: CardType
    @State private var codeValue: String
    @State private var barcodeFormat: BarcodeFormat
    @State private var backgroundHex: String
    @State private var requiresBiometricUnlock: Bool
    @State private var expiryDate: Date
    @State private var hasExpiry = false
    @State private var privateNote = ""

    init(existingCard: WalletCard? = nil, source: CardSource = .manual) {
        self.existingCard = existingCard
        self.source = source
        _title = State(initialValue: existingCard?.title ?? "")
        _subtitle = State(initialValue: existingCard?.subtitle ?? "")
        _type = State(initialValue: existingCard?.type ?? .generic)
        _codeValue = State(initialValue: existingCard?.barcode?.value ?? "")
        _barcodeFormat = State(initialValue: existingCard?.barcode?.format ?? .qr)
        _backgroundHex = State(initialValue: existingCard?.design.backgroundColorHex ?? CardDesign.default.backgroundColorHex)
        _requiresBiometricUnlock = State(initialValue: existingCard?.requiresBiometricUnlock ?? false)
        _expiryDate = State(initialValue: existingCard?.expiryDate ?? .now.addingTimeInterval(60 * 60 * 24 * 30))
        _hasExpiry = State(initialValue: existingCard?.expiryDate != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        PremiumPassCardView(card: previewCard)
                            .padding(.top)

                        editorForm
                    }
                    .padding()
                }
            }
            .navigationTitle(existingCard == nil ? "Create Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var editorForm: some View {
        VStack(spacing: 14) {
            formSection("Content") {
                TextField("Title", text: $title)
                TextField("Subtitle", text: $subtitle)
                Picker("Type", selection: $type) {
                    ForEach(CardType.allCases) { Text($0.displayName).tag($0) }
                }
            }

            formSection("Code") {
                TextField("QR or barcode value", text: $codeValue, axis: .vertical)
                Picker("Format", selection: $barcodeFormat) {
                    ForEach(BarcodeFormat.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
                if barcodeFormat.walletCompatibleFormat != barcodeFormat {
                    Label("Apple Wallet may not support this barcode type. Passly can create a QR version using the same value.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            formSection("Design") {
                Picker("Template", selection: $backgroundHex) {
                    Text("Midnight Glass").tag("#111318")
                    Text("Pearl White").tag("#F7F4EF")
                    Text("Emerald Silk").tag("#0D4F3C")
                    Text("Sunset Copper").tag("#A85332")
                    Text("Deep Blue").tag("#12234A")
                }
            }

            formSection("Reminders & Privacy") {
                Toggle("Expiry reminder", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("Expiry date", selection: $expiryDate, displayedComponents: [.date, .hourAndMinute])
                }
                Toggle("Require Face ID to open", isOn: $requiresBiometricUnlock)
                TextField("Private note", text: $privateNote, axis: .vertical)
            }
        }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PasslyTheme.textPrimary)
            content()
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .glassPanel()
        .tint(PasslyTheme.accent)
    }

    private var previewCard: WalletCard {
        let card = WalletCard(title: title.isEmpty ? "New Pass" : title, subtitle: subtitle, type: type, source: source, barcode: barcodePayload, design: previewDesign, fields: fields)
        card.requiresBiometricUnlock = requiresBiometricUnlock
        card.expiryDate = hasExpiry ? expiryDate : nil
        return card
    }

    private var previewDesign: CardDesign {
        var design = CardDesign.default
        design.backgroundColorHex = backgroundHex
        design.gradient = GradientSpec(colors: [backgroundHex, "#08090C"], startPoint: "topLeading", endPoint: "bottomTrailing")
        return design
    }

    private var barcodePayload: BarcodePayload? {
        let value = codeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return BarcodePayload(value: value, format: barcodeFormat, originalFormat: barcodeFormat, walletExportFormat: barcodeFormat.walletCompatibleFormat, altText: value)
    }

    private var fields: [CardField] {
        privateNote.isEmpty ? [] : [CardField(key: "private_note", label: "Private Note", value: privateNote, placement: .appOnlySensitive, isHiddenInWallet: true, isSensitive: true)]
    }

    private func save() {
        let card = existingCard ?? WalletCard(title: title, type: type, source: source)
        card.title = title
        card.subtitle = subtitle.isEmpty ? nil : subtitle
        card.type = type
        card.source = source
        card.barcode = barcodePayload
        card.design = previewDesign
        card.fields = fields
        card.requiresBiometricUnlock = requiresBiometricUnlock
        card.expiryDate = hasExpiry ? expiryDate : nil
        card.updatedAt = .now
        if hasExpiry {
            card.reminders = [CardReminder(title: "\(title) expires soon", date: expiryDate.addingTimeInterval(-86_400), kind: .expiry)]
        }
        modelContext.insert(card)
        try? modelContext.save()
        Task {
            for reminder in card.reminders {
                await container.notificationService.schedule(reminder: reminder, cardID: card.id)
            }
        }
        container.analytics.track(.cardCreated)
        dismiss()
    }
}
