import Foundation
import SwiftData

enum AvatarProcessingStatus: String {
    case pending
    /// A transparent silhouette was generated from the source selfie.
    case ready
    /// Vision could not isolate a person; the original photo stands in for the silhouette.
    case failed
}

@Model
final class AvatarProfile {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var displayName: String?
    var isActive: Bool
    @Relationship(deleteRule: .cascade) var sourceImage: ImageAsset?
    @Relationship(deleteRule: .cascade) var silhouetteImage: ImageAsset?
    @Relationship(deleteRule: .cascade) var previewImage: ImageAsset?
    var processingStatusRawValue: String
    var heightCentimeters: Double?
    var shoulderAdjustment: Double
    var torsoAdjustment: Double
    var waistAdjustment: Double
    var hipAdjustment: Double
    var legAdjustment: Double
    var poseConfidence: Double?
    var bodyLandmarksJSON: Data?

    var processingStatus: AvatarProcessingStatus? {
        AvatarProcessingStatus(rawValue: processingStatusRawValue)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        displayName: String? = nil,
        isActive: Bool = true,
        processingStatus: AvatarProcessingStatus = .pending,
        heightCentimeters: Double? = nil,
        shoulderAdjustment: Double = 0,
        torsoAdjustment: Double = 0,
        waistAdjustment: Double = 0,
        hipAdjustment: Double = 0,
        legAdjustment: Double = 0,
        poseConfidence: Double? = nil,
        bodyLandmarksJSON: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.displayName = displayName
        self.isActive = isActive
        self.processingStatusRawValue = processingStatus.rawValue
        self.heightCentimeters = heightCentimeters
        self.shoulderAdjustment = shoulderAdjustment
        self.torsoAdjustment = torsoAdjustment
        self.waistAdjustment = waistAdjustment
        self.hipAdjustment = hipAdjustment
        self.legAdjustment = legAdjustment
        self.poseConfidence = poseConfidence
        self.bodyLandmarksJSON = bodyLandmarksJSON
    }
}
