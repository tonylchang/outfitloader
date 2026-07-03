# TestFlight Readiness Checklist

Run this pass on a physical iPhone before uploading the first Milestone 1 build to TestFlight.

Status: completed 2026-07-03 on a physical iPhone, except the final archive/upload.

## Build

- [x] Confirm the app builds for an iOS device target in Xcode.
- [x] Confirm the app launches from a clean install.
- [x] Confirm version/build numbers are set for the intended TestFlight upload.

## Core Flow

- [x] Create an avatar from camera capture and confirm camera permission copy appears.
- [x] Create an avatar from photo import.
- [x] Adjust avatar body-shape controls and confirm the Avatar and Try On previews update.
- [x] Add clothing from camera capture.
- [x] Add clothing from photo import.
- [x] Confirm native clothing foreground extraction creates transparent overlays when the photo supports it.
- [x] Replace a wardrobe item photo from camera or import.
- [x] Assemble an outfit in Try On.
- [x] Save a look.
- [x] Open the look in Lookbook.
- [x] Reopen the look in Try On.

## Data And Privacy

- [x] Confirm deleting a wardrobe item used by a saved look is blocked with the saved-look count.
- [x] Confirm deleting a saved look does not delete closet items.
- [x] Confirm Settings shows local-only privacy statements.
- [x] Confirm Delete All Local Data removes avatar, wardrobe, looks, and generated media, then returns to avatar setup.
- [x] Confirm no sensitive photos, generated avatars, body adjustments, or wardrobe details are written to logs.

## Accessibility And Layout

- [x] Check light and dark mode.
- [x] Check larger Dynamic Type.
- [x] Check VoiceOver labels for primary actions: capture, import, save look, reopen look, replace photo, delete data.
- [x] Check iPhone portrait and landscape.
- [x] Check iPad or a wide/resizable layout if available.

## Release Materials

- [x] Review `docs/APP_STORE_CONNECT_PREP.md`.
- [x] Review and publish `docs/privacy.html` as the privacy policy URL before external TestFlight.
- [x] Prepare App Store Connect privacy answers matching the no-backend, no-analytics, on-device data model.
- [ ] Archive and upload manually from Xcode/App Store Connect.
