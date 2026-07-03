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
    private var unavailableLabel: UILabel?

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
            return
        }

        DispatchQueue.main.async { [onCapture] in
            onCapture(image)
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
                    self?.showUnavailableMessage("Camera access is required for this spike.")
                }
            }
        case .denied, .restricted:
            showUnavailableMessage("Camera access is disabled. Use photo import or enable camera access in Settings.")
        @unknown default:
            showUnavailableMessage("Camera access is unavailable.")
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
                self.showUnavailableMessage("No camera is available in this environment.")
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
                self.showUnavailableMessage("Camera setup failed. Use photo import for this run.")
            }
        }
    }

    private func showUnavailableMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            let label = self.unavailableLabel ?? UILabel()
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

            self.unavailableLabel = label
        }
    }
}
