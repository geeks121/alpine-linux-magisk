#!/system/bin/sh
#====================================================
# Alpine Linux - Post FS Data Script (Patched)
#====================================================

MODDIR="${0%/*}"

# Create global command symlink for Magisk/KSU/APatch (vaultwarden-universal pattern)
# This allows 'alpine' command to work from any shell (adb, Termux, SSH, root, cron)
# MUST run BEFORE sourcing common.sh - KSU may not have module paths ready yet
TARGET="$MODDIR/system/bin/alpine"

# Detect root solution bin directory (use first available like vaultwarden-universal)
if [ -d /data/adb/magisk/bin ]; then
    BIN_DIR="/data/adb/magisk/bin"
elif [ -d /data/adb/ksu/bin ]; then
    BIN_DIR="/data/adb/ksu/bin"
elif [ -d /data/adb/ap/bin ]; then
    BIN_DIR="/data/adb/ap/bin"
else
    exit 0
fi

LINK="$BIN_DIR/alpine"

# Create symlink if missing or points elsewhere
if [ ! -L "$LINK" ] || [ "$(readlink "$LINK")" != "$TARGET" ]; then
    ln -sf "$TARGET" "$LINK"
fi

# Now load common functions for the rest
. "$MODDIR/common.sh"

inf "Initializing Alpine Linux module"

# Create necessary directories (ensure directories exist before log functions)
mkdir -p "$R"
chmod 755 "$R"

if [ -d "$RF/usr/bin" ]; then
    echo "$RF/usr/bin:$RF/bin" > /data/adb/alpine_path
fi

inf "Initialization complete"
