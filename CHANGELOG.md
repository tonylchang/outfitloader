# Changelog

## 0.1.0 - Unreleased

Milestone 1 TestFlight-able MVP work.

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
- Privacy policy draft in `docs/privacy.html`.
- App Store Connect preparation notes for the first TestFlight upload.
- TestFlight readiness checklist for physical-device validation.

### Changed

- Removed unpopulated avatar pose/preview and wardrobe mask schema fields before the first tagged release.
- Consolidated wardrobe add/replace photo acquisition and foreground extraction state into a shared view model.
- Serialized local media file IO through a single `MediaStore` queue.

### Notes

- All user photos, avatar data, wardrobe data, body-shape adjustments, and saved looks stay on device for v1.
- No backend, sync, product analytics, or third-party AI services are included.
- An initial physical-device run has been completed.
- App Store Connect privacy answers, build numbering, archive, and manual upload remain before external TestFlight.
