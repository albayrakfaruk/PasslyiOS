import CoreImage.CIFilterBuiltins
import SwiftUI

struct PremiumPassCardView: View {
    let card: WalletCard
    var isBack = false
    var tilt: CGSize = .zero
    var width: CGFloat = 330
    var height: CGFloat = 208

    var body: some View {
        let design = card.design
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                logo
                Spacer()
                Image(systemName: card.type.defaultSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PasslyTheme.color(hex: design.foregroundColorHex).opacity(0.9))
            }

            Spacer(minLength: 8)

            if isBack {
                backContent
            } else {
                frontContent
            }
        }
        .padding(22)
        .frame(width: width, height: height)
        .background(background(for: design))
        .overlay(alignment: .topLeading) {
            LinearGradient(
                colors: [.white.opacity(0.32), .white.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 86)
            .blendMode(.screen)
        }
        .overlay(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.10))
                .frame(width: 108, height: 46)
                .overlay {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(index.isMultiple(of: 2) ? 0.65 : 0.32))
                                .frame(width: index.isMultiple(of: 2) ? 5 : 3, height: 26)
                        }
                    }
                }
                .padding(18)
                .opacity(isBack ? 0 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
        .rotation3DEffect(.degrees(Double(tilt.width / 18)), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(Double(-tilt.height / 22)), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.title)
    }

    private var logo: some View {
        ZStack {
            Circle().fill(.white.opacity(0.16))
            Text(card.letterLogo ?? String(card.title.prefix(1)).uppercased())
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 50, height: 50)
    }

    private var frontContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.type.displayName.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            Text(card.title)
                .font(.title2.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .foregroundStyle(.white)
            if let subtitle = card.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }
            if let barcode = card.barcode {
                HStack(spacing: 8) {
                    Image(systemName: barcode.format == .qr ? "qrcode" : "barcode")
                    Text(barcode.altText ?? barcode.value)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 4)
            }
        }
    }

    private var backContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(card.fields.prefix(4)) { field in
                HStack {
                    Text(field.label)
                        .foregroundStyle(.white.opacity(0.58))
                    Spacer()
                    Text(field.isSensitive ? "Locked" : field.value)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .font(.caption)
            }
            if card.fields.isEmpty {
                Text("Add notes, dates, and private fields in the editor.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    @ViewBuilder
    private func background(for design: CardDesign) -> some View {
        if let gradient = design.gradient, gradient.colors.count > 1 {
            LinearGradient(
                colors: gradient.colors.map(PasslyTheme.color(hex:)),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            PasslyTheme.color(hex: design.backgroundColorHex)
        }
    }
}

struct CodeImageView: View {
    let payload: BarcodePayload

    var body: some View {
        Group {
            if let image = makeImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ContentUnavailableView("No Code", systemImage: "qrcode", description: Text("Add a barcode or QR value to show it here."))
            }
        }
    }

    private func makeImage() -> UIImage? {
        let context = CIContext()
        let data = Data(payload.value.utf8)
        let output: CIImage?

        switch payload.effectiveWalletFormat {
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = data
            output = filter.outputImage
        default:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = data
            filter.correctionLevel = "M"
            output = filter.outputImage
        }

        guard let image = output?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
