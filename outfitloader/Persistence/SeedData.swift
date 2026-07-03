import Foundation
import SwiftData

enum SeedData {
    /// Seeds the four system categories on first launch. Categories are SwiftData
    /// records rather than a hard-coded enum so the closet grid can query, filter,
    /// and sort consistently, and so custom categories stay possible later.
    static func seedDefaultCategories(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<ClosetCategory>()) == 0 else {
            return
        }

        for (index, kind) in CategoryKind.allCases.enumerated() {
            context.insert(ClosetCategory(kind: kind, sortIndex: index, isSystem: true))
        }

        try context.save()
    }
}
