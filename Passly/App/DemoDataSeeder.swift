import Foundation
import SwiftData

#if DEBUG
@MainActor
enum DemoDataSeeder {
    private static let seedVersion = 1

    static func seedIfRequested(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "passly.demoSeedEnabled") as? Bool == true else { return }
        guard defaults.integer(forKey: "passly.demoSeedVersion") != seedVersion else { return }

        let descriptor = FetchDescriptor<WalletCard>()
        if let existingCards = try? context.fetch(descriptor) {
            existingCards.forEach(context.delete)
        }

        sampleCards.forEach(context.insert)
        try? context.save()
        defaults.set(seedVersion, forKey: "passly.demoSeedVersion")
    }

    private static var sampleCards: [WalletCard] {
        let calendar = Calendar.current

        let coffee = WalletCard(
            title: "Blue Bottle",
            subtitle: "Gold Member",
            type: .loyalty,
            source: .cameraScan,
            status: .walletAdded,
            barcode: .init(value: "BB-GOLD-8421", format: .qr, altText: "BB-GOLD-8421"),
            design: .init(
                templateId: "mint-glass",
                backgroundColorHex: "#12342C",
                foregroundColorHex: "#FFFFFF",
                labelColorHex: "#BAE6D4",
                accentColorHex: "#63E6BE",
                gradient: .init(colors: ["#102C28", "#1F755F"], startPoint: "topLeading", endPoint: "bottomTrailing"),
                materialStyle: .glass,
                visualDensity: .balanced
            ),
            fields: [
                .init(key: "tier", label: "Tier", value: "Gold", placement: .secondary),
                .init(key: "points", label: "Points", value: "1,240", placement: .auxiliary)
            ],
            reminders: [
                .init(title: "Reward expires", date: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now, kind: .expiry)
            ]
        )
        coffee.isFavorite = true
        coffee.walletAddedAt = calendar.date(byAdding: .day, value: -3, to: .now)

        let flight = WalletCard(
            title: "Istanbul to London",
            subtitle: "TK 1983 · Seat 8A",
            type: .boardingReference,
            source: .pdfImport,
            status: .walletReady,
            barcode: .init(value: "TK1983-8A-ESRA", format: .pdf417, altText: "TK1983 8A"),
            design: .init(
                templateId: "sky-ticket",
                backgroundColorHex: "#123B72",
                foregroundColorHex: "#FFFFFF",
                labelColorHex: "#B7D7FF",
                accentColorHex: "#77C8FF",
                gradient: .init(colors: ["#0F2D5C", "#2278B8"], startPoint: "topLeading", endPoint: "bottomTrailing"),
                materialStyle: .satin,
                visualDensity: .detailed
            ),
            fields: [
                .init(key: "gate", label: "Gate", value: "B12", placement: .header),
                .init(key: "boarding", label: "Boarding", value: "18:40", placement: .primary)
            ],
            reminders: [
                .init(title: "Boarding starts", date: calendar.date(byAdding: .day, value: 2, to: .now) ?? .now, kind: .event)
            ]
        )

        let cinema = WalletCard(
            title: "Cinema Night",
            subtitle: "Dune · Row C Seat 12",
            type: .movieTicket,
            source: .photoImport,
            status: .walletReady,
            barcode: .init(value: "CINEMA-DUNE-C12", format: .aztec, altText: "Row C Seat 12"),
            design: .init(
                templateId: "violet-ticket",
                backgroundColorHex: "#2B123D",
                foregroundColorHex: "#FFFFFF",
                labelColorHex: "#D7C6F5",
                accentColorHex: "#FFB86B",
                gradient: .init(colors: ["#2B123D", "#7A2E86"], startPoint: "topLeading", endPoint: "bottomTrailing"),
                materialStyle: .glass,
                visualDensity: .balanced
            ),
            fields: [
                .init(key: "screen", label: "Screen", value: "4", placement: .secondary),
                .init(key: "time", label: "Time", value: "21:15", placement: .primary)
            ]
        )

        let parking = WalletCard(
            title: "Zorlu Parking",
            subtitle: "Level P2 · B-184",
            type: .parking,
            source: .nfcTag,
            status: .localOnly,
            barcode: .init(value: "PARK-ZORLU-P2-B184", format: .code128, altText: "P2 B-184"),
            design: .init(
                templateId: "amber-utility",
                backgroundColorHex: "#3B2A12",
                foregroundColorHex: "#FFFFFF",
                labelColorHex: "#F2D7A2",
                accentColorHex: "#FFBD59",
                gradient: .init(colors: ["#3B2A12", "#9B631F"], startPoint: "topLeading", endPoint: "bottomTrailing"),
                materialStyle: .satin,
                visualDensity: .minimal
            ),
            fields: [
                .init(key: "plate", label: "Plate", value: "34 PLY 034", placement: .secondary)
            ],
            reminders: [
                .init(title: "Parking expires", date: calendar.date(byAdding: .hour, value: 4, to: .now) ?? .now, kind: .parking)
            ]
        )
        parking.expiryDate = calendar.date(byAdding: .hour, value: 4, to: .now)

        let insurance = WalletCard(
            title: "Axa Insurance",
            subtitle: "Health policy",
            type: .insuranceReference,
            source: .manual,
            status: .synced,
            barcode: .init(value: "AXA-POLICY-77-4920", format: .qr, altText: "Policy 77-4920"),
            design: .init(
                templateId: "medical-clear",
                backgroundColorHex: "#103045",
                foregroundColorHex: "#FFFFFF",
                labelColorHex: "#B9DAE8",
                accentColorHex: "#7BE0FF",
                gradient: .init(colors: ["#103045", "#176068"], startPoint: "topLeading", endPoint: "bottomTrailing"),
                materialStyle: .glass,
                visualDensity: .detailed
            ),
            fields: [
                .init(key: "policy", label: "Policy", value: "77-4920", placement: .primary),
                .init(key: "member", label: "Member ID", value: "M-394822", placement: .appOnlySensitive, isSensitive: true)
            ]
        )
        insurance.requiresBiometricUnlock = true

        let gift = WalletCard(
            title: "Gift Balance",
            subtitle: "$42.80 remaining",
            type: .giftCard,
            source: .pastedCode,
            status: .generatingPass,
            barcode: .init(value: "GIFT-4280-2026", format: .qr, altText: "GIFT-4280"),
            design: .init(
                templateId: "rose-gift",
                backgroundColorHex: "#4A1328",
                foregroundColorHex: "#FFFFFF",
                labelColorHex: "#FFD2DD",
                accentColorHex: "#FF7B9D",
                gradient: .init(colors: ["#4A1328", "#B93C5F"], startPoint: "topLeading", endPoint: "bottomTrailing"),
                materialStyle: .glass,
                visualDensity: .balanced
            ),
            fields: [
                .init(key: "balance", label: "Balance", value: "$42.80", placement: .primary)
            ]
        )

        return [coffee, flight, cinema, parking, insurance, gift]
    }
}
#endif
