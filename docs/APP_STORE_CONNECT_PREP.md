# App Store Connect Prep

Use this as the working checklist for the first TestFlight upload of outfitloader.

## Build Metadata

- App name: `outfitloader`
- Version: `0.1.0`
- Build number: `1`
- Bundle ID: confirm in Xcode before archive.
- Signing team: confirm in Xcode before archive.
- Platforms: iPhone and iPad.
- Minimum OS: iOS/iPadOS 26.
- Distribution path: manual archive and upload from Xcode to App Store Connect/TestFlight.

The Xcode project should keep:

```text
MARKETING_VERSION = 0.1.0
CURRENT_PROJECT_VERSION = 1
```

## Privacy Policy

- Source file: `docs/privacy.html`
- Public Privacy Policy URL: required before external TestFlight or App Store distribution.
- Privacy Choices URL: optional for v1; not needed while all user data remains local and the app includes in-app local data deletion.

Before entering the URL in App Store Connect, publish `docs/privacy.html` at a publicly accessible HTTPS URL. Keep the hosted page content aligned with the checked-in source.

## App Privacy Answers

Recommended answers for the current MVP, based on the active spec and implementation:

- Tracking: `No`
- Data collection: `No`
- Third-party advertising: `No`
- Developer advertising or marketing: `No`
- Analytics: `No`
- Third-party SDKs: `No`
- Backend/server data storage: `No`

Reasoning:

- Avatar photos, clothing photos, generated silhouettes, clothing cutouts, body-shape adjustment values, saved looks, and generated previews are processed and stored on device.
- The app does not operate a backend or hosted database.
- The app does not include product analytics, behavioral tracking, advertising SDKs, data brokers, or third-party AI services.
- Apple says data processed only on device is not considered collected for App Store privacy answers unless it is sent off device.

Recheck these answers before upload if any of the following change:

- Cloud sync, accounts, backup service, or hosted storage is added.
- External AI/image processing is added.
- Analytics, crash SDKs, advertising SDKs, attribution SDKs, or social SDKs are added.
- Outfit sharing, public profiles, support forms, or networked feedback are added.

## TestFlight Beta Information

Beta app description:

```text
outfitloader helps you create an on-device avatar from a full-body photo, add real clothing items to a local digital closet, assemble outfits on your avatar, save looks, and reopen them later.
```

What to test:

```text
Please test the full MVP loop:
1. Create or import an avatar photo.
2. Adjust avatar body-shape controls.
3. Add clothing from camera capture or photo import.
4. Confirm clothing foreground extraction looks usable.
5. Assemble an outfit in Try On.
6. Save the look.
7. Open it in Lookbook.
8. Reopen it in Try On.
9. Delete all local data from Settings.
```

Known limitations:

```text
Clothing cutout quality depends on photo background, lighting, shadows, and contrast. For best results, photograph clothing on a plain contrasting surface. The app is local-only in this build; there are no accounts, cloud sync, sharing, outfit scheduling, recommendations, or analytics.
```

Test account:

```text
No account is required.
```

Reviewer notes:

```text
Camera access is used only when the tester chooses to capture an avatar or clothing photo. Photo import uses the system picker. All avatar, wardrobe, and saved-look data stays on device for this MVP.
```

## Upload Checklist

- [ ] Confirm the working tree is clean.
- [ ] Confirm `MARKETING_VERSION` is `0.1.0`.
- [ ] Confirm `CURRENT_PROJECT_VERSION` is the intended upload build number.
- [ ] Confirm camera and photo permission strings are present.
- [ ] Confirm `docs/privacy.html` is hosted at a public HTTPS URL.
- [ ] Enter the Privacy Policy URL in App Store Connect.
- [ ] Enter app privacy answers matching this document.
- [ ] Archive from Xcode.
- [ ] Upload the archive to App Store Connect.
- [ ] Add internal testers first.
- [ ] Install the TestFlight build on a physical device.
- [ ] Run the checklist in `docs/TESTFLIGHT_READINESS_CHECKLIST.md`.

## Sources

- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
