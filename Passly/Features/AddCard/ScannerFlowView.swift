import AVFoundation
import SwiftData
import SwiftUI

struct ScannerFlowView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var manualValue = ""
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                CameraScannerView { value, format in
                    createCard(value: value, format: format)
                } permissionDenied: {
                    permissionDenied = true
                }
                .ignoresSafeArea()

                VStack {
                    ScannerOverlay()
                    Spacer()
                    VStack(spacing: 10) {
                        TextField("Manual code fallback", text: $manualValue)
                            .textFieldStyle(.roundedBorder)
                        Button("Create from Manual Code") {
                            createCard(value: manualValue, format: .qr)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(manualValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Scan Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Camera unavailable", isPresented: $permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow camera access or use the manual fallback.")
            }
        }
    }

    private func createCard(value: String, format: BarcodeFormat) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let barcode = BarcodePayload(value: clean, format: format, originalFormat: format, walletExportFormat: format.walletCompatibleFormat, altText: clean)
        let card = WalletCard(title: "Scanned Pass", type: .generic, source: .cameraScan, barcode: barcode)
        modelContext.insert(card)
        try? modelContext.save()
        container.analytics.track(.cardCreated)
        dismiss()
    }
}

private struct ScannerOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(PasslyTheme.accent, style: StrokeStyle(lineWidth: 3, dash: [16, 10]))
            .frame(width: 280, height: 220)
            .overlay {
                VStack {
                    Rectangle()
                        .fill(PasslyTheme.accent)
                        .frame(height: 2)
                    Spacer()
                }
                .padding(10)
            }
            .padding(.top, 90)
            .accessibilityHidden(true)
    }
}

private struct CameraScannerView: UIViewControllerRepresentable {
    let onCode: (String, BarcodeFormat) -> Void
    let permissionDenied: () -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        controller.permissionDenied = permissionDenied
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

private final class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String, BarcodeFormat) -> Void)?
    var permissionDenied: (() -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    allowed ? self?.start() : self?.permissionDenied?()
                }
            }
        default:
            permissionDenied?()
        }
    }

    private func start() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            permissionDenied?()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr, .code128, .pdf417, .aztec, .ean13, .ean8, .upce, .code39, .codabar, .itf14, .dataMatrix]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didEmit,
              let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let value = object.stringValue else { return }
        didEmit = true
        session.stopRunning()
        onCode?(value, object.type.passlyFormat)
    }
}

private extension AVMetadataObject.ObjectType {
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
