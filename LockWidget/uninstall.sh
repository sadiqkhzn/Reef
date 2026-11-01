#!/bin/bash
#
# Remove the Reef lock-screen widget and restore the original unlock rule.
# Run with sudo. Safe to run even if only part of the install happened.
#
set -euo pipefail

PLUGINS="/Library/Security/SecurityAgentPlugins"
RIGHT="system.login.screensaver"
DATADIR="/Library/Application Support/Reef"
BACKUP="$DATADIR/screensaver-backup.plist"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo: sudo ./uninstall.sh"
    exit 1
fi

# Restore the original rule from the backup taken at install time.
if [ -f "$BACKUP" ]; then
    security authorizationdb write "$RIGHT" < "$BACKUP"
    echo "Restored $RIGHT from backup."
else
    echo "No backup found; leaving $RIGHT as-is."
    echo "If the widget mechanism is still listed, reset the rule with:"
    echo "  sudo security authorizationdb remove $RIGHT   # then log out/in to regenerate defaults"
fi

rm -rf "$PLUGINS/ReefLockWidget.bundle"
echo "Removed $PLUGINS/ReefLockWidget.bundle"

echo "Left $DATADIR in place (contains the shared state and backup)."
echo "Delete it yourself if you want: sudo rm -rf \"$DATADIR\""
