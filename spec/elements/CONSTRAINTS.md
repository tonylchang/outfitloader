# Constraints

## Budget

- No fixed budget limit.
- Avoid unnecessary spend, recurring services, hosted infrastructure, and paid third-party tools unless they clearly improve the product and are approved first.
- Prefer Apple platform capabilities and local processing before paid APIs or external services.

## Timeline

- No fixed deadline.
- Prioritize technical validation of avatar generation, clothing capture, and outfit compositing before broad feature expansion.

## Team

- Solo developer project.
- Keep architecture, tooling, release process, and operational overhead appropriate for one person.

## Licensing

- Undecided.
- Treat the project as private/proprietary until a license decision is made.
- Do not add third-party code, models, images, or assets unless their license is reviewed and compatible with the eventual project direction.

## Compliance

- Follow Apple App Review Guidelines, including for TestFlight beta distribution.
- Provide an accurate privacy policy before external TestFlight or App Store distribution.
- Keep App Store privacy details accurate and update them if data practices change.
- Use data minimization: request only the camera/photo access needed for the current task, and prefer out-of-process pickers where practical.
- Keep avatar photos, wardrobe photos, segmentation masks, body-shape adjustments, outfits, and schedules on-device for v1.
- Do not use body, face, depth, camera, or photo-derived data for advertising, marketing, profiling, or use-based data mining.
- Do not share user photos, body data, wardrobe data, or derived avatar data with third-party AI services without a spec update, explicit user consent, and a privacy review.
- Do not include product analytics or behavioral tracking.
- Logging and crash reporting must not include sensitive photos, generated avatars, body measurements, wardrobe images, or personally identifying closet data.
- Avoid biometric-identification claims or behavior. The avatar should represent the user for outfit visualization, not identify, authenticate, score, classify, or infer sensitive traits about them.
- Avoid health, fitness, body-composition, medical, or sizing-accuracy claims unless the product scope and legal review change.
- Do not target the Kids Category for v1. If the app later targets children or collects data from minors, add a dedicated children privacy review before implementation.
- Include a clear way for users to delete local avatar, wardrobe, and outfit data from within the app.
