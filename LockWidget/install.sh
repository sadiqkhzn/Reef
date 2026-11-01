#!/bin/bash
#
# Install the Reef lock-screen widget. Run with sudo.
#
# It copies the plugin into the SecurityAgent plugins directory, creates the
# shared data directory Reef writes to, and adds a DISPLAY-ONLY mechanism to the
# screensaver-unlock rule. The mechanism never checks the password, so it cannot
# block login. If the rule is not in a form we can safely edit, the script says
# so and changes nothing in the authorization database.
#
# Undo everything with: sudo ./uninstall.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$DIR/build/ReefLockWidget.bundle"
PLUGINS="/Library/Security/SecurityAgentPlugins"
RIGHT="system.login.screensaver"
DATADIR="/Library/Application Support/Reef"
BACKUP="$DATADIR/screensaver-backup.plist"
MECHANISM="ReefLockWidget:widget"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo: sudo ./install.sh"
    exit 1
fi
if [ ! -d "$BUNDLE" ]; then
    echo "Plugin not built yet. Run ./build.sh first."
    exit 1
fi

# Shared data directory, writable by the logged-in user so Reef can update it.
USER_NAME="${SUDO_USER:-$(stat -f%Su /dev/console)}"
mkdir -p "$DATADIR"
chown "$USER_NAME" "$DATADIR"
chmod 755 "$DATADIR"

# Install the plugin bundle.
mkdir -p "$PLUGINS"
rm -rf "$PLUGINS/ReefLockWidget.bundle"
cp -R "$BUNDLE" "$PLUGINS/ReefLockWidget.bundle"
echo "Installed plugin to $PLUGINS/ReefLockWidget.bundle"

# Back up the current rule once, before any change.
TMP="$(mktemp)"
security authorizationdb read "$RIGHT" > "$TMP"
if [ ! -f "$BACKUP" ]; then
    cp "$TMP" "$BACKUP"
    chown "$USER_NAME" "$BACKUP"
    echo "Backed up $RIGHT to $BACKUP"
fi

if /usr/libexec/PlistBuddy -c "Print :mechanisms" "$TMP" >/dev/null 2>&1; then
    # Avoid adding twice.
    if /usr/libexec/PlistBuddy -c "Print :mechanisms" "$TMP" | grep -q "$MECHANISM"; then
        echo "Mechanism already present in $RIGHT."
    else
        /usr/libexec/PlistBuddy -c "Add :mechanisms:0 string $MECHANISM" "$TMP"
        security authorizationdb write "$RIGHT" < "$TMP"
        echo "Added display mechanism to $RIGHT."
    fi
    echo
    echo "Done. Lock the screen (Ctrl-Cmd-Q) to test the widget."
    echo "If anything misbehaves, run: sudo $DIR/uninstall.sh"
else
    REF="$(/usr/libexec/PlistBuddy -c 'Print :rule:0' "$TMP" 2>/dev/null || echo unknown)"
    echo
    echo "NOTE: $RIGHT has no inline mechanisms; it references the rule '$REF'."
    echo "To stay safe, the authorization database was NOT changed automatically."
    echo "The plugin bundle and data directory are installed, but the widget will"
    echo "not appear until a mechanism is added. See README.md for the manual step."
fi

rm -f "$TMP"
