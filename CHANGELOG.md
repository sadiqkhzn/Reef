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
- Hover to open: resting against the notch and moving the pointer over it opens
  the overlay with a spring, and moving away closes it. A short settle time
  keeps a passing pointer from opening it by accident.
- An idle panel in the open state showing the time, the date, and a live
  battery badge that tracks charge, charging, and wall power. The reading
  updates the moment power is plugged in or out and refreshes on a slow timer
  while on battery. Desktop Macs with no battery simply omit the badge.
- Battery parsing is a pure function with unit tests covering scaling,
  rounding, clamping, and missing fields.
