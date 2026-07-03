import PhotosUI
import SwiftUI
import UIKit

struct SpikeRootView: View {
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var clothingPickerItem: PhotosPickerItem?
    @State private var sourceAvatarImage: UIImage?
    @State private var avatarSilhouetteImage: UIImage?
    @State private var sourceClothingImage: UIImage?
    @State private var clothingImage: UIImage?
    @State private var renderedComposite: UIImage?
    @State private var avatarAdjustment = AvatarAdjustment()
    @State private var placement = ClothingPlacement()
    @State private var isProcessingAvatar = false
    @State private var isProcessingClothing = false
    @State private var avatarStatusMessage = "Import or capture a full-body selfie to start the spike."
    @State private var clothingStatusMessage = "Import or capture one clothing item for the overlay test."
    @State private var showingAvatarCamera = false
    @State private var showingClothingCamera = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                if proxy.size.width >= 820 {
                    HStack(alignment: .top, spacing: 20) {
                        captureColumn
                            .frame(width: min(380, proxy.size.width * 0.38))

                        previewColumn
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            captureColumn
                            previewColumn
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Try-On Spike")
            .toolbar {
                Button {
                    resetSpike()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
            .sheet(isPresented: $showingAvatarCamera) {
                GuidedCameraSheet(
                    mode: .avatarSelfie,
                    title: "Selfie Capture",
                    guidance: "Keep your full body inside the guide with clear lighting."
                ) { image in
                    handleAvatarImage(image)
                }
            }
            .sheet(isPresented: $showingClothingCamera) {
                GuidedCameraSheet(
                    mode: .clothing,
                    title: "Clothing Capture",
                    guidance: "Place one item flat in frame with as plain a background as possible."
                ) { image in
                    handleClothingImage(image)
                }
            }
            .onChange(of: avatarPickerItem) { _, newItem in
                Task {
                    await loadAvatar(from: newItem)
                }
            }
            .onChange(of: clothingPickerItem) { _, newItem in
                Task {
                    await loadClothing(from: newItem)
                }
            }
        }
    }

    private var captureColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            CaptureCard(
                title: "Avatar",
                subtitle: avatarStatusMessage,
                systemImage: "person.crop.rectangle",
                isBusy: isProcessingAvatar
            ) {
                HStack {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        Label("Import", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingAvatarCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .buttonStyle(.borderedProminent)
                }

                ImagePreview(title: "Source", image: sourceAvatarImage)
                ImagePreview(title: "Silhouette", image: avatarSilhouetteImage)
            }

            CaptureCard(
                title: "Clothing",
                subtitle: clothingStatusMessage,
                systemImage: "tshirt",
                isBusy: isProcessingClothing
            ) {
                HStack {
                    PhotosPicker(selection: $clothingPickerItem, matching: .images) {
                        Label("Import", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingClothingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .buttonStyle(.borderedProminent)
                }

                ImagePreview(title: "Source", image: sourceClothingImage)
                ImagePreview(title: "Foreground", image: clothingImage)
            }
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Composite")
                .font(.title2.weight(.semibold))

            TryOnCanvas(
                avatarImage: avatarSilhouetteImage ?? sourceAvatarImage,
                clothingImage: clothingImage,
                avatarAdjustment: $avatarAdjustment,
                placement: $placement,
                renderedComposite: $renderedComposite
            )

            if let renderedComposite {
                ImagePreview(title: "Rendered Output", image: renderedComposite)
            }
        }
    }

    @MainActor
    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let image = await loadImage(from: item) else {
            return
        }

        handleAvatarImage(image)
    }

    @MainActor
    private func loadClothing(from item: PhotosPickerItem?) async {
        guard let image = await loadImage(from: item) else {
            return
        }

        handleClothingImage(image)
    }

    private func loadImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item else {
            return nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                return nil
            }

            return image.normalizedForProcessing()
        } catch {
            return nil
        }
    }

    @MainActor
    private func handleAvatarImage(_ image: UIImage) {
        sourceAvatarImage = image.resizedToFit(maxPixelSize: 1600)
        avatarSilhouetteImage = nil
        renderedComposite = nil
        avatarStatusMessage = "Running on-device Vision person segmentation..."
        isProcessingAvatar = true

        Task {
            await generateSilhouette(from: image)
        }
    }

    @MainActor
    private func handleClothingImage(_ image: UIImage) {
        let resized = image.resizedToFit(maxPixelSize: 1600)
        sourceClothingImage = resized
        clothingImage = nil
        renderedComposite = nil
        clothingStatusMessage = "Running on-device Vision foreground extraction..."
        isProcessingClothing = true

        Task {
            await extractClothingForeground(from: resized)
        }
    }

    private func generateSilhouette(from image: UIImage) async {
        do {
            let silhouette = try await Task.detached(priority: .userInitiated) {
                try PersonSilhouetteGenerator().makeSilhouette(from: image)
            }.value

            await MainActor.run {
                avatarSilhouetteImage = silhouette
                avatarStatusMessage = "Vision produced a transparent person silhouette."
                isProcessingAvatar = false
            }
        } catch {
            await MainActor.run {
                avatarSilhouetteImage = sourceAvatarImage
                avatarStatusMessage = "Vision failed: \(error.localizedDescription). The spike will use the original image for overlay testing."
                isProcessingAvatar = false
            }
        }
    }

    private func extractClothingForeground(from image: UIImage) async {
        do {
            let foreground = try await Task.detached(priority: .userInitiated) {
                try ClothingForegroundExtractor().extractForeground(from: image)
            }.value

            await MainActor.run {
                clothingImage = foreground
                clothingStatusMessage = "Vision extracted a transparent foreground item."
                isProcessingClothing = false
            }
        } catch {
            await MainActor.run {
                clothingImage = sourceClothingImage
                clothingStatusMessage = "Vision failed: \(error.localizedDescription). The spike will use the original clothing photo."
                isProcessingClothing = false
            }
        }
    }

    @MainActor
    private func resetSpike() {
        avatarPickerItem = nil
        clothingPickerItem = nil
        sourceAvatarImage = nil
        avatarSilhouetteImage = nil
        sourceClothingImage = nil
        clothingImage = nil
        renderedComposite = nil
        avatarAdjustment = AvatarAdjustment()
        placement = ClothingPlacement()
        isProcessingAvatar = false
        isProcessingClothing = false
        avatarStatusMessage = "Import or capture a full-body selfie to start the spike."
        clothingStatusMessage = "Import or capture one clothing item for the overlay test."
    }
}

private struct CaptureCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isBusy = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isBusy {
                    ProgressView()
                }
            }

            content
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ImagePreview: View {
    let title: String
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 132)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct TryOnCanvas: View {
    let avatarImage: UIImage?
    let clothingImage: UIImage?
    @Binding var avatarAdjustment: AvatarAdjustment
    @Binding var placement: ClothingPlacement
    @Binding var renderedComposite: UIImage?
    @State private var activeLayer: EditableCompositeLayer = .clothing

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { proxy in
                let canvasBounds = CGRect(origin: .zero, size: proxy.size)
                let fittedAvatarRect = avatarImage.map {
                    CGRect.aspectFit(size: $0.size, in: canvasBounds.insetBy(dx: 16, dy: 16))
                } ?? .zero
                let avatarRect = fittedAvatarRect.scaledFromCenter(by: avatarAdjustment.scale)

                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))

                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: avatarRect.width, height: avatarRect.height)
                            .opacity(avatarAdjustment.opacity)
                            .rotationEffect(.radians(Double(avatarAdjustment.rotationRadians)))
                            .position(x: avatarRect.midX, y: avatarRect.midY)
                    } else {
                        ContentUnavailableView(
                            "No Avatar",
                            systemImage: "person.crop.rectangle",
                            description: Text("Capture or import a selfie first.")
                        )
                    }

                    if let clothingImage, avatarImage != nil {
                        clothingLayer(clothingImage, avatarRect: avatarRect)
                            .allowsHitTesting(activeLayer == .clothing)
                    }
                }
                .coordinateSpace(name: "tryOnCanvas")
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(minHeight: 460)

            controls
        }
    }

    private func clothingLayer(_ image: UIImage, avatarRect: CGRect) -> some View {
        let width = max(avatarRect.width * placement.scale, 44)
        let height = image.size.width > 0 ? width * image.size.height / image.size.width : width
        let center = CGPoint(
            x: avatarRect.minX + avatarRect.width * placement.anchor.x,
            y: avatarRect.minY + avatarRect.height * placement.anchor.y
        )

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .opacity(placement.opacity)
            .rotationEffect(.radians(Double(avatarAdjustment.rotationRadians + placement.rotationRadians)))
            .position(center)
            .gesture(
                DragGesture(coordinateSpace: .named("tryOnCanvas"))
                    .onChanged { value in
                        guard avatarRect.width > 0, avatarRect.height > 0 else {
                            return
                        }

                        placement.anchor = CGPoint(
                            x: ((value.location.x - avatarRect.minX) / avatarRect.width).clamped(to: 0...1),
                            y: ((value.location.y - avatarRect.minY) / avatarRect.height).clamped(to: 0...1)
                        )
                        renderedComposite = nil
                    }
            )
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Layer", selection: $activeLayer) {
                ForEach(EditableCompositeLayer.allCases) { layer in
                    Text(layer.title)
                        .tag(layer)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Scale")
                    .frame(width: 76, alignment: .leading)
                Slider(value: activeScale, in: activeLayer.scaleRange)
                Text(activeScale.wrappedValue, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            HStack {
                Text("Rotation")
                    .frame(width: 76, alignment: .leading)
                Slider(value: activeRotationDegrees, in: activeLayer.rotationRange)
                Text("\(Int(activeRotationDegrees.wrappedValue.rounded()))°")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            HStack {
                Text("Opacity")
                    .frame(width: 76, alignment: .leading)
                Slider(value: activeOpacity, in: activeLayer.opacityRange)
                Text(activeOpacity.wrappedValue, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            Button {
                guard let avatarImage, let clothingImage else {
                    return
                }

                renderedComposite = TryOnComposer().compose(
                    avatar: avatarImage,
                    clothing: clothingImage,
                    avatarAdjustment: avatarAdjustment,
                    placement: placement
                )
            } label: {
                Label("Render Composite", systemImage: "square.2.layers.3d")
            }
            .buttonStyle(.borderedProminent)
            .disabled(avatarImage == nil || clothingImage == nil)
        }
        .font(.subheadline)
    }

    private var activeScale: Binding<Double> {
        Binding {
            switch activeLayer {
            case .avatar:
                Double(avatarAdjustment.scale)
            case .clothing:
                Double(placement.scale)
            }
        } set: { value in
            switch activeLayer {
            case .avatar:
                avatarAdjustment.scale = CGFloat(value)
            case .clothing:
                placement.scale = CGFloat(value)
            }
            renderedComposite = nil
        }
    }

    private var activeRotationDegrees: Binding<Double> {
        Binding {
            switch activeLayer {
            case .avatar:
                Double(avatarAdjustment.rotationRadians * 180 / .pi)
            case .clothing:
                Double(placement.rotationRadians * 180 / .pi)
            }
        } set: { value in
            switch activeLayer {
            case .avatar:
                avatarAdjustment.rotationRadians = CGFloat(value) * .pi / 180
            case .clothing:
                placement.rotationRadians = CGFloat(value) * .pi / 180
            }
            renderedComposite = nil
        }
    }

    private var activeOpacity: Binding<Double> {
        Binding {
            switch activeLayer {
            case .avatar:
                Double(avatarAdjustment.opacity)
            case .clothing:
                Double(placement.opacity)
            }
        } set: { value in
            switch activeLayer {
            case .avatar:
                avatarAdjustment.opacity = CGFloat(value)
            case .clothing:
                placement.opacity = CGFloat(value)
            }
            renderedComposite = nil
        }
    }
}

private extension CGRect {
    func scaledFromCenter(by scale: CGFloat) -> CGRect {
        let clampedScale = max(scale, 0.01)
        let scaledSize = CGSize(width: width * clampedScale, height: height * clampedScale)

        return CGRect(
            x: midX - scaledSize.width / 2,
            y: midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}

private enum EditableCompositeLayer: String, CaseIterable, Identifiable {
    case avatar
    case clothing

    var id: Self { self }

    var title: String {
        switch self {
        case .avatar:
            return "Avatar"
        case .clothing:
            return "Clothing"
        }
    }

    var scaleRange: ClosedRange<Double> {
        switch self {
        case .avatar:
            return 0.65...1.35
        case .clothing:
            return 0.15...0.9
        }
    }

    var rotationRange: ClosedRange<Double> {
        switch self {
        case .avatar:
            return -20...20
        case .clothing:
            return -35...35
        }
    }

    var opacityRange: ClosedRange<Double> {
        switch self {
        case .avatar:
            return 0.25...1
        case .clothing:
            return 0.35...1
        }
    }
}

private struct GuidedCameraSheet: View {
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

            GuideOverlay(mode: mode)
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

private struct GuideOverlay: View {
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

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
