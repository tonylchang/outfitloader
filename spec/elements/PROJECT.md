# Project Plan

## Current Phase

- Fresh project in specification and technical validation.
- Development approach is milestone-based.
- The first milestone should produce a TestFlight-able MVP.

## Milestones

### Milestone 1: TestFlight-able MVP

Definition of done:

- Native iPhone and iPad app builds successfully for the selected iOS/iPadOS targets.
- User can complete guided avatar/selfie capture.
- User can create a basic avatar representation and adjust core body-shape details.
- User can photograph or import clothing items.
- User can categorize, view, edit, and delete closet items.
- User can assemble an outfit on the avatar through drag-and-drop or tap-to-select interactions.
- User can save outfits and view them in a lookbook.
- User data stays on-device.
- Build is stable enough for manual TestFlight upload and external review.

### Phase 1: Polish & Retention

Target window: months 3-6 after MVP.

- Automated clothing segmentation: use a lightweight model or native vision pipeline to remove clothing-photo backgrounds when user feedback shows manual editing friction.
- Outfit scheduling and reminders: assign outfits to dates and show a morning push notification for the planned look.
- Basic wardrobe analytics: show simple stats such as most-worn item, least-worn colors, or cost per wear if users add prices.

### Phase 2: Intelligence & Context

Target window: months 6-12 after MVP.

- Weather and occasion integration: suggest saved outfits based on weather and user-tagged occasions such as work, date night, gym, or casual.
- AI remix and outfit completion: generate new combinations from the user's existing closet or suggest missing pieces that would complete an outfit.
- Profile and avatar sharing: create shareable image cards or links for outfits, such as sending a look to a friend or posting to social platforms.

### Phase 3: Monetization & Business Validation

Target window: months 9-15 after MVP.

- Freemium tier rollout: consider a free tier with limits and a premium tier with unlimited closet/outfit capacity and advanced recommendations.
- Monetization trigger: do not monetize until the MVP has clear manual validation from real users and the product feels useful enough to justify paid limits or premium features.
- Light affiliate or shopping integration: consider a curated feed for missing pieces, starting with a narrow partnership if it fits the product and privacy model.

### Phase 4: Ecosystem & Platform Expansion

Target window: months 15-24 after MVP.

- Apple Watch companion: show the scheduled outfit for the day through a simple watch app or complication.
- iPad and Mac Catalyst optimization: improve larger-screen planning workflows with denser grids and week-planning interfaces.
- Pack for Trip mode: recommend a capsule wardrobe from the user's closet based on destination and trip length.

### Phase 5: Advanced Reality

Target window: year 2 or later.

- Augmented reality preview: explore a 3D or spatial preview of the avatar wearing selected outfits, potentially using LiDAR-capable devices.

## Long-term Plan

- Treat this as a one-off project unless MVP feedback justifies continued investment.
- Later phases are a roadmap for optional expansion, not commitments.
- Avoid adding operational, backend, monetization, or analytics complexity before the TestFlight MVP validates the core avatar and virtual closet experience.
