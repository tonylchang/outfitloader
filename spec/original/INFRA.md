# Infrastructure

## Deployment Target

- Native iOS/iPadOS app distributed to testers through TestFlight for v1.
- No custom backend, serverless functions, VPS, or hosted API infrastructure for the MVP.

## CI/CD

- Manual TestFlight uploads from Xcode / App Store Connect.
- No automated CI/CD requirement for the initial release.
- Automated builds may be considered later if the project gains collaborators or frequent release needs.

## Database Hosting

- User wardrobe, avatar, outfit, and schedule data stays on-device for v1.
- No hosted database for the MVP.
- iCloud / CloudKit sync is not part of the initial infrastructure plan unless explicitly added later.

## Domain & DNS

- No domain, DNS, marketing site, or web infrastructure requirement for v1.

## Monitoring & Observability

- Use normal Apple platform logging and crash reporting appropriate for TestFlight builds.
- No product analytics or behavioral tracking.
- Logging must avoid storing sensitive body, wardrobe, photo, or biometric-adjacent data.
