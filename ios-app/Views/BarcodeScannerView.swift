internal import SwiftUI
import AVFoundation
import Combine

struct BarcodeScannerView: View {
    let onCodeScanned: (String) -> Void
    let onClose: () -> Void

    @StateObject private var viewModel = BarcodeScannerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeCameraPreview(
                    session: viewModel.session,
                    authorizationStatus: viewModel.authorizationStatus,
                    onCodeScanned: { code in
                        guard viewModel.markScanHandled() else { return }
                        onCodeScanned(code)
                    }
                )
                .ignoresSafeArea()

                scannerOverlay
            }
            .navigationTitle("Barcode scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") {
                        onClose()
                    }
                }
            }
            .task {
                await viewModel.requestCameraAccessIfNeeded()
                viewModel.startSessionIfAuthorized()
            }
            .onDisappear {
                viewModel.stopSession()
            }
        }
    }

    @ViewBuilder
    private var scannerOverlay: some View {
        switch viewModel.authorizationStatus {
        case .authorized:
            VStack {
                Spacer()
                Text("Richte den Barcode in den Rahmen aus")
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 24)
            }
        case .denied, .restricted:
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.largeTitle)
                Text("Kein Kamerazugriff")
                    .font(.headline)
                Text("Bitte erlaube den Kamerazugriff in den iOS-Einstellungen, um Barcodes zu scannen.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
        default:
            ProgressView("Kamera wird vorbereitet…")
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

@MainActor
final class BarcodeScannerViewModel: ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    let session = AVCaptureSession()
    private var hasHandledScan = false

    func requestCameraAccessIfNeeded() async {
        if authorizationStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func startSessionIfAuthorized() {
        guard authorizationStatus == .authorized else { return }
        hasHandledScan = false
    }

    func stopSession() {
        hasHandledScan = false
        if session.isRunning {
            session.stopRunning()
        }
    }

    func markScanHandled() -> Bool {
        guard !hasHandledScan else { return false }
        hasHandledScan = true
        return true
    }
}

struct BarcodeCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let authorizationStatus: AVAuthorizationStatus
    let onCodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, onCodeScanned: onCodeScanned)
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.session = session

        guard authorizationStatus == .authorized else {
            context.coordinator.stopSession()
            return
        }

        context.coordinator.configureIfNeeded()
        context.coordinator.startSession()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let session: AVCaptureSession
        private let onCodeScanned: (String) -> Void
        private var configured = false

        init(session: AVCaptureSession, onCodeScanned: @escaping (String) -> Void) {
            self.session = session
            self.onCodeScanned = onCodeScanned
        }

        func configureIfNeeded() {
            guard !configured else { return }

            session.beginConfiguration()
            defer {
                session.commitConfiguration()
                configured = true
            }

            guard let videoDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  session.canAddInput(videoInput) else { return }

            session.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            guard session.canAddOutput(metadataOutput) else { return }
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce]
        }

        func startSession() {
            guard configured, !session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }

        func stopSession() {
            guard session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.stopRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }

            stopSession()
            onCodeScanned(value)
        }
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
