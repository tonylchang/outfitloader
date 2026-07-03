import SwiftUI
import UIKit

struct GuidedCameraSheet: View {
    let mode: CameraCaptureView.Mode
    let title: String
    let guidance: String
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var captureRequestID: UUID?

    var body: some View {
        ZStack {
            CameraCaptureView(
                mode: mode,
                captureRequestID: $captureRequestID
            ) { image in
                onCapture(image)
                dismiss()
            }
            .ignoresSafeArea()

            CameraGuideOverlay(mode: mode)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Text(guidance)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.regularMaterial)

                Spacer()

                Button {
                    captureRequestID = UUID()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 74, height: 74)
                        Circle()
                            .stroke(.black.opacity(0.25), lineWidth: 2)
                            .frame(width: 62, height: 62)
                    }
                }
                .accessibilityLabel("Capture photo")
                .padding(.bottom, 36)
            }
        }
    }
}

private struct CameraGuideOverlay: View {
    let mode: CameraCaptureView.Mode

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let guideWidth = mode == .avatarSelfie ? size.width * 0.58 : size.width * 0.72
            let guideHeight = mode == .avatarSelfie ? size.height * 0.66 : size.height * 0.44

            ZStack {
                Color.black.opacity(0.20)

                RoundedRectangle(cornerRadius: mode == .avatarSelfie ? guideWidth / 2 : 18)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                    .frame(width: guideWidth, height: guideHeight)
                    .shadow(radius: 8)

                VStack {
                    Spacer()
                    Text(mode == .avatarSelfie ? "Full body in frame" : "Single item in frame")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(.bottom, 128)
                }
            }
        }
    }
}
