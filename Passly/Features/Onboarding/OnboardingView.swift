import SwiftUI

struct OnboardingPageModel: Identifiable {
    let id: String
    let headlineKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let visual: OnboardingVisualType
    let safetyNoteKey: LocalizedStringKey?
}

enum OnboardingVisualType {
    case walletStudio, addFromAnywhere, smartScan, designStudio, nfcSafe, privacySync, premiumUnlock
}

struct OnboardingView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var restoreMessage: String?
    let finish: (_ shouldShowPaywall: Bool) -> Void

    private let pages: [OnboardingPageModel] = [
        .init(id: "wallet", headlineKey: "Create beautiful Apple Wallet passes", subtitleKey: "Turn cards, tickets, coupons, memberships, and codes into premium digital passes.", visual: .walletStudio, safetyNoteKey: nil),
        .init(id: "anywhere", headlineKey: "Add from anywhere", subtitleKey: "Scan with camera, import photos, PDFs, links, clipboard text, or share files directly into Passly.", visual: .addFromAnywhere, safetyNoteKey: nil),
        .init(id: "scan", headlineKey: "Scan once. We build the pass.", subtitleKey: "Passly detects QR codes, barcodes, titles, dates, colors, and useful fields automatically.", visual: .smartScan, safetyNoteKey: nil),
        .init(id: "design", headlineKey: "Make every card look premium", subtitleKey: "Customize logos, colors, gradients, fields, icons, and layouts with a live Wallet preview.", visual: .designStudio, safetyNoteKey: nil),
        .init(id: "nfc", headlineKey: "Readable NFC tags, safely imported", subtitleKey: "Scan public NFC tag text or URLs and turn them into passes. Secure cards cannot be copied.", visual: .nfcSafe, safetyNoteKey: "Passly cannot copy payment cards, access cards, hotel keys, car keys, or transit cards."),
        .init(id: "private", headlineKey: "Private and organized", subtitleKey: "Lock sensitive fields with Face ID, organize cards, and set helpful expiry reminders.", visual: .privacySync, safetyNoteKey: nil),
        .init(id: "premium", headlineKey: "Unlock Passly", subtitleKey: "Choose Monthly or Lifetime Pro to create Wallet passes from cards, tickets, PDFs, photos, NFC tags, and links.", visual: .premiumUnlock, safetyNoteKey: nil)
    ]

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(spacing: 22) {
                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { pageIndex, page in
                        VStack(spacing: 26) {
                            OnboardingVisual(type: page.visual, reduceMotion: reduceMotion)
                                .frame(height: 340)
                                .padding(.top, 28)

                            VStack(spacing: 12) {
                                Text(page.headlineKey)
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(PasslyTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.78)
                                Text(page.subtitleKey)
                                    .font(.body)
                                    .foregroundStyle(PasslyTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                if let note = page.safetyNoteKey {
                                    Label(note, systemImage: "shield")
                                        .font(.caption)
                                        .foregroundStyle(PasslyTheme.textSecondary)
                                        .padding(10)
                                        .glassPanel()
                                }
                                if page.visual == .premiumUnlock {
                                    premiumBullets
                                }
                            }
                            .padding(.horizontal, 24)
                            Spacer()
                        }
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { page in
                        Capsule()
                            .fill(page == index ? PasslyTheme.vividAccent : PasslyTheme.quietFill)
                            .frame(width: page == index ? 26 : 8, height: 8)
                    }
                }

                HStack {
                    if index == pages.indices.last {
                        Button("Restore Purchase") {
                            Task { await restorePurchase() }
                        }
                            .foregroundStyle(PasslyTheme.textSecondary)
                    } else if index > 1 {
                        Button("Skip") { finish(false) }
                            .foregroundStyle(PasslyTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        if index == pages.indices.last {
                            container.analytics.track(.onboardingCompleted)
                            finish(true)
                        } else {
                            withAnimation(.snappy) { index += 1 }
                        }
                    } label: {
                        Text(index == pages.indices.last ? "Unlock Passly" : "Continue")
                            .font(.headline)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 14)
                            .background(PasslyTheme.vividAccent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .sensoryFeedback(.selection, trigger: index)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .onAppear { container.analytics.track(.onboardingStarted) }
        .alert("Passly", isPresented: Binding(get: { restoreMessage != nil }, set: { _ in restoreMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    private var premiumBullets: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(["Lifetime launch price available", "Monthly option for flexibility", "Apple Wallet pass generation", "Photo, PDF, and NFC import"], id: \.self) { bullet in
                Label(bullet, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
            }
        }
        .foregroundStyle(PasslyTheme.textPrimary)
        .padding(14)
        .glassPanel()
    }

    private func restorePurchase() async {
        await container.entitlementService.restorePurchases()
        if container.entitlementService.isProUnlocked {
            finish(false)
        } else {
            restoreMessage = "No active Passly purchase was found for this Apple ID."
        }
    }
}

struct OnboardingVisual: View {
    let type: OnboardingVisualType
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.white.opacity(0.055))
                    .frame(width: 338, height: 306)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [.white.opacity(0.20), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }
                switch type {
                case .walletStudio:
                    cardFan(t)
                case .addFromAnywhere:
                    orbitingIcons(t)
                case .smartScan:
                    scannerScene(t)
                case .designStudio:
                    designScene(t)
                case .nfcSafe:
                    nfcScene(t)
                case .privacySync:
                    privacyScene(t)
                case .premiumUnlock:
                    premiumScene(t)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cardFan(_ t: TimeInterval) -> some View {
        ZStack {
            visualCard("Coupon", systemImage: "tag", color: .orange, offset: CGSize(width: -70, height: 40), rotation: -12 + sin(t) * 2, labelOpacity: 0.82)
            visualCard("Event", systemImage: "ticket", color: .purple, offset: CGSize(width: 64, height: 16), rotation: 10 + cos(t) * 2, labelOpacity: 0)
            visualCard("Coffee", systemImage: "qrcode", color: PasslyTheme.accent, offset: CGSize(width: 0, height: -24), rotation: sin(t * 0.7) * 4)
            walletBadge
                .offset(y: 132)
        }
    }

    private func orbitingIcons(_ t: TimeInterval) -> some View {
        ZStack {
            visualCard("New Pass", systemImage: "wallet.pass", color: .cyan, offset: .zero, rotation: 0)
            ForEach(Array(["camera", "photo", "doc.richtext", "link", "doc.on.clipboard", "square.and.arrow.up"].enumerated()), id: \.offset) { item in
                let angle = t + Double(item.offset) * .pi / 3
                Image(systemName: item.element)
                    .font(.title2)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18)))
                    .foregroundStyle(.white)
                    .offset(x: cos(angle) * 126, y: sin(angle) * 96)
            }
        }
    }

    private func scannerScene(_ t: TimeInterval) -> some View {
        ZStack {
            visualCard("Boarding", systemImage: "qrcode.viewfinder", color: .green, offset: .zero, rotation: 0)
            RoundedRectangle(cornerRadius: 24)
                .stroke(PasslyTheme.accent, style: StrokeStyle(lineWidth: 3, dash: [12, 10]))
                .frame(width: 250, height: 174)
            Rectangle()
                .fill(PasslyTheme.accent.opacity(0.75))
                .frame(width: 236, height: 2)
                .offset(y: -78 + (sin(t * 2) + 1) * 78)
            detectionChip("logo", x: -88, y: -72, delay: 0)
            detectionChip("date", x: 88, y: -42, delay: 0.4)
            detectionChip("code", x: 78, y: 70, delay: 0.8)
        }
    }

    private func designScene(_ t: TimeInterval) -> some View {
        ZStack {
            visualCard("Design", systemImage: "paintpalette", color: Color(hue: (sin(t) + 1) / 2, saturation: 0.6, brightness: 0.85), offset: .zero, rotation: sin(t) * 3)
            HStack(spacing: 10) {
                ForEach([Color.blue, .green, .orange, .pink], id: \.description) { color in
                    Circle().fill(color).frame(width: 28, height: 28)
                }
            }
            .offset(y: 128)
        }
    }

    private func nfcScene(_ t: TimeInterval) -> some View {
        ZStack {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 120))
                .foregroundStyle(.white)
                .offset(x: -52)
            Image(systemName: "wave.3.right")
                .font(.system(size: 60))
                .foregroundStyle(PasslyTheme.accent.opacity(0.55 + 0.25 * sin(t * 3)))
                .offset(x: 40)
            Image(systemName: "shield.checkered")
                .font(.system(size: 58))
                .foregroundStyle(.green)
                .offset(x: 112, y: 64)
            visualChip("NDEF", systemImage: "checkmark.seal.fill")
                .offset(x: 74, y: -96)
        }
    }

    private func privacyScene(_ t: TimeInterval) -> some View {
        ZStack {
            visualCard("Private", systemImage: "lock", color: .indigo, offset: .zero, rotation: 0)
            Image(systemName: sin(t * 2) > 0 ? "faceid" : "lock.open")
                .font(.system(size: 64))
                .foregroundStyle(.white)
                .offset(y: 118)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.16))
                .frame(width: 164, height: 18)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.42))
                        .frame(width: 76, height: 18)
                        .blur(radius: sin(t * 2) > 0 ? 3 : 0)
                }
                .offset(y: 22)
        }
    }

    private func premiumScene(_ t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<5) { idx in
                visualCard("Premium", systemImage: "sparkles", color: Color(hue: Double(idx) / 5, saturation: 0.55, brightness: 0.8), offset: CGSize(width: CGFloat(idx - 2) * 34, height: CGFloat(abs(idx - 2)) * 18), rotation: Double(idx - 2) * 8 + sin(t) * 2)
            }
            walletBadge
                .offset(y: 140)
        }
    }

    private func visualCard(_ title: String, systemImage: String, color: Color, offset: CGSize, rotation: Double, labelOpacity: Double = 0.92) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.9), .black.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 228, height: 144)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: systemImage).font(.title)
                    Spacer()
                    Text(title).font(.title3.weight(.bold))
                }
                .foregroundStyle(.white)
                .opacity(labelOpacity)
                .padding(18)
            }
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.18)))
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(color: .black.opacity(0.25), radius: 18, y: 14)
    }

    private var walletBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "wallet.pass.fill")
            Text("Wallet")
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white)
        .foregroundStyle(.black)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
    }

    private func detectionChip(_ text: String, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(PasslyTheme.mint)
            .clipShape(Capsule())
            .offset(x: x, y: y)
    }

    private func visualChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18)))
            .foregroundStyle(.white)
    }
}
