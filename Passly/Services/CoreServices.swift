import AVFoundation
import CoreImage.CIFilterBuiltins
import Foundation
import LocalAuthentication
import PassKit
import SwiftUI
import UserNotifications
import Vision

final class LocalAnonymousAuthService: AuthService {
    private(set) var userID: String? = UserDefaults.standard.string(forKey: "passly.localUserID")

    func signInAnonymouslyIfNeeded() async throws {
        if userID == nil {
            let id = "anon_" + UUID().uuidString
            UserDefaults.standard.set(id, forKey: "passly.localUserID")
            userID = id
        }
    }
}

struct LocalRemoteConfigService: RemoteConfigService {
    var flags = RemoteFeatureFlags()
    func refresh() async {}
}

struct PrivacySafeAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        print("analytics:", event.rawValue)
        #endif
    }
}

struct MockPassGenerationService: PassGenerationService {
    func generatePass(for card: WalletCard) async throws -> GeneratedPass {
        try await Task.sleep(for: .milliseconds(600))
        return GeneratedPass(
            passId: "mock-\(card.id.uuidString)",
            serialNumber: card.walletPassSerialNumber ?? card.id.uuidString,
            passTypeIdentifier: "pass.com.example.passly.mock",
            storagePath: "mock/generated/\(card.id.uuidString).pkpass",
            downloadURL: nil,
            passData: nil
        )
    }

    func updatePass(for card: WalletCard) async throws -> GeneratedPass {
        try await generatePass(for: card)
    }
}

struct FirebasePassGenerationService: PassGenerationService {
    var endpoint: URL
    var idTokenProvider: () async throws -> String

    func generatePass(for card: WalletCard) async throws -> GeneratedPass {
        try await request(path: "generatePass", card: card)
    }

    func updatePass(for card: WalletCard) async throws -> GeneratedPass {
        try await request(path: "updatePass", card: card)
    }

    private func request(path: String, card: WalletCard) async throws -> GeneratedPass {
        var request = URLRequest(url: endpoint.appending(path: path))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(try await idTokenProvider())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.passly.encode(PassGenerationRequest(card: card))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PasslyError.walletGenerationFailed
        }
        return try JSONDecoder.passly.decode(GeneratedPass.self, from: data)
    }
}

private struct PassGenerationRequest: Encodable {
    var cardId: UUID
    var locale: String
    var card: PassCardPayload
    var logoStoragePath: String?

    init(card: WalletCard) {
        self.cardId = card.id
        self.locale = Locale.current.identifier
        self.card = PassCardPayload(card: card)
        self.logoStoragePath = card.logoStoragePath
    }
}

private struct PassCardPayload: Encodable {
    var type: String
    var title: String
    var subtitle: String?
    var barcode: BarcodePayload?
    var design: CardDesign
    var fields: [CardField]
    var backFields: [CardField]
    var relevantDate: Date?
    var expiryDate: Date?

    init(card: WalletCard) {
        self.type = card.type.rawValue
        self.title = card.title
        self.subtitle = card.subtitle
        self.barcode = card.barcode
        self.design = card.design
        self.fields = card.fields.filter { $0.placement != .back && !$0.isSensitive }
        self.backFields = card.fields.filter { $0.placement == .back && !$0.isSensitive }
        self.relevantDate = card.relevantDate
        self.expiryDate = card.expiryDate
    }
}

struct PassKitWalletService: WalletService {
    func canAddPass(_ passData: Data) -> Bool {
        (try? PKPass(data: passData)).map { PKAddPassesViewController.canAddPasses() && !PKPassLibrary().containsPass($0) } ?? false
    }

    func containsPass(serialNumber: String, passTypeIdentifier: String) -> Bool {
        PKPassLibrary().pass(withPassTypeIdentifier: passTypeIdentifier, serialNumber: serialNumber) != nil
    }
}

@MainActor
final class BiometricGate {
    func authenticate(reason: String = "Unlock private Passly fields") async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) == true
    }
}

@MainActor
final class NotificationScheduler {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func schedule(reminder: CardReminder, cardID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "A saved Passly card needs your attention."
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "passly.\(cardID).\(reminder.id)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

struct LocalImportAnalysisService: ImportAnalysisService {
    func analyzeImage(_ image: UIImage) async throws -> ImportAnalysisResult {
        let barcode = try await detectBarcode(in: image.cgImage)
        return ImportAnalysisResult(
            suggestedTitle: barcode?.value.prefix(24).isEmpty == false ? "Scanned Pass" : "Imported Pass",
            suggestedType: .generic,
            barcode: barcode,
            fields: [],
            design: .default
        )
    }

    func analyzePDF(_ url: URL) async throws -> ImportAnalysisResult {
        ImportAnalysisResult(suggestedTitle: url.deletingPathExtension().lastPathComponent, suggestedType: .generic, barcode: nil, fields: [], design: .default)
    }

    func analyzeURL(_ url: URL) async throws -> ImportAnalysisResult {
        ImportAnalysisResult(
            suggestedTitle: url.host(percentEncoded: false) ?? "Link Pass",
            suggestedType: .generic,
            barcode: BarcodePayload(value: url.absoluteString, format: .qr, altText: url.absoluteString),
            fields: [CardField(key: "url", label: "Website", value: url.absoluteString, placement: .back)],
            design: .default
        )
    }

    func analyzeText(_ text: String) async throws -> ImportAnalysisResult {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ImportAnalysisResult(
            suggestedTitle: inferTitle(from: value),
            suggestedType: inferType(from: value),
            barcode: value.isEmpty ? nil : BarcodePayload(value: value, format: value.hasPrefix("http") ? .qr : .code128, altText: value),
            fields: [],
            design: .default
        )
    }

    private func detectBarcode(in cgImage: CGImage?) async throws -> BarcodePayload? {
        guard let cgImage else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observation = request.results?.compactMap { $0 as? VNBarcodeObservation }.first
                let format = observation?.symbology.passlyFormat ?? .unsupported
                continuation.resume(returning: observation?.payloadStringValue.map {
                    BarcodePayload(value: $0, format: format, originalFormat: format, walletExportFormat: format.walletCompatibleFormat, altText: $0)
                })
            }
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }

    private func inferTitle(from text: String) -> String {
        if let url = URL(string: text), let host = url.host(percentEncoded: false) { return host }
        return text.isEmpty ? "New Pass" : "Pasted Code"
    }

    private func inferType(from text: String) -> CardType {
        let lower = text.lowercased()
        if ["coupon", "promo", "voucher", "indirim", "kupon"].contains(where: lower.contains) { return .coupon }
        if ["ticket", "event", "seat", "koltuk"].contains(where: lower.contains) { return .eventTicket }
        if ["reservation", "booking", "rezervasyon"].contains(where: lower.contains) { return .restaurantReservation }
        return .generic
    }
}

extension VNBarcodeSymbology {
    var passlyFormat: BarcodeFormat {
        switch self {
        case .qr: .qr
        case .code128: .code128
        case .pdf417: .pdf417
        case .aztec: .aztec
        case .ean13: .ean13
        case .ean8: .ean8
        case .upce: .upce
        case .code39: .code39
        case .codabar: .codabar
        case .itf14: .itf
        case .dataMatrix: .dataMatrix
        default: .unsupported
        }
    }
}

enum PasslyError: LocalizedError {
    case walletGenerationFailed
    case nfcUnavailable
    case unsupportedSecureNFC

    var errorDescription: String? {
        switch self {
        case .walletGenerationFailed:
            "We could not generate your Wallet pass right now. Your card is saved, and you can try again anytime."
        case .nfcUnavailable:
            "This device cannot read NFC tags."
        case .unsupportedSecureNFC:
            "This NFC item cannot be read by Passly. Secure cards like payment cards, hotel keys, access cards, and transit cards cannot be copied."
        }
    }
}
