# Reef

**A calm widget that lives at the top of your Mac's screen.**

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![tests](https://img.shields.io/badge/tests-160%20passing-brightgreen)

Reef sits quietly along the top edge of the screen. On a MacBook with a notch
it wraps around the notch; on any other Mac it shows a small rounded pill just
under the menu bar. It stays out of the way until there is something worth
showing, like what is playing, your next event, or how your devices are doing,
and then it opens just enough to show it.

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
throughout.

## What it shows

- **Now Playing** from any app or browser: cover art and a cover-tinted
  equalizer on the resting island, and an open player with a scrolling title, a
  live seek bar, shuffle and repeat, and the full transport. Pick which player
  to follow, hide it while its app is frontmost, and tap the source to jump to
  the app.
- **Calendar**: your next event on the island, a heads-up before it starts, an
  agenda of the coming days, and a per-calendar choice of what shows.
- **Weather** for where you are, from a free service, on the open home page.
- **Battery and power**: charging, fully charged, and low-battery activities
  with an adjustable warning level, plus a Low Power Mode heads-up.
- **Bluetooth**: AirPods and other device battery on connect, and a disconnect
  activity, drawn with Reef's own 3D earbud and headphone models or with SF
  Symbols, your choice. **Audio output** changes to wired, USB, HDMI, or AirPlay show too.
- **A shelf** to stash files on the notch and drag them back out later.

## How you reach it

- **Swipe** the island to skip tracks and to open or close it, or hover and
  click. The open island flips between the player, a home page, the shelf, and
  the agenda.
- Choose **where it lives**: follow the pointer across screens, the built-in
  display, or the main screen. On a Mac without a notch it can draw a simulated
  one.
- Tune **how it opens** (hover or click, with a dwell), the quick peek, haptics,
  a contrast outline, and whether it hides from screen capture.

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
- **Local first.** No accounts and no telemetry. The one thing that leaves the
  Mac is the weather lookup: when you turn weather on, a coarse location,
  rounded to about a kilometer, is sent to Open-Meteo to fetch the forecast, and
  nothing else.
- **Yours to shape.** Everything it shows should be something you chose to see.

## Roadmap

- [x] Floating overlay, notch and non-notch placement, multi-screen handling.
- [x] Hover or click to open, with a smooth expand and collapse.
- [x] Glass island design system: materials, accents, and motion presets.
- [x] Battery and power activities, with an adjustable low-battery level.
- [x] Bluetooth device battery and connect activity, and audio output changes.
- [x] System-wide Now Playing: resting equalizer and a full open player.
- [x] Calendar: next event, heads-up, agenda, and per-calendar filtering.
- [x] Local weather on the home page.
- [x] A file shelf, swipe gestures, and an onboarding and permissions screen.
- [x] A settings window covering appearance, behavior, and activities.
- [ ] A notarized `.dmg` once a signing certificate is in place.
- [ ] In-app updates.

## License

MIT. See [LICENSE](LICENSE).
