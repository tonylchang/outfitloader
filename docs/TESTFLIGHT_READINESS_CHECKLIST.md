# TestFlight Readiness Checklist

Run this pass on a physical iPhone before uploading the first Milestone 1 build to TestFlight.

## Build

- [ ] Confirm the app builds for an iOS device target in Xcode.
- [ ] Confirm the app launches from a clean install.
- [ ] Confirm version/build numbers are set for the intended TestFlight upload.

## Core Flow

- [ ] Create an avatar from camera capture and confirm camera permission copy appears.
- [ ] Create an avatar from photo import.
- [ ] Adjust avatar body-shape controls and confirm the Avatar and Try On previews update.
- [ ] Add clothing from camera capture.
- [ ] Add clothing from photo import.
- [ ] Confirm native clothing foreground extraction creates transparent overlays when the photo supports it.
- [ ] Replace a wardrobe item photo from camera or import.
- [ ] Assemble an outfit in Try On.
- [ ] Save a look.
- [ ] Open the look in Lookbook.
- [ ] Reopen the look in Try On.

## Data And Privacy

- [ ] Confirm deleting a wardrobe item used by a saved look is blocked with the saved-look count.
- [ ] Confirm deleting a saved look does not delete closet items.
- [ ] Confirm Settings shows local-only privacy statements.
- [ ] Confirm Delete All Local Data removes avatar, wardrobe, looks, and generated media, then returns to avatar setup.
- [ ] Confirm no sensitive photos, generated avatars, body adjustments, or wardrobe details are written to logs.

## Accessibility And Layout

- [ ] Check light and dark mode.
- [ ] Check larger Dynamic Type.
- [ ] Check VoiceOver labels for primary actions: capture, import, save look, reopen look, replace photo, delete data.
- [ ] Check iPhone portrait and landscape.
- [ ] Check iPad or a wide/resizable layout if available.

## Release Materials

- [ ] Review `docs/APP_STORE_CONNECT_PREP.md`.
- [ ] Review and publish `docs/privacy.html` as the privacy policy URL before external TestFlight.
- [ ] Prepare App Store Connect privacy answers matching the no-backend, no-analytics, on-device data model.
- [ ] Archive and upload manually from Xcode/App Store Connect.
