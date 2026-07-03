# Technical Debt

This document tracks known engineering debt that should not block the first TestFlight upload but should stay explicit.

## Deferred

- `MediaStore` is still a synchronous value type, now protected by a serial IO queue. If media work becomes more concurrent or long-running, promote it to an async actor-backed service and update repository APIs around that boundary.
- `OutfitloaderApp` now falls back to an in-memory SwiftData container and shows a local-store error screen when persistent store creation fails. If even the fallback container cannot be created, startup still terminates because SwiftUI views require a model container.
- Pose detection is not implemented in the MVP. The app uses person segmentation for silhouettes and manual body-shape sliders for visual adjustment.
- Editable/refinable clothing masks are not stored in the MVP. Add mask schema only when Phase 1 validation proves users need manual or automated mask refinement.

## Decided

- Durable originals and the local store stay included in standard user-controlled device backups (decided 2026-07-03). Backups are encrypted and user-managed, and excluding only some artifacts would leave restored devices with database rows pointing at missing media. The privacy policy states the backup nuance explicitly. Revisit only if a Phase 1 backup opt-out toggle plus export feature is added.
