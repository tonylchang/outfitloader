import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([
        AvatarProfile.self,
        ClosetCategory.self,
        WardrobeItem.self,
        OutfitLook.self,
        OutfitSlot.self,
        ImageAsset.self
    ])

    static func makeDefault() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
