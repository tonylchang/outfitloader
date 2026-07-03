# Technical Debt

This document tracks known engineering debt that should not block the first TestFlight upload but should stay explicit.

## Deferred

- `MediaStore` is still a synchronous value type, now protected by a serial IO queue. If media work becomes more concurrent or long-running, promote it to an async actor-backed service and update repository APIs around that boundary.
- `OutfitloaderApp` now falls back to an in-memory SwiftData container and shows a local-store error screen when persistent store creation fails. If even the fallback container cannot be created, startup still terminates because SwiftUI views require a model container.
- Pose detection is not implemented in the MVP. The app uses person segmentation for silhouettes and manual body-shape sliders for visual adjustment.
- Editable/refinable clothing masks are not stored in the MVP. Add mask schema only when Phase 1 validation proves users need manual or automated mask refinement.
- Decide before external TestFlight whether durable originals should be excluded from standard encrypted device backups for stricter local-only semantics.
