import Foundation
import PassKit
import SwiftData
import UIKit

@MainActor
protocol CardRepository {
    func fetchCards() async throws -> [WalletCard]
    func save(_ card: WalletCard) async throws
    func delete(_ card: WalletCard) async throws
    func archive(_ card: WalletCard) async throws
    func search(query: String) async throws -> [WalletCard]
}

@MainActor
protocol AuthService {
    var userID: String? { get }
    func signInAnonymouslyIfNeeded() async throws
}

@MainActor
protocol PassGenerationService {
    func generatePass(for card: WalletCard) async throws -> GeneratedPass
    func updatePass(for card: WalletCard) async throws -> GeneratedPass
}

protocol WalletService {
    func canAddPass(_ passData: Data) -> Bool
    func containsPass(serialNumber: String, passTypeIdentifier: String) -> Bool
}

@MainActor
protocol NFCReadingService {
    func readNDEF() async throws -> NFCPayload
}

@MainActor
protocol ImportAnalysisService {
    func analyzeImage(_ image: UIImage) async throws -> ImportAnalysisResult
    func analyzePDF(_ url: URL) async throws -> ImportAnalysisResult
    func analyzeURL(_ url: URL) async throws -> ImportAnalysisResult
    func analyzeText(_ text: String) async throws -> ImportAnalysisResult
}

@MainActor
protocol RemoteConfigService {
    var flags: RemoteFeatureFlags { get }
    func refresh() async
}

@MainActor
protocol EntitlementService: ObservableObject {
    var state: EntitlementState { get }
    var isProUnlocked: Bool { get }
    func refreshEntitlements() async
    func purchase(_ product: PasslyProduct) async throws
    func restorePurchases() async
}

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
}

enum AnalyticsEvent: String {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case addCardStarted = "add_card_started"
    case cardCreated = "card_created"
    case walletGenerationStarted = "wallet_generation_started"
    case walletGenerationSuccess = "wallet_generation_success"
    case walletGenerationFailed = "wallet_generation_failed"
    case nfcReadSuccess = "nfc_read_success"
}
