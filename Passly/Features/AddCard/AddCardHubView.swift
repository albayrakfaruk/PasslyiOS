import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AddCardHubView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @State private var showManual = false
    @State private var showPaste = false
    @State private var showScanner = false
    @State private var showPDFImporter = false
    @State private var showPaywall = false
    @State private var photoItem: PhotosPickerItem?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PremiumBackground()
            if container.entitlementService.isProUnlocked {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        AddCardTile(title: "Scan QR / Barcode", symbol: "qrcode.viewfinder") { showScanner = true }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            AddCardTileContent(title: "Import Photo", symbol: "photo")
                        }
                        AddCardTile(title: "Import PDF", symbol: "doc.richtext") { showPDFImporter = true }
                        AddCardTile(title: "Paste Code", symbol: "doc.on.clipboard") { showPaste = true }
                        AddCardTile(title: "Scan NFC Tag", symbol: "wave.3.right") { Task { await scanNFC() } }
                        AddCardTile(title: "Create Manually", symbol: "square.and.pencil") { showManual = true }
                    }
                    .padding(20)

                    Label("Scan readable NFC tags. If the tag contains public text or a URL, Passly can turn it into a Wallet pass.", systemImage: "shield")
                        .font(.caption)
                        .foregroundStyle(PasslyTheme.textSecondary)
                        .padding()
                        .glassPanel()
                        .padding(.horizontal, 20)
                }
            } else {
                LockedFeatureView(
                    title: "Unlock Passly to create passes",
                    message: "Monthly or Lifetime Pro is required before scanning, importing, or creating Wallet-ready passes.",
                    action: { showPaywall = true }
                )
            }
        }
        .navigationTitle("Add Card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showManual) { ManualCardEditorView(source: .manual) }
        .sheet(isPresented: $showPaste) { PasteCreateView() }
        .sheet(isPresented: $showScanner) { ScannerFlowView() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(container)
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
            Task { await handlePDF(result) }
        }
        .onChange(of: photoItem) { _, newValue in
            Task { await handlePhoto(newValue) }
        }
        .alert("Passly", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            showPaywall = !container.entitlementService.isProUnlocked
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        do {
            let result = try await container.importAnalyzer.analyzeImage(image)
            insertCard(from: result, source: .photoImport)
        } catch {
            errorMessage = "We could not analyze that photo. You can still create a manual pass."
        }
    }

    private func handlePDF(_ result: Result<URL, Error>) async {
        do {
            let url = try result.get()
            let analysis = try await container.importAnalyzer.analyzePDF(url)
            insertCard(from: analysis, source: .pdfImport)
        } catch {
            errorMessage = "We could not import that PDF. Your files are not uploaded."
        }
    }

    private func scanNFC() async {
        do {
            let payload = try await container.nfcService.readNDEF()
            let text = payload.urlString ?? payload.rawText ?? ""
            let analysis = try await container.importAnalyzer.analyzeText(text)
            let card = WalletCard(title: analysis.suggestedTitle, type: analysis.suggestedType, source: .nfcTag, barcode: analysis.barcode, design: analysis.design, fields: analysis.fields)
            card.nfcPayloadData = try? JSONEncoder.passly.encode(payload)
            modelContext.insert(card)
            try? modelContext.save()
            container.analytics.track(.nfcReadSuccess)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func insertCard(from result: ImportAnalysisResult, source: CardSource) {
        let card = WalletCard(title: result.suggestedTitle, type: result.suggestedType, source: source, barcode: result.barcode, design: result.design, fields: result.fields)
        modelContext.insert(card)
        try? modelContext.save()
        container.analytics.track(.cardCreated)
    }
}

private struct AddCardTile: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AddCardTileContent(title: title, symbol: symbol)
        }
        .buttonStyle(.plain)
    }
}

private struct AddCardTileContent: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PasslyTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(PasslyTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(height: 118)
        .glassPanel()
    }
}

struct PasteCreateView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Code, text, or link") {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle("Paste Code")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() async {
        guard let result = try? await container.importAnalyzer.analyzeText(text) else { return }
        let card = WalletCard(title: result.suggestedTitle, type: result.suggestedType, source: .pastedCode, barcode: result.barcode, design: result.design, fields: result.fields)
        modelContext.insert(card)
        try? modelContext.save()
        container.analytics.track(.cardCreated)
        dismiss()
    }
}
