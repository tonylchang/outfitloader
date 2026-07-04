import AVFoundation
import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    enum Mode {
        case avatarSelfie
        case clothing

        var cameraPosition: AVCaptureDevice.Position {
            switch self {
            case .avatarSelfie:
                return .front
            case .clothing:
                return .back
            }
        }
    }

    let mode: Mode
    @Binding var captureRequestID: UUID?
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        CameraCaptureViewController(
            cameraPosition: mode.cameraPosition,
            onCapture: onCapture
        )
    }

    func updateUIViewController(_ viewController: CameraCaptureViewController, context: Context) {
        guard let captureRequestID, context.coordinator.lastCaptureRequestID != captureRequestID else {
            return
        }

        context.coordinator.lastCaptureRequestID = captureRequestID
        viewController.capturePhoto()
    }

    final class Coordinator {
        var lastCaptureRequestID: UUID?
    }
}

final class CameraCaptureViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let cameraPosition: AVCaptureDevice.Position
    private let onCapture: (UIImage) -> Void
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.outfitloader.camera-session")
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    private var isConfigured = false
    private var messageLabel: UILabel?

    init(
        cameraPosition: AVCaptureDevice.Position,
        onCapture: @escaping (UIImage) -> Void
    ) {
        self.cameraPosition = cameraPosition
        self.onCapture = onCapture
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Interruptions (phone calls, Split View) usually resume on their
        // own, but not always; media-services resets never do. Restart the
        // session in both cases so the preview cannot silently stay frozen.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeErrorOccurred),
            name: AVCaptureSession.runtimeErrorNotification,
            object: captureSession
        )

        configureIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else {
                return
            }

            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }

            settings.photoQualityPrioritization = .balanced
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)?.normalizedForProcessing()
        else {
            showMessage("The photo couldn't be captured. Try again.", autoHideAfter: 2.5)
            return
        }

        DispatchQueue.main.async { [onCapture] in
            onCapture(image)
        }
    }

    @objc private func sessionInterruptionEnded() {
        restartSessionIfNeeded()
    }

    @objc private func sessionRuntimeErrorOccurred(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        guard error?.code == .mediaServicesWereReset else {
            return
        }

        restartSessionIfNeeded()
    }

    private func restartSessionIfNeeded() {
        sessionQueue.async { [captureSession, isConfigured] in
            if isConfigured, !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else {
            return
        }

        isConfigured = true

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
                if isGranted {
                    self?.configureSession()
                } else {
                    self?.showMessage("Camera access is required to capture photos.")
                }
            }
        case .denied, .restricted:
            showMessage("Camera access is disabled. Use photo import or enable camera access in Settings.")
        @unknown default:
            showMessage("Camera access is unavailable.")
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: self.cameraPosition
            ) else {
                self.showMessage("No camera is available in this environment.")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)

                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .photo

                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                if self.captureSession.canAddOutput(self.photoOutput) {
                    self.captureSession.addOutput(self.photoOutput)
                }

                self.captureSession.commitConfiguration()
                self.captureSession.startRunning()
            } catch {
                self.showMessage("Camera setup failed. Use photo import instead.")
            }
        }
    }

    /// Persistent when `autoHideAfter` is nil (configuration failures);
    /// transient for recoverable errors like a failed capture.
    private func showMessage(_ message: String, autoHideAfter delay: TimeInterval? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            let label = self.messageLabel ?? UILabel()
            label.text = message
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = .preferredFont(forTextStyle: .body)
            label.translatesAutoresizingMaskIntoConstraints = false

            if label.superview == nil {
                self.view.addSubview(label)
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24),
                    label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24),
                    label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
                ])
            }

            label.isHidden = false
            self.messageLabel = label
            UIAccessibility.post(notification: .announcement, argument: message)

            if let delay {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak label] in
                    // Leave the label alone if a newer message replaced this one.
                    if label?.text == message {
                        label?.isHidden = true
                    }
                }
            }
        }
    }
}
