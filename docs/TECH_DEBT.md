# Technical Debt

This document tracks known engineering debt that should not block the first TestFlight upload but should stay explicit.

## Deferred

- Pose detection is not implemented in the MVP. The app uses person segmentation for silhouettes and manual body-shape sliders for visual adjustment.
- Editable/refinable clothing masks are not stored in the MVP. Add mask schema only when Phase 1 validation proves users need manual or automated mask refinement.

## Resolved

- Startup no longer terminates when even the in-memory fallback SwiftData container fails (2026-07-03): the app shows a SwiftData-free error screen with recovery guidance instead of calling fatalError.

- `MediaStore` was promoted from a synchronous value type behind a serial IO queue to an actor (2026-07-03). A shared instance keeps app-wide IO serialized, repositories and views await it, image encoding now runs off the main thread, and SwiftData models never cross the actor boundary. Repository delete flows also now save SwiftData before removing files, so a failed save cannot leave rows pointing at deleted media.

## Decided

- `WardrobeItem` no longer carries a `category` relationship to `ClosetCategory` (decided 2026-07-04). The relationship and `categoryKindRawValue` were two hand-synced sources of truth for the same fact; the raw value is what every query and view filters on, so it is now the only one. The seeded `ClosetCategory` table stays in the schema as scaffolding for future custom categories — dropping a whole entity from a TestFlight-shipped store is migration risk with no user-visible benefit. Reintroduce an item→category reference only when custom categories actually land.

- Durable originals and the local store stay included in standard user-controlled device backups (decided 2026-07-03). Backups are encrypted and user-managed, and excluding only some artifacts would leave restored devices with database rows pointing at missing media. The privacy policy states the backup nuance explicitly. Revisit only if a Phase 1 backup opt-out toggle plus export feature is added.
