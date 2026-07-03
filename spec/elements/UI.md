# UI

## Interface Type

Native iOS and iPadOS app built with SwiftUI.

## Target Platforms

- iPhone and iPad.
- Minimum target: iOS 26 / iPadOS 26.
- Forward-compatibility target: iOS 27 / iPadOS 27 as SDKs and platform behavior become available.
- Layouts must work across compact iPhone, large iPhone, rotated/resized app windows, iPhone Mirroring, and iPad widths.

## Framework

- SwiftUI is the default UI framework.
- Use system navigation, tab bars, sidebars, split views, sheets, menus, toolbars, gestures, and materials before custom components.
- Bridge to UIKit only when required for lower-level camera, image, drag/drop, or platform behavior not exposed cleanly in SwiftUI.

## Design Preferences

- Follow current iOS design patterns rather than fixed portrait-only app layouts.
- Use restrained Liquid Glass and system materials for navigation, floating controls, cards, and key overlays.
- Avoid placing long text, dense information, or critical state on busy translucent backgrounds.
- Use adaptive navigation: bottom tabs on compact iPhone, sidebars or split views at wider widths, and overflow menus for secondary actions.
- Keep primary actions visible and reachable in the current context.
- Use calm, data-rich hierarchy for closet, lookbook, and planning screens: clear grids, progressive detail, useful empty states, and subtle motion that explains changes.
- Use contextual AI actions and suggestions inside normal flows rather than a separate chatbot-first interface.
- Use consistent SF Symbols and invest in a polished layered app icon with light, dark, tinted, and clear appearances.
- Avoid custom glassmorphism everywhere, tiny low-contrast text, fixed screen assumptions, and bolted-on chatbot UI.

## Accessibility

- Support normal iOS accessibility basics as first-class requirements.
- Support Dynamic Type, VoiceOver, high contrast, dark mode, Reduce Transparency, and Reduce Motion.
- Preserve legibility when using system materials, translucency, gradients, charts, custom iconography, and image-heavy wardrobe grids.
- Ensure interactive controls have adequate hit targets, labels, focus order, and non-color-only state indicators.
