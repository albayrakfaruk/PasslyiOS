import Foundation
import SwiftData

@MainActor
final class DependencyContainer: ObservableObject {
    let modelContainer: ModelContainer
    let authService: AuthService
    let remoteConfig: RemoteConfigService
    let analytics: AnalyticsService
    let passGenerationService: PassGenerationService
    let walletService: WalletService
    let nfcService: NFCReadingService
    let importAnalyzer: ImportAnalysisService
    let notificationService: NotificationScheduler
    let entitlementService: RevenueCatEntitlementService

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.authService = LocalAnonymousAuthService()
        self.remoteConfig = LocalRemoteConfigService()
        self.analytics = PrivacySafeAnalyticsService()
        self.passGenerationService = MockPassGenerationService()
        self.walletService = PassKitWalletService()
        self.nfcService = CoreNFCReadingService()
        self.importAnalyzer = LocalImportAnalysisService()
        self.notificationService = NotificationScheduler()
        self.entitlementService = RevenueCatEntitlementService()
    }

    var cardRepository: CardRepository {
        SwiftDataCardRepository(context: modelContainer.mainContext)
    }

    func bootstrap() async {
        try? await authService.signInAnonymouslyIfNeeded()
        await remoteConfig.refresh()
        await entitlementService.refreshEntitlements()
        #if DEBUG
        DemoDataSeeder.seedIfRequested(in: modelContainer.mainContext)
        #endif
    }
}
