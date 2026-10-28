# Contributing

Thanks for your interest in Reef.

## Scope

Reef is a small widget that lives at the top of the screen and surfaces things
you already care about: what is playing, battery and device status, quick
glances at system state. Anything that keeps it calm, fast, and out of the way
is in scope. Features that fight for attention or add noise are not.

## Development

1. Install XcodeGen: `brew install xcodegen`.
2. Generate the project: `xcodegen generate`.
3. Open `Reef.xcodeproj` in Xcode 15 or later and run on macOS 14 or later.

The checked-in source of truth is `project.yml`. Edit that, not the generated
`.xcodeproj`, then run `xcodegen generate` again.

## Pull requests

- Keep each pull request focused on one concern.
- Prefix the title with `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, or `ci:`.
- Explain what changed and why in the body.
- Add tests for logic that can be tested without the UI.

## Tests

Logic that does not need a window should have unit tests. Run them in Xcode
with Cmd+U, or from the command line:

```
xcodebuild -project Reef.xcodeproj -scheme Reef \
  -destination 'platform=macOS' test
```
