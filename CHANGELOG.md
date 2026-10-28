# Changelog

All notable changes to Reef are recorded here.

## Unreleased

### Added

- Project scaffolding: XcodeGen spec, app target, and unit test target.
- Floating overlay that sits at the top center of the screen. It hugs the
  notch on Macs that have one and shows a rounded pill on Macs that do not.
- The overlay uses a non-activating panel that floats above other apps,
  joins every Space, and never steals keyboard focus.
- Multi-screen handling: the overlay moves to the active screen and
  repositions when the screen layout changes.
- Pure geometry helpers for notch detection and frame placement, with unit
  tests.
