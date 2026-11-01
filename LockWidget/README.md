# Reef Lock-Screen Widget (experimental)

A SecurityAgent authorization plugin that draws a small ambient widget — clock,
playing track, weather, battery — on the screensaver **unlock** screen. This is
the only supported place a third-party process can draw on the locked Mac, and
it comes with real caveats. Read this before installing.

## Safety model

The plugin is registered as a **display-only** mechanism:

- It **never reads, checks, or sets your password.** Authentication stays
  entirely with the system's own mechanisms, which run after this one.
- Its mechanism **always allows and continues.** It cannot block or weaken
  login — the worst it can do is fail to draw its widget.
- All UI code is exception-guarded so nothing can escape into the SecurityAgent.

Because it is not in the credential path, it cannot lock you out. The residual
risk is cosmetic (the widget may not render well) plus the general fragility of
any private integration across OS updates.

## Build & install

```sh
cd LockWidget
./build.sh                 # builds build/ReefLockWidget.bundle (no sudo)
sudo ./install.sh          # installs the plugin + adds the display mechanism
```

Then lock the screen (Ctrl-Cmd-Q) to see it. Reef must be running so the shared
state file (`/Library/Application Support/Reef/lockscreen.json`) is kept current.

## Uninstall

```sh
cd LockWidget
sudo ./uninstall.sh        # restores the original unlock rule, removes the plugin
```

## If something goes wrong

The install is reversible and your data is never touched. If the unlock screen
ever misbehaves:

1. **Safe Mode** (most reliable): shut down, hold the power button until
   "Loading startup options" appears, pick your disk while holding **Shift**, and
   choose "Continue in Safe Mode." Safe Mode does not load third-party
   SecurityAgent plugins, so you can log in normally, then run
   `sudo ./uninstall.sh`.
2. From a normal login, `sudo ./uninstall.sh` restores the original rule.

Your files are never at risk here — this only affects an authentication UI
config, not the disk.

## Known limitations

- **No Touch ID at unlock while active.** A rule with a third-party mechanism
  falls back to password entry; Touch ID unlock is not available for it.
- **Display-only, constrained.** The widget is drawn as an overlay; it does not
  control the surrounding lock-screen chrome, and whether it renders and persists
  neatly next to the password field varies by macOS version.
- **Not notarized.** It is ad-hoc signed for local use on your own machine.
- **Fragile across updates.** Apple can change the authorization flow in any
  release; re-check after major macOS updates.

## How it fits together

- `ReefLockWidget/ReefLockWidget.m` — the plugin: the authorization-plugin C
  interface plus the AppKit overlay window.
- Reef app (`LockWidgetBridge`) writes `lockscreen.json` with the current track,
  weather, and battery whenever the shared directory exists.
- `install.sh` adds the mechanism to `system.login.screensaver`; `uninstall.sh`
  restores it from the backup saved at install time.
