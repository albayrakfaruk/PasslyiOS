import SwiftData
import SwiftUI

@main
struct PasslyApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var container: DependencyContainer

    init() {
        let schema = Schema([WalletCard.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }
            let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = modelContainer
            _container = StateObject(wrappedValue: DependencyContainer(modelContainer: modelContainer))
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .modelContainer(modelContainer)
                .task {
                    await container.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var container: DependencyContainer
    @AppStorage("passly.appearance") private var appearance = "system"
    @State private var needsOnboarding: Bool
    @State private var showPaywall = false

    init() {
        let onboardingComplete = UserDefaults.standard.object(forKey: "passly.onboardingComplete") as? Bool ?? false
        _needsOnboarding = State(initialValue: !onboardingComplete)
    }

    var body: some View {
        Group {
            if needsOnboarding {
                onboarding
            } else {
                NavigationStack { HomeView() }
            }
        }
        .tint(PasslyTheme.accent)
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(container)
        }
        .task {
            #if DEBUG
            if UserDefaults.standard.object(forKey: "passly.debugShowPaywallOnLaunch") as? Bool == true {
                UserDefaults.standard.set(false, forKey: "passly.debugShowPaywallOnLaunch")
                showPaywall = true
            }
            #endif
        }
    }

    private var onboarding: some View {
        OnboardingView { shouldShowPaywall in
            UserDefaults.standard.set(true, forKey: "passly.onboardingComplete")
            needsOnboarding = false
            showPaywall = shouldShowPaywall
        }
        .environmentObject(container)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }
}
