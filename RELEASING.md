# Releasing Reef

Reef auto-updates with [Sparkle](https://sparkle-project.org). This is the
one-time + per-release setup. Until it's done, the in-app "Check for Updates"
will report that it can't check — the code is wired, the infrastructure is not.

## One-time setup

1. **Generate the signing keys** (EdDSA). From Sparkle's tools (bundled with the
   Swift package under `~/Library/Developer/Xcode/DerivedData/Reef-*/SourcePackages/artifacts/sparkle/Sparkle/bin`):

   ```sh
   ./generate_keys
   ```

   This stores the **private** key in your login keychain and prints the
   **public** key.

2. **Add the public key** to `project.yml` under `targets.Reef.info.properties`:

   ```yaml
   SUPublicEDKey: "<the public key printed above>"
   ```

   Then `xcodegen generate`. (The feed URL `SUFeedURL` is already set to the
   GitHub releases appcast.)

> Keep the private key safe. Anyone with it can sign updates your users will
> install. Never commit it.

## Per release

1. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml`,
   `xcodegen generate`.
2. Archive, export a **Developer ID**–signed build, and **notarize** it.
3. Zip the app: `ditto -c -k --keepParent Reef.app Reef-<version>.zip`.
4. Generate/update the appcast (signs each build with your private key):

   ```sh
   ./generate_appcast /path/to/folder-of-zips
   ```

   This writes `appcast.xml` next to the zips.
5. Create a GitHub release for the version tag and attach both
   `Reef-<version>.zip` and `appcast.xml`.

`SUFeedURL` points at `releases/latest/download/appcast.xml`, so users on older
versions see the update on the next check.
