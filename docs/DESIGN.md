# Reef design language

This document is the design reference for every Reef surface: the island
itself, its live activities, HUDs, panels, lock screen widgets, onboarding,
and the settings window. It covers the full target surface. Each section says
what is already built and what is specified for later, so new work can follow
the same system without re-deciding it.

The code that implements the shared pieces lives in `Reef/Design/`.

---

## 1. Direction

### Midnight core, glass shell

The island is black wherever it meets the hardware notch, and glass wherever
it grows past it.

- **At rest** on a notched MacBook, the island is pure black, so it disappears
  into the cutout, exactly like the iPhone Dynamic Island.
- **When it opens or spreads its wings**, the part below and beside the notch
  is glass: the desktop shows through, blurred and darkened, with a rim of light
  along the edge. A solid band fades from the notch into the glass, so the
  cutout never shows through.
- **On a Mac without a notch**, or in the floating style, there is nothing to
  hide, so the whole island is glass.

### Why this direction

A review of the existing notch apps (boring.notch, Atoll, NotchNook, Alcove,
DynamicLake, Notchy, DynamicNotchKit, and others) shows a clear split:

| Approach | Apps | Strength | Weakness |
|---|---|---|---|
| Solid black island | boring.notch, Atoll, NotchNook, Alcove | Blends with the notch; always legible | Looks heavy on light wallpapers; feels dated next to macOS 26 |
| Glass styles | DynamicLake (Liquid and Frosted Glass), Notchy (Liquid Glass UI) | Feels native on macOS 26 | Text legibility and the visible notch cutout are often unsolved |
| Floating capsule | DynamicNotchKit, Seam, Atoll on non-notch Macs | Works on every Mac | Reads as a separate widget, not part of the screen |

Reef takes the strength of each: black where it must blend, glass where it can
breathe, and a floating style for Macs without a notch. Reviews consistently
praise Alcove and NotchNook for polish and motion and criticize boring.notch
for "less polished animations", so motion quality is treated as a feature,
not a finish.

### 2026 glass, done with restraint

Glass in 2026 means Apple's Liquid Glass on macOS 26 and a more restrained
"glassmorphism 2.0" elsewhere. The rules Reef follows:

1. **Glass is for the floating layer only.** The island body is glass; the
   cards inside it are not. Glass cannot sample other glass, and stacking it
   muddies the result.
2. **Dark tint, always.** Island text is white, so the glass is tinted dark
   enough to stay legible over a white wallpaper.
3. **A rim of light, not a border.** Frosted glass gets a gradient rim, bright
   at the top-leading edge and faint at the bottom-trailing edge, as if lit
   from above. Liquid Glass draws its own edge, so Reef adds only a hairline.
4. **Accessibility first.** Reduce Transparency draws solid black. Increase
   Contrast replaces the soft rim with a clear solid edge. Reduce Motion swaps
   springs for short fades.
5. **No decorative motion at rest.** The island stays still unless something
   is happening.

---

## 2. Tokens

Defined in `Reef/Design/ReefTheme.swift`.

### Spacing (4 pt grid)

| Token | Value | Use |
|---|---|---|
| `hairline` | 2 | Tight gaps inside glyphs |
| `xs` | 4 | Icon to label |
| `s` | 8 | Between cards |
| `m` | 12 | Card padding |
| `l` | 16 | Header padding, large card padding |
| `xl` | 24 | Section spacing in panels |

### Radii (concentric)

| Token | Value | Use |
|---|---|---|
| `island` | 26 | Open island body |
| `islandInset` | 10 | Gap between island edge and cards |
| `card` | 16 | Cards inside the island (`island - islandInset`) |
| `control` | 9 | Chips, selected tab pill, small buttons |

The resting floating pill is always a capsule (radius = half its height). The
attached resting shape uses 13 pt bottom corners and 6 pt concave shoulders.

### Type

SF Pro Rounded throughout the island, with tabular digits for every number.

| Token | Size / weight | Use |
|---|---|---|
| `display` | 34 semibold | Clock, large timer readout |
| `title` | 15 semibold | Card values, track title |
| `body` | 13 medium | Labels, list rows |
| `caption` | 11 medium | Secondary labels, header items |
| `wing` | 12 semibold | Values in the collapsed wings |

### Ink (the island is always dark)

| Token | Value |
|---|---|
| `primary` | white |
| `secondary` | white 62% |
| `tertiary` | white 38% |
| `fill` | white 7% (card fill) |
| `fillStrong` | white 14% (pressed, selected) |
| `stroke` | white 10% (card hairline) |

### Status colors (independent of accent)

| Token | Use |
|---|---|
| `charging` (green) | Charging, connected, success |
| `warning` (amber) | Low battery, 20% and below |
| `critical` (red) | Critical battery, 10% and below; recording indicator |

### Accents

Lagoon (default), Iris, Coral, Sunset, Mint, Pearl. The accent colors
selection, progress rings, meters, and the selected tab. It never replaces a
status color.

---

## 3. Materials

Defined in `Reef/Design/Appearance.swift` and `Reef/Design/IslandSurface.swift`.

| Material | Look | Implementation |
|---|---|---|
| Midnight | Solid black with a 6% top sheen and a hairline rim | `Color.black` |
| Frosted | Blurred desktop, 38% black tint, 12% sheen, specular gradient rim | `NSVisualEffectView` (`.hudWindow`, behind window) |
| Liquid Glass | System glass, dark tint, hairline rim | `glassEffect(.regular.tint(...), in: NotchShape)` on macOS 26; frosted elsewhere |

Liquid Glass is the default. It compiles only with the macOS 26 SDK (guarded by
`#if compiler(>=6.2)`) and runs only on macOS 26 (guarded by `#available`), so
older SDKs and systems quietly fall back to frosted glass. CI builds once with
each SDK.

---

## 4. Shape

Defined in `Reef/Overlay/NotchShape.swift`.

- **Attached**: concave shoulders flare out along the top edge, the way the
  hardware notch flows out of the menu bar. The body has rounded bottom corners
  (13 pt at rest, 26 pt open).
- **Floating**: a capsule at rest, a uniformly rounded panel (26 pt) open, 3 pt
  below the top edge, with a soft shadow.

All radii and the shoulder width are animatable, so switching style or
opening the island morphs the silhouette rather than swapping it.

---

## 5. Motion

Defined in `MotionStyle` (`Reef/Design/Appearance.swift`). Three presets, each
with four springs:

| Preset | Open | Close | Peek | Wings |
|---|---|---|---|---|
| Smooth (default) | 0.42 s, no overshoot | 0.45 s, no overshoot | 0.30 s, 0.80 | 0.38 s, 0.95 |
| Snappy | 0.30 s, 0.92 | 0.32 s, no overshoot | 0.22 s, 0.85 | 0.28 s, 0.90 |
| Bouncy | 0.46 s, 0.74 | 0.44 s, 0.90 | 0.30 s, 0.62 | 0.42 s, 0.70 |

Rules:

- Closing is never bouncier than opening, so the island settles back cleanly.
- Content inside the island arrives with a **blur-resolve**: it starts blurred
  8 pt, at 96% scale anchored to the top, and transparent. This is the
  `islandContent` transition.
- Numbers roll with `contentTransition(.numericText())`.
- With Reduce Motion on, every spring becomes a 0.18 s ease.
- Hover opens after a 0.2 s settle; leaving closes after 0.15 s.

---

## 6. Overlay states (spec section 1)

| State | Design | Status |
|---|---|---|
| Resting | Notch-sized black shape, or a glass capsule (200 by menu bar height) | Built |
| Hover peek | Grows 10 by 5 pt with the peek spring; rim brightens | Built |
| Open | Header row at resting height beside the notch, then the page body (136 pt) | Built |
| Live activity wings | Resting shape widens 48 pt on each side; glyph left, value right; label in the middle when there is no notch | Built |
| Concealed | Hidden during Mission Control, App Expose, and Show Desktop via the transient window behavior | Built |
| Relocating | Shrinks to 90% and fades out in 0.12 s, moves, then pops back with the peek spring | Built |

---

## 7. Island tabs (spec section 2)

The open header holds the **tab strip** on the leading side, next to the notch.

- Each tab is an SF Symbol in a 26 pt hit area. The selected tab expands into a
  capsule with its title, filled with the accent at 18% and labeled in the
  accent color. The selection pill slides between tabs with a matched geometry
  animation.
- More than five tabs: the strip scrolls horizontally with a fade mask at both
  ends; it never wraps to a second row.
- The trailing side of the header carries glanceable status: the battery badge
  today, and later quick toggles.

Pages: Home, Media, Stats, Timer, Clipboard, Notes, Color picker, Shelf,
Terminal, Usage, Extension.

Status: Home is built, with the pill that becomes the strip once a second page
exists.

---

## 8. Live activities (spec section 3)

Every activity follows one wing grammar: a 48 pt **leading wing** with a glyph
or artwork, a 48 pt **trailing wing** with a value or meter, and an optional
**center label** shown only when there is no hardware notch.

| Activity | Leading wing | Trailing wing | Tint | Status |
|---|---|---|---|---|
| Charging | Bolt, pulsing | Percent | Charging green | Built |
| Fully charged | Full battery | Check | Charging green | Built |
| Low battery | Battery 25% (amber) or 0% (red, pulsing) | Percent | Warning / critical | Built |
| Now playing | Album art, 20 pt, 6 pt radius | Five-bar equalizer in the accent | Accent | Specified |
| Focus | Focus symbol | Focus name, scrolling if long | Focus color | Specified |
| Privacy | Mic and camera dots (orange, green) | Nothing | System | Specified |
| Screen recording | Red record dot, pulsing | Elapsed time | Critical | Specified |
| Downloads | Spinning ring | Percent or count | Accent | Specified |
| Timer | Shrinking ring | Remaining time | Accent | Specified |
| Reminder / calendar | Countdown ring | Minutes until | Accent | Specified |
| Network | Wi-Fi or Ethernet symbol | Network name or "Offline" | Status | Specified |
| Weather | Condition symbol | Temperature | Ink | Specified |
| AirDrop | AirDrop symbol | Progress ring | Accent | Specified |
| Extension | Extension icon | Extension value | Extension tint | Specified |

Priority decides which activity shows: critical battery, then recording and
privacy, then low battery, timers and reminders, charging, media, and the rest.
Battery activities show for 4 to 6 seconds; ongoing ones (media, recording,
timers) stay while active. Each activity can be turned off in Settings, Live
Activities, which also has a Preview button for each one.

---

## 9. Media (spec section 4)

- **Mini player (Home)**: 56 pt artwork with a 12 pt radius on the left; title
  (`title`) and artist (`caption`, secondary) scroll if long; a 3 pt progress bar
  in the accent; transport buttons as 28 pt circles that fill white 14% on
  press. Source app icon at 14 pt in the corner of the artwork.
- **Full player (Media tab)**: 96 pt artwork; a background glow sampled from the
  artwork's dominant color at 30%, behind the glass tint; full transport; a
  scrubber that thickens from 4 to 8 pt on hover; volume capsule; like, shuffle,
  and repeat as 24 pt symbols.
- **Waveform scrubber**: 40 bars, played bars in the accent, unplayed white 25%.
- **Visualizer**: five capsule bars, 3 pt wide, animated from audio levels.
- **Synced lyrics**: the current line in `title`, neighbors in `body` at
  secondary and tertiary, auto-scrolling; the pinned single-line mode sits in
  the trailing wing. The sweep highlights the current line left to right in
  the accent.
- **Source picker**: a popover listing players with their icon and a
  capability line ("Play, skip, seek, like").
- **Live stream**: a red "LIVE" capsule replaces the progress bar.

---

## 10. HUD and OSD replacements (spec section 5)

All HUDs share the glass surface and appear from the island with the wings
spring.

- **Inline**: the wings spread; the leading wing shows the symbol (speaker,
  sun, keyboard backlight, caps lock), the trailing wing a 4 pt capsule meter
  in white with the level filled.
- **Circular**: a 64 pt ring gauge (`RingGauge`) below the island, with the
  symbol in the middle.
- **Vertical**: a 36 by 160 pt glass capsule at the screen edge, filled from the
  bottom.
- **Numeric label**: `wing` style, tabular digits, no percent sign for volume
  (0 to 16 steps) unless the person prefers percent.
- **Network HUD**: inline form with the network name and a check or cross.

---

## 11. System stats (spec section 6)

- **Overview**: a row of five 52 pt ring gauges (CPU, GPU, memory, disk,
  network), each with its value in `caption` beneath.
- **Detail views**: a card per metric with a 60-sample timeline graph (1.5 pt
  line in the accent with a 20% to 0% gradient fill below), per-core bars for
  CPU, and a dual graph for network (upload in the accent, download in
  white).
- **Process list**: ranked rows with app icon, name, and value; the top row is
  highlighted in `fillStrong`.

---

## 12. Productivity tools (spec section 7)

- **Timer**: a horizontal ruler picker with minute ticks that snap; running
  timers as cards with a ring and name; the live activity uses the timer wing.
- **Clipboard**: a vertical list of cards, text clipped to two lines, images as
  thumbnails; pin and delete appear on hover; items drag out.
- **Color picker**: a large swatch card with HEX, RGB, and HSL rows to copy; a
  saved-colors grid of 24 pt circles; the pick flashes the island rim in the
  picked color.
- **Calendar**: event rows with a 3 pt calendar-color bar, time in `caption`,
  title in `body`.
- **Notes**: list, split (list plus preview), and editor layouts.
- **Terminal**: a monospaced pane on a black card inside the glass.

---

## 13. Shelf and sharing (spec section 8)

- **Empty**: a dashed 1.5 pt card outline with a tray symbol and "Drop files
  here".
- **Drag over**: the whole island rim lights in the accent and the island grows
  open as files approach.
- **Items**: 56 pt thumbnails with the name in `caption`, a remove button on
  hover.
- **AirDrop**: a row of nearby device avatars; a progress ring per transfer.

---

## 14. Devices, webcam, assistant (spec sections 9 to 11)

- **Bluetooth battery card**: device symbol, name, and ring gauges per ear and
  case.
- **Audio route switcher**: list rows with a check on the current route.
- **Keep awake**: a coffee-cup toggle; the active state shows a small cup in the
  trailing wing.
- **Webcam mirror**: a rounded 4:3 card with flip and size controls.
- **Assistant (optional)**: chat bubbles as cards; model picker as a chip;
  snipping overlay with a dimmed screen and a bright selection.

---

## 15. Lock screen (spec section 12)

Widgets reuse the island cards on a larger scale: a 340 pt wide glass panel
below the clock with media, timer, charging, nearby device, weather, reminder,
and calendar rows. A lock-screen island replica shows ongoing activities.
Placement (top, center, bottom) and tint are set in Settings.

---

## 16. Onboarding (spec section 13)

A centered 560 by 420 window with a glass island animating at the top as the
hero. Steps: welcome, permissions (rows with granted check or "Allow"
button), player selection, profile (Minimal, Balanced, Everything), optional
upgrade, finish with the island opening for the first time. A five-dot
progress indicator sits at the bottom.

---

## 17. Settings window (spec section 14)

Built as a System Settings style window: a searchable sidebar grouped under
headers, each page with a colored icon tile, and grouped forms on the right.

Built pages:

- **General**: island style (attached or floating), open at login, restore
  defaults.
- **Appearance**: a live, clickable island preview over a colorful backdrop;
  material tiles; accent swatches; motion picker.
- **Live Activities**: per-activity toggles with Preview buttons.
- **About**: icon, version, links.

The remaining pages from the spec (Lock screen, Media, Devices, Timer,
Calendar, HUD and OSD, Battery, Stats, Clipboard, Screen assistant, Color
picker, Downloads, Shelf, Shortcuts, Notes, Terminal, Keep awake, Extensions,
Integrations, Software update) are added to `SettingsSection` as their features
land, under the groups Core, Media and display, System, Productivity,
Utilities, Developer, Integrations, and Info. Pages with visual choices (notch
height, HUD style, lock screen layout, animation style) get a preview at the
top, like Appearance.

---

## 18. Menu bar, gestures, and modes (spec sections 15 to 17)

- **Menu bar**: the `water.waves` symbol; menu with Settings, About, and Quit,
  growing feature toggles as features land.
- **Gestures**: hover to open with the settle delay; two-finger swipe down and
  up when hover is off; horizontal swipe over media to skip or seek, with
  haptics; optional 2 degree parallax tilt on hover.
- **Minimalistic mode**: media and HUDs only, Smooth motion, no tab strip.
- **Notch height**: match notch, match menu bar, or custom (with a preview).
