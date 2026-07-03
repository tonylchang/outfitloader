import Foundation
import Observation
import UIKit

enum CanvasSelection: Hashable {
    case avatar
    case layer(UUID)
}

/// One wardrobe item placed on the try-on canvas. Placement uses normalized
/// avatar-canvas coordinates so it maps directly onto saved `OutfitSlot` data.
struct TryOnLayer: Identifiable {
    let id: UUID
    let itemID: UUID
    let itemName: String
    let categoryKind: CategoryKind
    let image: UIImage
    var placement: ClothingPlacement

    var zIndex: Int {
        categoryKind.layerIndex
    }
}

/// Unsaved try-on state. Lives outside SwiftData until the user saves a look.
@Observable
final class TryOnComposition {
    var avatarAdjustment = AvatarAdjustment()
    var selection: CanvasSelection = .avatar
    private(set) var layers: [TryOnLayer] = []

    var sortedLayers: [TryOnLayer] {
        layers.sorted { $0.zIndex < $1.zIndex }
    }

    var isPristine: Bool {
        layers.isEmpty && avatarAdjustment == AvatarAdjustment()
    }

    func layer(id: UUID) -> TryOnLayer? {
        layers.first { $0.id == id }
    }

    func isPlaced(itemID: UUID) -> Bool {
        layers.contains { $0.itemID == itemID }
    }

    /// Places an item with its category's default placement, replacing any
    /// item currently occupying the same category.
    func place(itemID: UUID, name: String, kind: CategoryKind, image: UIImage) {
        layers.removeAll { $0.categoryKind == kind }

        let layer = TryOnLayer(
            id: UUID(),
            itemID: itemID,
            itemName: name,
            categoryKind: kind,
            image: image,
            placement: kind.defaultPlacement
        )
        layers.append(layer)
        selection = .layer(layer.id)
    }

    func remove(itemID: UUID) {
        guard let layer = layers.first(where: { $0.itemID == itemID }) else {
            return
        }

        removeLayer(id: layer.id)
    }

    func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
        if selection == .layer(id) {
            selection = .avatar
        }
    }

    func updatePlacement(layerID: UUID, _ change: (inout ClothingPlacement) -> Void) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else {
            return
        }

        change(&layers[index].placement)
    }

    func reset() {
        layers.removeAll()
        avatarAdjustment = AvatarAdjustment()
        selection = .avatar
    }
}

extension CategoryKind {
    var defaultPlacement: ClothingPlacement {
        switch self {
        case .tops:
            return ClothingPlacement(anchor: CGPoint(x: 0.5, y: 0.35), scale: 0.55, rotationRadians: 0, opacity: 0.96)
        case .bottoms:
            return ClothingPlacement(anchor: CGPoint(x: 0.5, y: 0.62), scale: 0.5, rotationRadians: 0, opacity: 0.96)
        case .shoes:
            return ClothingPlacement(anchor: CGPoint(x: 0.5, y: 0.9), scale: 0.3, rotationRadians: 0, opacity: 0.96)
        case .accessories:
            return ClothingPlacement(anchor: CGPoint(x: 0.5, y: 0.16), scale: 0.25, rotationRadians: 0, opacity: 0.96)
        }
    }
}
