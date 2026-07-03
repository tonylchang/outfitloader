# Versioning

## Scheme

- Use Semantic Versioning in the form `MAJOR.MINOR.PATCH`.
- Early development versions may use `0.x.y`, starting with `0.1.0` when there is a meaningful build to identify.

## Release Cadence

- No formal releases yet.
- Cut releases only when there is a meaningful milestone build, especially a TestFlight-ready MVP.
- Internal build numbers may advance independently through Xcode/App Store Connect.

## Tagging

- Use Git tags for versioned releases.
- Tag format: `vMAJOR.MINOR.PATCH`, such as `v0.1.0`.
- Do not tag every experimental local build.

## Pre-release Labels

- Do not use pre-release labels for now.
- If needed later, update this spec before adopting labels such as `alpha`, `beta`, or `rc`.

## Changelog

- Maintain a `CHANGELOG.md`.
- Changelog entries should summarize user-facing changes, meaningful technical changes, fixes, and known limitations for each tagged version.
