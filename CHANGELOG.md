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
- A design system in `Reef/Design/`: spacing, radius, type, ink, and status
  tokens; accent colors; and three motion presets (Smooth, Snappy, Bouncy)
  that fall back to short fades with Reduce Motion.
- Glass island materials: Midnight (solid black), Frosted (blurred desktop with
  a specular rim), and Liquid Glass on macOS 26, which falls back to Frosted on
  earlier systems. Reduce Transparency draws solid and Increase Contrast draws
  a clear edge. On notched displays a solid band keeps the cutout hidden while
  the glass shows below it.
- The attached shape now flares out of the top edge with concave shoulders,
  like the hardware notch.
- Live activities: the resting island spreads wings around the notch when
  power is connected, when the battery is full, and when it drops to 20% and
  again at 10%. Activities are ranked so the most important one shows.
- A redesigned open island: a header row beside the notch, a time card, and a
  battery card with a ring gauge and charging status. Content resolves in with
  a blur rather than a plain fade.
- A settings window with a searchable, grouped sidebar: General (island style,
  open at login), Appearance (live preview, material, accent, motion), Live
  Activities (toggles and previews), and About. Choices persist across
  launches.
- `docs/DESIGN.md`, the design reference for every planned surface.
- CI also builds with the macOS 26 SDK so the Liquid Glass path is compiled.
- Quick peek: every live activity shows a line of detail under the wings for
  its first two seconds, such as "Charging · 64%".
- Device activity: when AirPods, headphones, a keyboard, a mouse, or another
  Bluetooth device connects, the wings show the device's symbol, with a toggle
  and a preview in Settings, Live Activities.
- The resting island dips slightly when pressed, so a click feels physical.
- Device models: Reef's own 3D earbuds, earbuds in their charging case, and
  over-ear headphones, in glossy white, stainless steel, anodized aluminum,
  and knit mesh with no logos. They are modeled as smooth distance fields and
  built with Blender by `tools/models`, ship as USDZ (about 1.2 MB for all
  three), and are drawn with SceneKit. They appear in the device wing and turn slowly in the onboarding
  device tiles. A new Device icons choice in Settings, Live Activities picks
  3D models or SF Symbols; devices without a model, and any model that fails
  to load, fall back to the symbol. The models are original and covered by
  the project's license.
