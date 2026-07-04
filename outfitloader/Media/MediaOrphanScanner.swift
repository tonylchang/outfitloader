import Foundation
import SwiftData

/// Result of comparing SwiftData image rows against the files on disk.
/// Carries counts only - never paths - so it can be logged without exposing
/// user media locations.
struct MediaOrphanScanReport: Equatable {
    /// ImageAsset rows whose backing file is missing, keyed by kind raw value.
    var missingFilesByKind: [String: Int] = [:]
    /// Files on disk that no ImageAsset row references.
    var orphanedDurableFileCount = 0
    var orphanedCachedFileCount = 0

    var hasFindings: Bool {
        !missingFilesByKind.isEmpty || orphanedDurableFileCount > 0 || orphanedCachedFileCount > 0
    }
}

/// Debug-only integrity check for the media write/delete rules: every row has
/// a file, and every file has a row. Findings mean a transaction cleanup path
/// is broken somewhere.
@MainActor
struct MediaOrphanScanner {
    let modelContext: ModelContext
    let mediaStore: MediaStore

    func scan() async throws -> MediaOrphanScanReport {
        let assets = try modelContext.fetch(FetchDescriptor<ImageAsset>())
        let references = assets.map {
            (relativePath: $0.relativePath, kindRawValue: $0.kindRawValue)
        }

        var report = MediaOrphanScanReport()
        var referencedDurable: Set<String> = []
        var referencedCached: Set<String> = []

        for reference in references {
            guard let kind = ImageAssetKind(rawValue: reference.kindRawValue) else {
                report.missingFilesByKind[reference.kindRawValue, default: 0] += 1
                continue
            }

            if kind.isCacheStored {
                referencedCached.insert(reference.relativePath)
            } else {
                referencedDurable.insert(reference.relativePath)
            }

            if await !mediaStore.fileExists(relativePath: reference.relativePath, kind: kind) {
                report.missingFilesByKind[reference.kindRawValue, default: 0] += 1
            }
        }

        let onDisk = await mediaStore.listAllRelativePaths()
        report.orphanedDurableFileCount = onDisk.durable.subtracting(referencedDurable).count
        report.orphanedCachedFileCount = onDisk.cached.subtracting(referencedCached).count

        return report
    }
}
