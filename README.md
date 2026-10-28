# Reef

**A calm widget that lives at the top of your Mac's screen.**

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![tests](https://img.shields.io/badge/tests-62%20passing-brightgreen)

Reef sits quietly along the top edge of the screen. On a MacBook with a notch
it wraps around the notch; on any other Mac it shows a small rounded pill just
under the menu bar. It stays out of the way until there is something worth
showing, like what is playing or how your devices are doing, and then it opens
just enough to show it.

This is early. The overlay, its glass materials, the battery live activities,
and the settings window are in place; the rest of the glanceable content is being
built out release by release. See the roadmap below for where it is headed.

## Look and feel

Reef is black where it meets the notch and glass where it grows past it. Pick
the material in Settings, Appearance:

- **Liquid Glass**: the system glass on macOS 26, tinted dark so text stays
  readable on any wallpaper. Earlier systems use Frosted.
- **Frosted**: a blurred view of the desktop with a soft rim of light.
- **Midnight**: solid black, like the iPhone Dynamic Island.

It can hug the top edge and flow out of the notch (Attached) or sit just below
it as its own bubble (Floating), in one of six accent colors and three motion
styles. Reduce Transparency, Increase Contrast, and Reduce Motion are honored
throughout. The full design reference is in [docs/DESIGN.md](docs/DESIGN.md).

## Why another one of these

Most notch widgets grow into a kitchen sink of panels and settings. Reef is an
attempt to keep the idea small and quiet: a thing you forget is there until the
moment it is useful, that never grabs focus, and that reads cleanly on both a
bright and a dark desktop.

## How it behaves

- It floats above other windows at the status bar level and never takes keyboard
  focus, so it does not interrupt what you are doing.
- It shows on every Space and stays put when you switch between them.
- It follows the screen your pointer is on and repositions itself when you plug
  in or unplug a display, or close the lid.
- It runs as a menu bar item with no Dock icon and no main window. Settings open
  from the menu bar item.

## Build from source

You need Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
brew install xcodegen
git clone https://github.com/sadiqkhzn/Reef.git
cd Reef
xcodegen generate
open Reef.xcodeproj
```

Build and run the `Reef` scheme. The project file is generated from
`project.yml`, so edit that rather than the `.xcodeproj`.

To run the tests from the command line:

```
xcodebuild -project Reef.xcodeproj -scheme Reef -destination 'platform=macOS' test
```

## Principles

- **Quiet by default.** It earns attention, it does not demand it.
- **Local only.** No accounts, no telemetry, no network calls of its own.
- **Yours to shape.** Everything it shows should be something you chose to see.

## Roadmap

- [x] v0.1 groundwork: floating overlay, notch and non-notch placement, multi-screen handling.
- [ ] Now Playing: track, artwork, and transport controls.
- [x] Hover to open, with a smooth expand and collapse.
- [x] Glass island design system: materials, accents, and motion presets.
- [x] Battery live activities: charging, fully charged, and low battery.
- [x] Device live activity when AirPods and other Bluetooth devices connect, with a quick peek.
- [x] A settings window with appearance and live activity controls.
- [ ] Nearby device status (AirPods and other Bluetooth devices).
- [ ] A notarized `.dmg` once a signing certificate is in place.

## License

MIT. See [LICENSE](LICENSE).
