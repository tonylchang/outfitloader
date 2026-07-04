# Changelog

## Unreleased

### Added

- Layered Liquid Glass app icon (`AppIcon.icon`) with the brand gradient fill and vector ring, alongside the flat icon fallbacks.
- VoiceOver custom actions on the try-on canvas: move a placed item up/down/left/right in 5% steps, remove it, and hear its position; the avatar and layers now expose button and selected-state traits.
- Test coverage for MediaStore file IO, TryOnComposer rendering (including opacity blending and z-order), WardrobeRepository create/replace/delete transactions, and the clothing-extraction fallback contract.

### Changed

- Promoted `MediaStore` to an actor-backed async service; repositories and views now await media IO, and image encoding runs off the main thread.
- Repository delete flows save SwiftData before removing files, so a failed save can no longer leave rows pointing at missing media.
- The camera capture overlay's framing hint becomes fully opaque when Reduce Transparency is enabled.

### Fixed

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
