# outfitloader

A native iOS/iPadOS app that turns a full-body selfie into a digital avatar and lets you photograph your real clothing to build a virtual closet, then mix and match outfits on your own body shape in seconds instead of trying everything on.

## Status

Pre-release. Milestone 1, a TestFlight-able MVP, is implementation-complete and being prepared for TestFlight:

- **Done:** app shell, on-device avatar creation (Vision person segmentation), avatar body-shape controls, digital closet with native background removal and replace-photo for clothing items, a try-on studio with tap-to-place and drag positioning, saved looks with lookbook reopen, settings with local data deletion, privacy policy draft, and an initial physical-device run.
- **Next:** App Store Connect privacy answers, version/build number confirmation, archive, and manual TestFlight upload.

See `docs/MVP_ARCHITECTURE.md` for the implementation plan and current slice status, `docs/TECHNICAL_SPIKE_CAPTURE_COMPOSITING.md` for the spike that validated the pipeline, `docs/APP_STORE_CONNECT_PREP.md` for upload metadata, `docs/TESTFLIGHT_READINESS_CHECKLIST.md` for the final device validation pass, and `docs/privacy.html` for the current privacy policy draft.

## How It Works

1. Capture or import a full-body selfie; a transparent silhouette is generated on device with Vision.
2. Photograph or import clothing items; Vision foreground extraction produces transparent cutouts, falling back to the original photo when it can't separate the item.
3. Assemble outfits on the try-on canvas with deterministic layering (bottoms, shoes, tops, accessories) and per-item scale, rotation, and opacity.
4. Save complete looks to the lookbook and reopen them later in the try-on studio.

## Stack & Privacy

- Swift, SwiftUI, SwiftData, Vision, Core Image, AVFoundation, PhotosUI - Apple frameworks only, no third-party dependencies, no backend.
- iOS 26 / iPadOS 26 minimum; iPhone and iPad.
- All photos, silhouettes, wardrobe data, and saved looks stay on device. No analytics or tracking.

## Building

Open `Outfitloader.xcodeproj` in Xcode 26 or later and run the `Outfitloader` scheme. Camera capture requires a physical device; photo import works in the simulator. The project uses a file-system-synchronized folder, so new files under `Outfitloader/` join the target automatically.

## Spec-Driven Development

The project specification lives in `spec/elements/`, with one file per concern: purpose, features, stack, UI, infra, constraints, project plan, versioning, and context. It is the source of truth for scope and constraints. Agent guidance lives in `AGENTS.md`. The `/spec-init`, `/spec-save-original`, `/spec-update`, and `/spec-check` workflows are defined in `spec/workflows/`, and `spec/original/` preserves the initial spec baseline.

## License

Not yet decided. Treat the project as private/proprietary for now (see `spec/elements/CONSTRAINTS.md`).
