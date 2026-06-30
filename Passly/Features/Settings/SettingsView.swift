import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @AppStorage("passly.appLockEnabled") private var appLockEnabled = false
    @AppStorage("passly.cloudSyncEnabled") private var cloudSyncEnabled = true
    @AppStorage("passly.appearance") private var appearance = "system"
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            PremiumBackground()
            Form {
                Section("Subscription") {
                    Button(container.entitlementService.state.isUnlocked ? "Manage Passly Pro" : "Unlock Passly") { showPaywall = true }
                    Text(container.entitlementService.state.isUnlocked ? container.entitlementService.state.displayName : "Monthly or Lifetime Pro is required to create and export passes.")
                        .font(.caption)
                }

                Section("Cloud & Security") {
                    Toggle("Cloud Sync", isOn: premiumBinding($cloudSyncEnabled))
                    Toggle("Require Face ID at launch", isOn: premiumBinding($appLockEnabled))
                    NavigationLink("NFC Safety FAQ") { NFCSafetyFAQView() }
                }

                Section("Preferences") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    Text("Localization is configured with String Catalogs and RTL-safe leading/trailing layouts.")
                        .font(.caption)
                }

                Section("About") {
                    Text("Passly creates user-generated Apple Wallet passes. It does not copy payment cards, access cards, hotel keys, car keys, transit cards, government IDs, or secure NFC credentials.")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func premiumBinding(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                guard container.entitlementService.isProUnlocked else {
                    showPaywall = true
                    return
                }
                binding.wrappedValue = newValue
            }
        )
    }
}

struct NFCSafetyFAQView: View {
    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(alignment: .leading, spacing: 18) {
                Label("Readable NFC tags only", systemImage: "wave.3.right")
                    .font(.title2.weight(.bold))
                Text("Passly can read public NDEF text and URL tags. It cannot copy payment cards, access cards, hotel keys, car keys, transit cards, or other secure NFC credentials.")
                Text("If a secure NFC item cannot be read, create a manual reference pass instead.")
                    .foregroundStyle(PasslyTheme.textSecondary)
                Spacer()
            }
            .foregroundStyle(PasslyTheme.textPrimary)
            .padding()
        }
        .navigationTitle("NFC Safety")
    }
}
