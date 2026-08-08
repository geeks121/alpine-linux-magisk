#!/system/bin/sh
#====================================================
# Alpine Linux Chroot - Uninstall Script (Patched)
#====================================================

MODDIR="${0%/*}"

# Load common functions
. "$MODDIR/common.sh"

inf "Uninstalling Alpine Linux module..."

# Stop Alpine (Fixed: use correct function name run)
if run; then
    inf "Stopping Alpine Linux..."
    alpine_stop
fi

# Clean up files
rm -f /data/adb/alpine_path 2>/dev/null

# Clean up logs
rm -f "$LOG" 2>/dev/null

# Clean up service directory
rm -rf "$SVC" 2>/dev/null

# Remove global command symlinks (Magisk/KSU/APatch)
for bindir in /data/adb/magisk/bin /data/adb/ksu/bin /data/adb/ap/bin; do
    [ -L "$bindir/alpine" ] && rm -f "$bindir/alpine" 2>/dev/null
done

inf "Alpine Linux module uninstalled"
inf "Note: Alpine rootfs preserved at $RF"
inf "To fully remove, manually run: rm -rf $R"
