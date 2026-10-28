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

## Branches

Name each branch after the change it carries, in lowercase words joined by
hyphens, for example `glass-island-design-system` or `media-live-activity`.
Leave tool and author names out of branch names.

## Pull requests

- Keep each pull request focused on one concern.
- Prefix the title with `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, or `ci:`.
- Explain what changed and why in the body.
- Add tests for logic that can be tested without the UI.
- New UI follows the design language in [docs/DESIGN.md](docs/DESIGN.md): use the
  tokens in `Reef/Design/` rather than inline colors, sizes, or springs.

## Tests

Logic that does not need a window should have unit tests. Run them in Xcode
with Cmd+U, or from the command line:

```
xcodebuild -project Reef.xcodeproj -scheme Reef \
  -destination 'platform=macOS' test
```
