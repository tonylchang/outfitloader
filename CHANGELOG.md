# Changelog

## Unreleased

### Added

- Layered Liquid Glass app icon (`AppIcon.icon`) with the brand gradient fill and vector ring, alongside the flat icon fallbacks.
- Debug-only orphan media scan at launch that reports SwiftData rows with missing files and unreferenced files on disk, as counts only.
- Empty states now lead to the action that fills them: Lookbook links to Try On, the Try On shelf links to the Closet, and a filtered-empty Closet offers Add Item and Show All.
- VoiceOver custom actions on the try-on canvas: move a placed item up/down/left/right in 5% steps, remove it, and hear its position; the avatar and layers now expose button and selected-state traits.
- Test coverage for MediaStore file IO, TryOnComposer rendering (including opacity blending and z-order), WardrobeRepository create/replace/delete transactions, and the clothing-extraction fallback contract.

### Changed

- Promoted `MediaStore` to an actor-backed async service; repositories and views now await media IO, and image encoding runs off the main thread.
- Repository delete flows save SwiftData before removing files, so a failed save can no longer leave rows pointing at missing media.
- The camera capture overlay's framing hint becomes fully opaque when Reduce Transparency is enabled.
- Imported originals are stored as HEIC when the device can encode it (smaller files), falling back to JPEG; generated derivatives keep their formats.
- The closet grid shows more, smaller cells on iPad and wide layouts, and cells scale with column width instead of using a fixed image height.
- Camera capture guidance now includes lighting and background-contrast tips in both the copy and the in-camera overlay.
- If even the in-memory fallback data store cannot be created at launch, the app shows an error screen with recovery steps instead of terminating.

### Fixed

- Closet, shelf, and look-detail images recover when iOS purges cached thumbnails under storage pressure: the thumbnail is regenerated in place from the durable original instead of showing a placeholder forever.
- Saved-look previews always render on a white background. They previously baked in whichever light/dark appearance was active at save time, leaving the lookbook grid a mix of light and dark cards.
- Lookbook previews refresh on screen after a wardrobe item's photo is replaced. The preview file is rewritten at the same path, which never retriggered the image loader; it now also keys off the asset's update time.
- Saved-look previews now honor avatar and clothing opacity. The composer previously set opacity through the graphics context, which `UIImage.draw(in:)` ignores, so previews always rendered layers fully opaque.

## 0.1.0 - 2026-07-03

Milestone 1: the TestFlight-able MVP. First build uploaded to TestFlight.

### Added

- Native SwiftUI app shell for iPhone and iPad.
- SwiftData local persistence with seeded closet categories.
- Local media storage for avatar, wardrobe, thumbnail, and outfit preview images.
- Guided avatar capture/import with on-device Vision silhouette generation.
- Avatar body-shape controls for visual outfit-preview proportions.
- Closet capture/import with native foreground extraction and manual categories.
- Wardrobe item edit, delete, and replace-photo flows.
- Try-on studio with tap-to-place, drag positioning, deterministic layering, and transform controls.
- Saved looks with generated previews.
- Lookbook grid, look detail, delete, and reopen-in-Try-On flow.
- Settings screen with local-only privacy summary and local data deletion.
- Swift Testing, XCTest, and XCUITest targets with initial coverage for avatar rendering, saved-look persistence, delete blocking, and app launch.
- App icon asset catalog with light, dark, and tinted appearances, plus a brand purple accent color.
- Privacy policy draft in `docs/privacy.html`.
- App Store Connect preparation notes for the first TestFlight upload.
- TestFlight readiness checklist for physical-device validation.

### Changed

- Changed the bundle identifier to `net.1x0.outfitloader` ahead of the first App Store Connect record.
- Removed unpopulated avatar pose/preview and wardrobe mask schema fields before the first tagged release.
- Consolidated wardrobe add/replace photo acquisition and foreground extraction state into a shared view model.
- Serialized local media file IO through a single `MediaStore` queue.

### Notes

- All user photos, avatar data, wardrobe data, body-shape adjustments, and saved looks stay on device for v1.
- No backend, sync, product analytics, or third-party AI services are included.
- User data participates in standard user-controlled encrypted device backups; the privacy policy states this explicitly.
- The full physical-device TestFlight readiness checklist has been completed.
- Build 1 was archived and uploaded to App Store Connect / TestFlight on 2026-07-03.
