# Vendored: mediaremote-adapter

This folder holds a third-party dependency, vendored so Reef builds without
fetching anything at build time.

- **Project:** mediaremote-adapter by Jonas van den Berg
- **Source:** https://github.com/ungive/mediaremote-adapter
- **Version:** v0.7.7
- **License:** BSD 3-Clause (see `LICENSE`)

## What it is

A small helper that reads system-wide now playing information from Apple's
private MediaRemote framework and controls playback. It works on macOS 15.4 and
later, where that framework is otherwise off-limits to ordinary apps, by running
through the system Perl binary, which is still permitted to use it.

## What is here

- `MediaRemoteAdapter.framework` is the prebuilt helper framework (universal,
  x86_64 and arm64). It is bundled with the app but not linked against. The Perl
  script loads it; Reef only passes its path.
- `mediaremote-adapter.pl` is the Perl entry point Reef launches.
- `LICENSE` is the dependency's BSD 3-Clause license and must ship with it.

## How to rebuild the framework

```
git clone --branch v0.7.7 https://github.com/ungive/mediaremote-adapter.git
cd mediaremote-adapter && mkdir build && cd build
cmake .. && cmake --build .
```

Then copy `build/MediaRemoteAdapter.framework`, `bin/mediaremote-adapter.pl`,
and `LICENSE` here.
