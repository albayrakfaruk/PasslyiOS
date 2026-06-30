import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

enum RevenueCatConfig {
    static let publicSDKKey = "REVENUECAT_PUBLIC_SDK_KEY"
    static let entitlementID = "pro"
    static let offeringID = "default"
}

@MainActor
final class RevenueCatEntitlementService: EntitlementService {
    @Published private(set) var state: EntitlementState
    private var hasConfiguredRevenueCat = false

    var isProUnlocked: Bool {
        state.isUnlocked
    }

    init() {
        let rawValue = UserDefaults.standard.string(forKey: "passly.entitlementState")
        self.state = rawValue.flatMap(EntitlementState.init(rawValue:)) ?? .locked
        configureIfPossible()
    }

    func refreshEntitlements() async {
        #if DEBUG
        if UserDefaults.standard.object(forKey: "passly.demoEntitlementUnlocked") as? Bool == true {
            updateState(.lifetimeUnlocked)
            return
        }
        #endif

        configureIfPossible()
        #if canImport(RevenueCat)
        guard hasConfiguredRevenueCat else {
            updateState(.locked)
            return
        }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateState(from: customerInfo)
        } catch {
            if !state.isUnlocked {
                updateState(.locked)
            }
        }
        #else
        updateState(.locked)
        #endif
    }

    func purchase(_ product: PasslyProduct) async throws {
        configureIfPossible()
        #if canImport(RevenueCat)
        guard hasConfiguredRevenueCat else {
            throw RevenueCatEntitlementError.missingSDKKey
        }
        let offerings = try await Purchases.shared.offerings()
        let offering = offerings.offering(identifier: RevenueCatConfig.offeringID) ?? offerings.current
        guard let package = offering?.availablePackages.first(where: { $0.storeProduct.productIdentifier == product.rawValue }) else {
            throw RevenueCatEntitlementError.productUnavailable
        }
        let result = try await Purchases.shared.purchase(package: package)
        updateState(from: result.customerInfo)
        #else
        throw RevenueCatEntitlementError.sdkUnavailable
        #endif
    }

    func restorePurchases() async {
        configureIfPossible()
        #if canImport(RevenueCat)
        guard hasConfiguredRevenueCat else {
            updateState(.locked)
            return
        }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateState(from: customerInfo)
        } catch {
            if !state.isUnlocked {
                updateState(.locked)
            }
        }
        #endif
    }

    private func configureIfPossible() {
        #if canImport(RevenueCat)
        guard !hasConfiguredRevenueCat else { return }
        guard RevenueCatConfig.publicSDKKey != "REVENUECAT_PUBLIC_SDK_KEY" else { return }
        Purchases.configure(withAPIKey: RevenueCatConfig.publicSDKKey)
        hasConfiguredRevenueCat = true
        #endif
    }

    #if canImport(RevenueCat)
    private func updateState(from customerInfo: CustomerInfo) {
        guard customerInfo.entitlements[RevenueCatConfig.entitlementID]?.isActive == true else {
            updateState(.locked)
            return
        }
        if customerInfo.nonSubscriptions.contains(where: { $0.productIdentifier == PasslyProduct.lifetime.rawValue }) {
            updateState(.lifetimeUnlocked)
        } else {
            updateState(.monthlyActive)
        }
    }
    #endif

    private func updateState(_ newState: EntitlementState) {
        state = newState
        UserDefaults.standard.set(newState.rawValue, forKey: "passly.entitlementState")
    }
}

enum RevenueCatEntitlementError: LocalizedError {
    case missingSDKKey
    case productUnavailable
    case sdkUnavailable

    var errorDescription: String? {
        switch self {
        case .missingSDKKey:
            "RevenueCat is not configured yet. Add the public SDK key before testing purchases."
        case .productUnavailable:
            "This purchase option is not available yet. Check the RevenueCat offering and product identifiers."
        case .sdkUnavailable:
            "RevenueCat SDK is unavailable in this build."
        }
    }
}
