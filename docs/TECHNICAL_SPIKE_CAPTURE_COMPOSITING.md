# Technical Spike: Capture, Silhouette, And Compositing

> **Status (2026-07-03):** Complete and retired. The validated pipeline moved into
> the MVP app structure (see `MVP_ARCHITECTURE.md` for slice status); the
> one-screen spike UI was deleted when the real app shell landed. The
> "Prototype" section below records where each spike component ended up.

## Goal

Validate the riskiest MVP path with native Apple frameworks:

- Guided full-body selfie capture.
- Body/person segmentation into a usable silhouette.
- Clothing image capture/import.
- Basic clothing overlay/compositing on the avatar.

## Prototype Added

The spike added a minimal SwiftUI iOS target with a single spike screen. When the
MVP app shell was scaffolded, the validated services moved into the real module
layout and the spike screen was deleted:

| Spike file | Where it is now |
| --- | --- |
| `Outfitloader/OutfitloaderApp.swift` | `Outfitloader/App/OutfitloaderApp.swift`, rewritten for SwiftData and `AppRootView` |
| `Outfitloader/SpikeRootView.swift` | Deleted; replaced by the app shell and feature views. Its guided camera sheet was extracted to `Outfitloader/Imaging/CameraCapture/GuidedCameraSheet.swift` |
| `Outfitloader/CameraCaptureView.swift` | `Outfitloader/Imaging/CameraCapture/CameraCaptureView.swift` |
| `Outfitloader/PersonSilhouetteGenerator.swift` | `Outfitloader/Imaging/PersonSilhouetteGenerator.swift` |
| `Outfitloader/ClothingForegroundExtractor.swift` | `Outfitloader/Imaging/ClothingForegroundExtractor.swift` |
| `Outfitloader/TryOnComposer.swift` | `Outfitloader/Imaging/TryOnComposer.swift`, generalized from one clothing image to N z-ordered layers |
| `Outfitloader/ImageUtilities.swift` | `Outfitloader/Imaging/ImageUtilities.swift` |
| `Outfitloader/Info.plist` | `Outfitloader/Info.plist`, unchanged |

The prototype was intentionally not the full MVP app shell. It was a focused technical slice for the avatar/closet/try-on risk.

## What It Tests

### Guided Selfie Capture

- Uses `AVFoundation` through a SwiftUI `UIViewControllerRepresentable` bridge.
- Supports front camera for avatar capture.
- Draws a full-body framing guide over the camera preview.
- Provides camera permission text in `Info.plist`.
- Includes a PhotosUI import fallback for environments without camera access.

### Body / Person Silhouette

- Uses `VNGeneratePersonSegmentationRequest` from Vision.
- Uses Core Image `CIBlendWithMask` to convert the person mask into a transparent-background silhouette.
- Falls back to the original avatar image if Vision cannot produce a mask.

### Clothing Capture / Import

- Uses back camera capture for clothing photos.
- Uses `PhotosPicker` for camera-roll import without broad library browsing.
- Normalizes image orientation and resizes large images for spike performance.
- Uses `VNGenerateForegroundInstanceMaskRequest` to attempt native foreground-object extraction for isolated clothing photos.
- Falls back to the original clothing photo if Vision cannot separate foreground from background.

### Basic Overlay / Compositing

- Uses a SwiftUI try-on canvas for live placement.
- Supports manual drag placement, scale, rotation, and opacity.
- Supports Avatar and Clothing tabs so only one layer's scale, rotation, and opacity are editable at a time.
- Uses normalized avatar-canvas placement so the same transform can later map to saved `OutfitSlot` data.
- Uses `TryOnComposer` to render a composite image with `UIGraphicsImageRenderer`.

## Verification

Completed:

- Swift type-check against the local iPhoneOS SDK:

  ```sh
  SDK=$(xcrun --sdk iphoneos --show-sdk-path)
  xcrun swiftc -typecheck \
    -module-cache-path /private/tmp/outfitloader-module-cache \
    -target arm64-apple-ios26.0 \
    -sdk "$SDK" \
    Outfitloader/*.swift
  ```

- Plist validation:

  ```sh
  plutil -lint Outfitloader/Info.plist Outfitloader.xcodeproj/project.pbxproj
  ```

Observed environment limitation:

- `xcodebuild` was terminated by the sandbox while initializing Xcode/CoreSimulator services, before compilation. The direct `swiftc` type-check succeeded, so the Swift/API surface is valid, but a full Xcode build should still be run locally outside the sandbox.

## Findings

- Native-only implementation is feasible for the spike path.
- PhotosUI import, AVFoundation capture, Vision segmentation, foreground instance masks, Core Image masking, and UIKit rendering compose cleanly without third-party dependencies.
- Physical validation showed avatar/person segmentation was good enough to continue, although silhouette edges were rough.
- Physical validation also showed that unprocessed clothing photos are not good enough for a credible composite because the photo background appears as a rectangle over the avatar.
- Native Vision foreground extraction is now included in the spike so isolated clothing photos can produce transparent-background overlays before considering external dependencies.
- The UI/persistence boundary in `MVP_ARCHITECTURE.md` is still valid: the compositor should operate on image inputs and normalized transforms, not SwiftData models directly.

## Remaining Device Validation

Run this on a physical iPhone before treating the spike as proven:

- Clothing foreground extraction with varied garment types, carpet/floor textures, lighting, shadows, and similar foreground/background colors.
- Whether Vision foreground extraction creates acceptable edges for common closet items without manual cleanup.
- Whether a garment should be captured on a contrasting background as part of guided capture instructions.
- Whether a silhouette from one selfie feels accurate enough after basic body-shape controls.
- Memory/performance on large imported images.

## Recommendation

Proceed with the MVP using this pipeline shape:

1. Keep guided avatar capture and clothing capture in the app shell.
2. Generate a transparent avatar silhouette on-device with Vision/Core Image.
3. Store original and derived images through the planned local media store.
4. Use normalized outfit slot transforms for tap/drag placement.
5. Keep lightweight native clothing foreground extraction in the MVP because unprocessed rectangular clothing photos undermine the core try-on experience.
