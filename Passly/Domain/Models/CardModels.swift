import Foundation
import SwiftData
import SwiftUI

@Model
final class WalletCard {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String?
    var typeRawValue: String
    var sourceRawValue: String
    var statusRawValue: String
    var barcodeData: Data?
    var nfcPayloadData: Data?
    var designData: Data?
    var fieldsData: Data?
    var remindersData: Data?
    var logoLocalPath: String?
    var logoStoragePath: String?
    var iconName: String?
    var letterLogo: String?
    var relevantDate: Date?
    var expiryDate: Date?
    var walletPassSerialNumber: String?
    var walletPassTypeIdentifier: String?
    var walletPassStoragePath: String?
    var walletAddedAt: Date?
    var lastWalletUpdateAt: Date?
    var isFavorite: Bool
    var isArchived: Bool
    var requiresBiometricUnlock: Bool
    var isCloudSyncEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        type: CardType = .generic,
        source: CardSource = .manual,
        status: CardStatus = .localOnly,
        barcode: BarcodePayload? = nil,
        design: CardDesign = .default,
        fields: [CardField] = [],
        reminders: [CardReminder] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.typeRawValue = type.rawValue
        self.sourceRawValue = source.rawValue
        self.statusRawValue = status.rawValue
        self.barcodeData = try? JSONEncoder.passly.encode(barcode)
        self.designData = try? JSONEncoder.passly.encode(design)
        self.fieldsData = try? JSONEncoder.passly.encode(fields)
        self.remindersData = try? JSONEncoder.passly.encode(reminders)
        self.iconName = type.defaultSymbol
        self.letterLogo = String(title.prefix(1)).uppercased()
        self.isFavorite = false
        self.isArchived = false
        self.requiresBiometricUnlock = false
        self.isCloudSyncEnabled = true
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension WalletCard {
    var type: CardType {
        get { CardType(rawValue: typeRawValue) ?? .generic }
        set { typeRawValue = newValue.rawValue }
    }

    var source: CardSource {
        get { CardSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    var status: CardStatus {
        get { CardStatus(rawValue: statusRawValue) ?? .localOnly }
        set { statusRawValue = newValue.rawValue }
    }

    var barcode: BarcodePayload? {
        get { decode(BarcodePayload.self, from: barcodeData) }
        set { barcodeData = try? JSONEncoder.passly.encode(newValue) }
    }

    var design: CardDesign {
        get { decode(CardDesign.self, from: designData) ?? .default }
        set { designData = try? JSONEncoder.passly.encode(newValue) }
    }

    var fields: [CardField] {
        get { decode([CardField].self, from: fieldsData) ?? [] }
        set { fieldsData = try? JSONEncoder.passly.encode(newValue) }
    }

    var reminders: [CardReminder] {
        get { decode([CardReminder].self, from: remindersData) ?? [] }
        set { remindersData = try? JSONEncoder.passly.encode(newValue) }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder.passly.decode(T.self, from: data)
    }
}

enum CardType: String, Codable, CaseIterable, Identifiable {
    case loyalty, store, membership, coupon, giftCard, eventTicket, movieTicket, sportsTicket, concertTicket
    case travelReservation, boardingReference, trainBusReservation, hotelReservation, restaurantReservation
    case parking, warranty, receipt, student, library, gym, club, medicalAppointment, insuranceReference
    case business, visitor, generic

    var id: String { rawValue }

    var displayName: String {
        rawValue
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    var defaultSymbol: String {
        switch self {
        case .coupon: "tag"
        case .eventTicket, .movieTicket, .sportsTicket, .concertTicket: "ticket"
        case .travelReservation, .boardingReference, .trainBusReservation: "airplane"
        case .hotelReservation: "bed.double"
        case .restaurantReservation: "fork.knife"
        case .parking: "parkingsign"
        case .business: "person.crop.rectangle"
        case .medicalAppointment, .insuranceReference: "cross.case"
        default: "wallet.pass"
        }
    }
}

enum CardSource: String, Codable, CaseIterable {
    case cameraScan, photoImport, pdfImport, manual, pastedCode, linkImport, template, shareExtension
    case nfcTag, pkpassImport, clipboard, duplicate
}

enum CardStatus: String, Codable {
    case localOnly, synced, generatingPass, walletReady, walletAdded, generationFailed
}

enum BarcodeFormat: String, Codable, CaseIterable, Identifiable {
    case qr, code128, pdf417, aztec, ean13, ean8, upca, upce, code39, codabar, itf, dataMatrix, unsupported
    var id: String { rawValue }

    var walletCompatibleFormat: BarcodeFormat {
        switch self {
        case .qr, .code128, .pdf417, .aztec: self
        default: .qr
        }
    }
}

struct BarcodePayload: Codable, Hashable {
    var value: String
    var format: BarcodeFormat
    var originalFormat: BarcodeFormat?
    var walletExportFormat: BarcodeFormat?
    var altText: String?

    var effectiveWalletFormat: BarcodeFormat {
        walletExportFormat ?? format.walletCompatibleFormat
    }
}

struct NFCPayload: Codable, Hashable {
    var rawText: String?
    var urlString: String?
    var recordType: String?
    var scannedAt: Date
}

struct CardDesign: Codable, Hashable {
    var templateId: String
    var backgroundColorHex: String
    var foregroundColorHex: String
    var labelColorHex: String
    var accentColorHex: String?
    var gradient: GradientSpec?
    var materialStyle: MaterialStyle
    var visualDensity: VisualDensity

    static let `default` = CardDesign(
        templateId: "midnight-glass",
        backgroundColorHex: "#111318",
        foregroundColorHex: "#FFFFFF",
        labelColorHex: "#B8BBC4",
        accentColorHex: "#73A7FF",
        gradient: GradientSpec(colors: ["#111318", "#273140"], startPoint: "topLeading", endPoint: "bottomTrailing"),
        materialStyle: .glass,
        visualDensity: .balanced
    )
}

struct GradientSpec: Codable, Hashable {
    var colors: [String]
    var startPoint: String
    var endPoint: String
}

enum MaterialStyle: String, Codable, CaseIterable { case solid, glass, satin, paper }
enum VisualDensity: String, Codable, CaseIterable { case minimal, balanced, detailed }

struct CardField: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var key: String
    var label: String
    var value: String
    var placement: FieldPlacement
    var isHiddenInWallet: Bool = false
    var isSensitive: Bool = false
}

enum FieldPlacement: String, Codable, CaseIterable, Identifiable {
    case header, primary, secondary, auxiliary, back, appOnlySensitive
    var id: String { rawValue }
}

struct CardReminder: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var kind: ReminderKind
}

enum ReminderKind: String, Codable, CaseIterable { case expiry, event, reservation, warranty, membership, parking, custom }

struct GeneratedPass: Codable, Hashable {
    var passId: String
    var serialNumber: String
    var passTypeIdentifier: String
    var storagePath: String
    var downloadURL: URL?
    var passData: Data?
}

struct RemoteFeatureFlags: Codable, Hashable {
    var walletExportEnabled = true
    var nfcImportEnabled = true
    var pdfImportEnabled = true
    var shareExtensionEnabled = true
    var cloudSyncEnabled = true
    var passAutoUpdateEnabled = false
    var lifetimePurchaseEnabled = false
    var aiImportSuggestionsEnabled = false
    var betaTemplatesEnabled = false
}

enum EntitlementState: String, Codable, Hashable {
    case locked
    case monthlyActive
    case lifetimeUnlocked

    var isUnlocked: Bool {
        self == .monthlyActive || self == .lifetimeUnlocked
    }

    var displayName: String {
        switch self {
        case .locked: "Locked"
        case .monthlyActive: "Monthly Pro"
        case .lifetimeUnlocked: "Lifetime Pro"
        }
    }
}

enum PasslyProduct: String, Codable, Hashable, CaseIterable, Identifiable {
    case monthly = "passly.monthly.pro"
    case lifetime = "passly.lifetime.pro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .lifetime: "Lifetime"
        }
    }

    var displayPrice: String {
        switch self {
        case .monthly: "$6.99"
        case .lifetime: "$29.99"
        }
    }

    var detail: String {
        switch self {
        case .monthly: "Renews monthly. Cancel anytime."
        case .lifetime: "One payment. Launch price."
        }
    }

    var badge: String? {
        switch self {
        case .monthly: nil
        case .lifetime: "Best value"
        }
    }
}

struct ImportAnalysisResult: Codable, Hashable {
    var suggestedTitle: String
    var suggestedType: CardType
    var barcode: BarcodePayload?
    var fields: [CardField]
    var design: CardDesign
}

extension JSONEncoder {
    static var passly: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var passly: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
