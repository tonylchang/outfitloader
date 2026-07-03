import SwiftUI
import UIKit

/// Live try-on canvas: the avatar silhouette with clothing layers rendered in
/// deterministic category order. Layers are draggable; tapping selects a layer
/// for the transform controls.
struct TryOnCanvasView: View {
    let avatarImage: UIImage?
    @Bindable var composition: TryOnComposition

    private static let coordinateSpaceName = "tryOnCanvas"

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let fittedAvatarRect = avatarImage.map {
                CGRect.aspectFit(size: $0.size, in: bounds.insetBy(dx: 8, dy: 8))
            } ?? .zero
            let avatarRect = fittedAvatarRect.scaledFromCenter(by: composition.avatarAdjustment.scale)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))

                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: avatarRect.width, height: avatarRect.height)
                        .opacity(composition.avatarAdjustment.opacity)
                        .rotationEffect(.radians(composition.avatarAdjustment.rotationRadians))
                        .position(x: avatarRect.midX, y: avatarRect.midY)
                        .onTapGesture {
                            composition.selection = .avatar
                        }

                    ForEach(composition.sortedLayers) { layer in
                        layerView(layer, avatarRect: avatarRect)
                    }
                } else {
                    ContentUnavailableView(
                        "No Avatar",
                        systemImage: "person.crop.rectangle",
                        description: Text("Create an avatar to start trying on outfits.")
                    )
                }
            }
            .coordinateSpace(name: Self.coordinateSpaceName)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func layerView(_ layer: TryOnLayer, avatarRect: CGRect) -> some View {
        let width = max(avatarRect.width * layer.placement.scale, 44)
        let height = layer.image.size.width > 0
            ? width * layer.image.size.height / layer.image.size.width
            : width
        let center = CGPoint(
            x: avatarRect.minX + avatarRect.width * layer.placement.anchor.x,
            y: avatarRect.minY + avatarRect.height * layer.placement.anchor.y
        )
        let isSelected = composition.selection == .layer(layer.id)

        return Image(uiImage: layer.image)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .opacity(layer.placement.opacity)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            Color.accentColor.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .padding(-6)
                }
            }
            .rotationEffect(.radians(layer.placement.rotationRadians))
            .position(center)
            .accessibilityLabel("\(layer.itemName), \(layer.categoryKind.displayName)")
            .onTapGesture {
                composition.selection = .layer(layer.id)
            }
            .gesture(
                DragGesture(coordinateSpace: .named(Self.coordinateSpaceName))
                    .onChanged { value in
                        guard avatarRect.width > 0, avatarRect.height > 0 else {
                            return
                        }

                        composition.selection = .layer(layer.id)
                        composition.updatePlacement(layerID: layer.id) { placement in
                            placement.anchor = CGPoint(
                                x: ((value.location.x - avatarRect.minX) / avatarRect.width).clamped(to: 0...1),
                                y: ((value.location.y - avatarRect.minY) / avatarRect.height).clamped(to: 0...1)
                            )
                        }
                    }
            )
    }
}

/// Transform controls for the current canvas selection (avatar or one layer).
/// The sliders stay collapsed behind a toggle so the canvas keeps the vertical
/// space by default — the composite is the focus of the screen.
struct TryOnControlsView: View {
    @Bindable var composition: TryOnComposition
    @State private var showsAdjustments = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Adjust", selection: $composition.selection) {
                    Text("Avatar").tag(CanvasSelection.avatar)

                    ForEach(composition.sortedLayers) { layer in
                        Text(layer.categoryKind.displayName)
                            .tag(CanvasSelection.layer(layer.id))
                    }
                }
                .pickerStyle(.segmented)

                if case .layer(let layerID) = composition.selection {
                    Button(role: .destructive) {
                        composition.removeLayer(id: layerID)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Remove item from outfit")
                }

                Toggle(isOn: $showsAdjustments.animation(.snappy)) {
                    Image(systemName: "slider.horizontal.3")
                }
                .toggleStyle(.button)
                .accessibilityLabel("Adjust scale, rotation, and opacity")
            }

            if showsAdjustments {
                VStack(spacing: 6) {
                    sliderRow("Scale", value: scaleBinding, in: scaleRange) {
                        Text($0, format: .number.precision(.fractionLength(2)))
                    }

                    sliderRow("Rotation", value: rotationDegreesBinding, in: rotationRange) {
                        Text("\(Int($0.rounded()))°")
                    }

                    sliderRow("Opacity", value: opacityBinding, in: opacityRange) {
                        Text($0, format: .number.precision(.fractionLength(2)))
                    }
                }
                .transition(.opacity)
            }
        }
        .font(.subheadline)
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        @ViewBuilder label: (Double) -> some View
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 72, alignment: .leading)

            Slider(value: value, in: range) {
                Text(title)
            }

            label(value.wrappedValue)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: - Selection bindings

    private var selectedLayerID: UUID? {
        if case .layer(let id) = composition.selection {
            return id
        }

        return nil
    }

    private var scaleRange: ClosedRange<Double> {
        selectedLayerID == nil ? 0.65...1.35 : 0.15...0.9
    }

    private var rotationRange: ClosedRange<Double> {
        selectedLayerID == nil ? -20...20 : -35...35
    }

    private var opacityRange: ClosedRange<Double> {
        selectedLayerID == nil ? 0.25...1 : 0.35...1
    }

    private var scaleBinding: Binding<Double> {
        Binding {
            if let layerID = selectedLayerID {
                return Double(composition.layer(id: layerID)?.placement.scale ?? 0.42)
            }

            return Double(composition.avatarAdjustment.scale)
        } set: { newValue in
            if let layerID = selectedLayerID {
                composition.updatePlacement(layerID: layerID) { $0.scale = newValue }
            } else {
                composition.avatarAdjustment.scale = newValue
            }
        }
    }

    private var rotationDegreesBinding: Binding<Double> {
        Binding {
            let radians: CGFloat
            if let layerID = selectedLayerID {
                radians = composition.layer(id: layerID)?.placement.rotationRadians ?? 0
            } else {
                radians = composition.avatarAdjustment.rotationRadians
            }

            return Double(radians) * 180 / .pi
        } set: { newValue in
            let radians = CGFloat(newValue) * .pi / 180
            if let layerID = selectedLayerID {
                composition.updatePlacement(layerID: layerID) { $0.rotationRadians = radians }
            } else {
                composition.avatarAdjustment.rotationRadians = radians
            }
        }
    }

    private var opacityBinding: Binding<Double> {
        Binding {
            if let layerID = selectedLayerID {
                return Double(composition.layer(id: layerID)?.placement.opacity ?? 1)
            }

            return Double(composition.avatarAdjustment.opacity)
        } set: { newValue in
            if let layerID = selectedLayerID {
                composition.updatePlacement(layerID: layerID) { $0.opacity = newValue }
            } else {
                composition.avatarAdjustment.opacity = newValue
            }
        }
    }
}
