# MVP Architecture

This document translates the active spec into an implementation plan for the TestFlight-able MVP. It intentionally excludes Phase 1 work such as outfit scheduling, reminders, automated clothing segmentation, analytics, backend services, and sync.

> **Status (2026-07-03):** Implementation slices 1-5 are built and compile clean
> for the iOS device target: app shell, SwiftData models, MediaStore, closet
> CRUD with clothing foreground extraction, avatar onboarding with silhouette
> generation, and the try-on studio. Slices 6-9 remain (save-look flow, lookbook
> detail/reopen, privacy/settings affordances, device/TestFlight readiness
> pass). Sections below note where the implementation consolidated the original
> plan.

## Architecture Principles

- Native SwiftUI app for iPhone and iPad.
- SwiftData owns structured metadata; image pixels live as local files.
- No backend, no product analytics, no behavioral tracking, and no third-party SDKs by default.
- Keep avatar, wardrobe, and outfit processing on-device.
- Keep the avatar/compositing pipeline behind service protocols so the MVP can start simple and Phase 1 can improve segmentation without rewriting the UI or persistence layer.

## Module Layout

Layout as implemented. The Xcode target uses a file-system-synchronized folder, so files added under `Outfitloader/` join the target automatically without project-file edits.

```text
Outfitloader/
  App/
    OutfitloaderApp.swift
    AppRootView.swift
    MainShellView.swift
  Models/
    AvatarProfile.swift
    WardrobeItem.swift
    ClosetCategory.swift
    OutfitLook.swift
    OutfitSlot.swift
    ImageAsset.swift
  Persistence/
    ModelContainerFactory.swift
    SeedData.swift
    Repositories/
      AvatarRepository.swift
      WardrobeRepository.swift
  Media/
    MediaStore.swift
  Imaging/
    CameraCapture/
      CameraCaptureView.swift
      GuidedCameraSheet.swift
    PersonSilhouetteGenerator.swift
    ClothingForegroundExtractor.swift
    TryOnComposer.swift
    ImageUtilities.swift
  Features/
    Onboarding/
    Avatar/
    Closet/
    TryOnStudio/
    Lookbook/
  SharedUI/
    Components/
```

Consolidations relative to the original plan:

- `ImageAssetWriter` and `ThumbnailGenerator` folded into `MediaStore`; split them out if the file grows past one clear responsibility.
- `VisionProcessingService`, `AvatarBuilder`, and `ClothingPreprocessor` are deferred: `PersonSilhouetteGenerator` and `ClothingForegroundExtractor` are the Vision boundaries the MVP needs. Introduce the fuller service split when body-adjustment rendering or Phase 1 mask refinement demands it. The contract stands: UI views never call Vision/Core Image APIs directly.
- `Features/Settings/` arrives with slice 8; `SharedUI/DesignTokens/` when a real design pass needs it.

Tests should mirror these boundaries: model tests, media-store tests, pure compositor tests, and focused UI tests for the MVP flows.

## SwiftData Model Draft

Use `UUID` primary identifiers on all models and store enum values as raw strings for migration stability. Do not store full image data inside SwiftData models.

### `AvatarProfile`

Represents the user's current avatar and body-adjustment settings.

Suggested fields:

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `displayName: String?`
- `isActive: Bool`
- `sourceImage: ImageAsset?`
- `silhouetteImage: ImageAsset?`
- `previewImage: ImageAsset?`
- `processingStatusRawValue: String`
- `heightCentimeters: Double?`
- `shoulderAdjustment: Double`
- `torsoAdjustment: Double`
- `waistAdjustment: Double`
- `hipAdjustment: Double`
- `legAdjustment: Double`
- `poseConfidence: Double?`
- `bodyLandmarksJSON: Data?`

Notes:

- MVP should support one active avatar, but the model should not prevent adding avatar history later.
- Store body landmark data as encoded app-owned geometry, not as a biometric identifier.
- Body adjustment values are UI controls for visual fit, not health or sizing measurements.

### `ClosetCategory`

Represents manually selectable wardrobe categories.

Suggested fields:

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `kindRawValue: String`
- `name: String`
- `symbolName: String`
- `sortIndex: Int`
- `isSystem: Bool`
- `isArchived: Bool`

Default seeded categories:

- Tops
- Bottoms
- Shoes
- Accessories

Notes:

- Use seeded SwiftData records instead of only a hard-coded enum so the closet grid can query, filter, and sort consistently.
- Keep category `kindRawValue` stable because outfit layering and default placement depend on category semantics.
- Custom categories are not MVP unless explicitly added later.

### `WardrobeItem`

Represents one user-owned clothing item.

Suggested fields:

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `name: String`
- `category: ClosetCategory?`
- `categoryKindRawValue: String`
- `originalImage: ImageAsset?`
- `processedImage: ImageAsset?`
- `thumbnailImage: ImageAsset?`
- `maskImage: ImageAsset?`
- `dominantColorName: String?`
- `notes: String?`
- `sortIndex: Int`
- `isArchived: Bool`

Notes:

- `processedImage` can initially be a normalized/cropped version of the original. It should not imply automated background removal in the MVP.
- `maskImage` is optional and exists to avoid a data migration when Phase 1 segmentation arrives.
- Deleting an item should remove it from new outfit assembly and either prevent deletion while used by saved looks or preserve a read-only snapshot reference for existing looks.

### `OutfitLook`

Represents a saved outfit/look.

Suggested fields:

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `name: String`
- `avatarProfile: AvatarProfile?`
- `slots: [OutfitSlot]`
- `previewImage: ImageAsset?`
- `notes: String?`
- `sortIndex: Int`
- `isArchived: Bool`

Notes:

- MVP lookbook is a gallery of saved looks, not a calendar.
- A saved look should keep enough slot transform data to re-render even if default placement logic changes later.

### `OutfitSlot`

Represents one wardrobe item placed on an avatar within a saved look.

Suggested fields:

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `look: OutfitLook?`
- `wardrobeItem: WardrobeItem?`
- `categoryKindRawValue: String`
- `zIndex: Int`
- `anchorX: Double`
- `anchorY: Double`
- `scale: Double`
- `rotationDegrees: Double`
- `opacity: Double`

Notes:

- Store placement in normalized avatar-canvas coordinates from `0.0...1.0` so previews can render on different screen sizes.
- Default layering should be deterministic: avatar base, bottoms, shoes, tops, accessories.
- Keep this model separate from `WardrobeItem`; placement belongs to a look, not to the item globally.

### `ImageAsset`

Represents a locally stored image or mask file.

Suggested fields:

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `kindRawValue: String`
- `relativePath: String`
- `contentType: String`
- `pixelWidth: Int`
- `pixelHeight: Int`
- `byteCount: Int64`
- `sourceRawValue: String`
- `sha256: String?`
- `isRegenerable: Bool`

Recommended image kinds:

- `avatarOriginal`
- `avatarSilhouette`
- `avatarPreview`
- `wardrobeOriginal`
- `wardrobeProcessed`
- `wardrobeMask`
- `wardrobeThumbnail`
- `outfitPreview`

Notes:

- Use relative paths so the app container can move between installs, backups, and simulator/device paths.
- `isRegenerable` should be true for thumbnails and previews, false for user-captured originals.
- Do not use filenames that include user-entered item names or body-related descriptors.

## Local Image Storage Strategy

SwiftData should store only metadata and relationships. `MediaStore` owns file writes, reads, deletes, and thumbnail generation.

### Directory Layout

Use Application Support for durable user-created media and Caches for files that can be regenerated.

```text
Application Support/
  Outfitloader/
    Media/
      Avatars/
        {avatarID}/
          original.jpg
          silhouette.png
          preview.png
      Wardrobe/
        {itemID}/
          original.jpg
          processed.png
          mask.png
      Outfits/
        {lookID}/
          preview.jpg

Caches/
  Outfitloader/
    Thumbnails/
      {imageAssetID}.jpg
```

### Format Rules

- Preserve camera/photo imports as HEIC when practical, otherwise JPEG. The current `MediaStore` re-encodes imports to JPEG (quality 0.9) after orientation normalization; HEIC passthrough is a possible later optimization.
- Use PNG for assets that need alpha, such as masks, silhouettes, and transparent processed clothing images.
- Use JPEG for thumbnails and outfit previews unless transparency is required.
- Generate thumbnails at stable sizes for grid performance, such as small grid, large grid, and detail preview variants if profiling shows the need.

### Write And Delete Rules

- Write image files before inserting or updating the SwiftData `ImageAsset`.
- Use atomic writes: write to a temporary file, then move into the final relative path.
- If a SwiftData save fails after a file write, clean up the orphaned file.
- If a file write fails, do not create the SwiftData row.
- Deletion should go through a repository/service that removes both SwiftData rows and media files.
- Use a periodic debug-only orphan scan during development to catch broken media references.

### Privacy And Protection

- Do not upload media or generated derivatives in the MVP.
- Do not log image paths, body measurements, thumbnails, masks, or Vision output.
- Apply iOS file protection to durable media and the SwiftData store where supported.
- Store regenerable thumbnails/previews in Caches or mark them as excluded from backup.
- Before external TestFlight, decide whether durable originals should participate in standard encrypted device backup or be excluded for stricter on-device semantics. Do not implement CloudKit sync in the MVP.

## SwiftUI Navigation Structure

The app has two modes: first-run onboarding and the main authenticated-by-local-state app shell. There are no accounts in the MVP.

### App Root

`AppRootView` decides which flow to show:

- If no active `AvatarProfile` exists: show onboarding/avatar creation.
- If an active avatar exists: show the main app shell.

This check should come from SwiftData, not user defaults. User defaults may cache lightweight UI preferences only.

### Compact iPhone

Use a tab-based shell:

- `Try On`: avatar canvas, current outfit state, item picker, save look action.
- `Closet`: category filters, visual grid, add/import, item detail/edit.
- `Lookbook`: saved outfit grid, look detail, reopen in Try On.
- `Avatar`: avatar preview, basic body adjustments, reset/recreate avatar, settings link.

Guidelines:

- Keep the primary action visible in each tab.
- Put destructive and secondary actions in menus or confirmation sheets.
- Use sheets for add/edit flows and full-screen cover only for guided camera capture or onboarding.

### iPad And Wide Widths

Use `NavigationSplitView`:

- Sidebar: Try On, Closet, Lookbook, Avatar.
- Content: selected feature grid/canvas.
- Detail or inspector column when useful:
  - Closet item detail.
  - Look detail.
  - Try-on selected item transform controls.

Guidelines:

- Closet should use denser grids at wider widths.
- Try On should keep the avatar canvas central with wardrobe selection in a side rail or inspector.
- Avoid designing only for portrait phone dimensions; normalized canvas coordinates should adapt across sizes.

### State Ownership

- Use SwiftData `@Query` for lists and detail reads.
- Use `@Observable` route/state objects for transient UI state such as selected tab, selected category, active item, and unsaved outfit composition.
- Keep unsaved try-on composition out of SwiftData until the user saves a look.
- Save operations should be explicit: create/update `OutfitLook`, `OutfitSlot`, and preview `ImageAsset` together.

## Avatar And Compositing Pipeline Boundaries

The image pipeline should be split into small services. UI views call orchestration methods, not Vision/Core Image APIs directly.

### Pipeline Overview

```text
Camera / PhotosUI
  -> MediaStore
  -> VisionProcessingService
  -> AvatarBuilder or ClothingPreprocessor
  -> SwiftData metadata update
  -> TryOnComposer
  -> MediaStore preview write
```

### `MediaStore`

Responsibilities:

- Import camera or PhotosUI image data.
- Normalize orientation.
- Write durable originals and regenerable derivatives.
- Generate thumbnails.
- Return `ImageAssetDraft` metadata for SwiftData insertion.

Non-responsibilities:

- Does not decide avatar geometry.
- Does not mutate SwiftData directly unless wrapped by a repository that owns the transaction.

### `VisionProcessingService`

Responsibilities:

- Run native Vision requests for person segmentation, body pose landmarks, and confidence values where feasible.
- Return plain value types such as masks, landmarks, bounding boxes, and confidence.

Non-responsibilities:

- Does not save files.
- Does not know about SwiftData models.
- Does not make product decisions such as accepting/rejecting an avatar photo.

### `AvatarBuilder`

Responsibilities:

- Convert the original selfie plus Vision outputs into an `AvatarRenderDescriptor`.
- Produce silhouette/preview images for the MVP.
- Apply user body-adjustment values to the render descriptor.
- Report whether the photo quality is usable enough for the MVP.

Non-responsibilities:

- Does not implement clothing placement.
- Does not infer health, body composition, identity, gender, age, or sensitive traits.

### `ClothingPreprocessor`

Responsibilities:

- Normalize imported clothing photos.
- Generate thumbnails and a processed image suitable for try-on composition.
- Preserve optional mask hooks for later segmentation work.
- Coordinate with `ClothingForegroundExtractor` when the product scope includes native background removal.

MVP boundary:

- Automated background removal is not required for v1.
- Phase 1 can replace or enhance this service with segmentation without changing `WardrobeItem`, `ImageAsset`, or try-on UI contracts.

Spike update:

- Physical validation showed that rectangular clothing photos undermine the try-on composite.
- `VNGenerateForegroundInstanceMaskRequest` is available in the target platform range and has been added to the spike as a native foreground-object extraction path.
- Device validation was good enough to move lightweight native clothing foreground extraction into MVP scope through `/spec-update`.

### `TryOnComposer`

Responsibilities:

- Render the avatar and selected outfit slots into a preview image.
- Apply deterministic category layering and normalized transforms.
- Support fast in-memory previews while the user edits a composition.
- Generate saved look previews when the user saves.

Inputs:

- `AvatarRenderDescriptor`
- `[OutfitLayer]`, each with image asset, category kind, normalized transform, opacity, and z-index
- Target output size and scale

Output:

- In-memory `CGImage` / `UIImage` / SwiftUI `Image` for live preview.
- Optional rendered data passed to `MediaStore` for saved look previews.

Non-responsibilities:

- Does not query SwiftData.
- Does not perform camera capture.
- Does not know how images are stored on disk.

## MVP Implementation Slices

1. [x] App shell, SwiftData container, seeded default categories, and placeholder main navigation.
2. [x] MediaStore with import/write/read/delete and thumbnail generation.
3. [x] Closet CRUD using manual category selection and local images. Replace-photo on existing items still to come.
4. [x] Avatar onboarding with guided capture/import and basic generated silhouette/preview. Body-shape adjustment controls still to come (fields exist on `AvatarProfile`, no UI yet).
5. [x] Try-on studio with tap-to-select or drag/drop item assembly and deterministic layering.
6. [ ] Save look flow that creates `OutfitLook`, `OutfitSlot`, and preview image.
7. [ ] Lookbook gallery and look detail/reopen flow.
8. [ ] Privacy/settings affordances, including local data deletion.
9. [ ] Device testing and TestFlight readiness pass.

## Open Technical Questions

- Can native Vision produce a good enough person mask from typical full-body selfies? **Answered in the spike:** good enough to proceed; silhouette edges are rough and may need Phase 1 refinement. Body-landmark quality remains unvalidated.
- What minimum manual adjustment controls are needed for users to feel the avatar represents their proportions? **Open.** `AvatarProfile` stores adjustment fields, but no adjustment UI exists yet.
- Is tap-to-select enough for first TestFlight, or does drag/drop materially improve the try-on experience? **Both implemented** (tap-to-place from the shelf, drag-to-position on the canvas); validate the feel on device.
- Should the MVP preserve deleted wardrobe items in existing looks as snapshots, or block deletion while an item is used by a saved look? **Open — must be decided in slices 6-7.** Items currently delete freely because no saved looks exist yet.
- Should durable original media be excluded from standard iCloud device backup for stricter local-only privacy, or included for user restore safety? **Open — decide before external TestFlight.**
