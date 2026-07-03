# Stack

## In Scope

### Languages

- Swift for all app code.

### Frameworks

- SwiftUI for the iOS user interface.
- Observation for SwiftUI state and data flow.
- SwiftData for local structured persistence, including wardrobe items, saved outfits, categories, and future scheduling metadata when Phase 1 scheduling is implemented.
- PhotosUI / PhotosPicker for privacy-preserving camera-roll import.
- AVFoundation for guided in-app camera capture when the system picker is not enough.
- Vision for human body pose detection, person segmentation, clothing foreground extraction, and other native computer-vision tasks where feasible.
- Core ML for on-device ML model inference if avatar or clothing processing needs model-based behavior.
- Core Image for image cleanup, masking, compositing, filtering, and lightweight image processing.
- UIKit only where required to bridge lower-level platform APIs that SwiftUI does not expose directly.

### Databases

- SwiftData local store for the MVP.
- iCloud / CloudKit sync may be considered later, but is not required for the first usable release unless explicitly added to the spec.

### Build & Tooling

- Xcode as the primary IDE and build system.
- Swift Package Manager only if an external package is explicitly approved.
- Xcode previews for UI development.
- SF Symbols for system-native iconography.
- TestFlight for beta distribution.

### Testing

- Swift Testing for unit and model-layer tests where supported by the selected Xcode/iOS target.
- XCTest and XCUITest for UI tests, integration tests, and compatibility with Xcode tooling.
- Manual device testing for camera, photo import, avatar creation, drag/drop or tap-to-select outfit assembly, and visual compositing quality.

## Out of Scope

- Android technologies for the initial product.
- Cross-platform UI frameworks such as React Native, Flutter, Ionic, or Kotlin Multiplatform for the MVP.
- Third-party SDKs, external APIs, hosted AI services, or non-Apple dependencies unless the user approves them after a concrete tradeoff discussion.
- Backend databases or custom server infrastructure for the MVP unless sync, accounts, or sharing are explicitly added later.

## Rationale

- This is a fresh native iOS project, so the default approach should be Apple platform frameworks before third-party dependencies.
- SwiftUI is the required UI framework and should drive navigation, screens, controls, animation, and interaction patterns.
- SwiftData is the preferred local persistence layer because the app needs structured, user-owned records for wardrobe items, outfits, categories, and schedules.
- PhotosUI should be preferred for camera-roll import because it lets users intentionally select assets without granting broad photo-library access.
- AVFoundation is appropriate for guided full-body selfie and clothing capture flows that need custom framing, overlays, lighting guidance, or camera control.
- Vision, Core ML, and Core Image are the preferred first choices for avatar, clothing foreground extraction, body-proportion, and image-compositing work because they keep sensitive body and wardrobe imagery on-device where feasible.
- The initial technical spike validated native Apple frameworks as good enough to continue for avatar person segmentation and lightweight clothing foreground extraction. If later quality requirements exceed native capabilities, propose specific external dependencies or services and get approval before adopting them.
