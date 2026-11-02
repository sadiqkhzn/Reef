import AVFoundation
import SwiftUI

/// Runs a front-camera capture session for the mirror pane. The session is only
/// alive while the pane is on screen; callers start it on appear and stop it on
/// disappear so the camera light never lingers.
@MainActor
final class WebcamModel: ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var authorized = false
    @Published private(set) var denied = false
    @Published var mirrored = true
    @Published private(set) var frozen = false

    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.authorized = granted
                    self.denied = !granted
                    if granted { self.configureAndRun() }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        let session = session
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
        }
    }

    func toggleFreeze() {
        frozen.toggle()
        if frozen { stop() } else { configureAndRun() }
    }

    private func configureAndRun() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .high
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)
            if let device, let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            configured = true
        }
        guard !frozen else { return }
        let session = session
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }
    }
}

/// Hosts the capture preview layer, honoring the mirror toggle.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let preview = nsView.layer as? AVCaptureVideoPreviewLayer else { return }
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
