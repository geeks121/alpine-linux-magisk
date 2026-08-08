#!/system/bin/sh
#====================================================
# Alpine Linux - Boot Service (Patched)
#====================================================

MODDIR="${0%/*}"
. "$MODDIR/common.sh"

# Wait for boot complete
wait_for_boot() {
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 1
    done
    sleep 5
}

# Main function
main() {
    inf "========================================"
    inf " Alpine Linux Service Starting"
    inf "========================================"

    # Check rootfs
    if ! ck; then
        wrn "rootfs not installed, skipping auto-start"
        inf "Use 'alpine download' to install"
        exit 0
    fi

    # Start Alpine (includes auto-start services)
    alpine_start

    # Check start result
    if run; then
        inf "Alpine Linux running in background"
    else
        err "Alpine Linux start failed"
    fi
}

# Background execution
wait_for_boot && main &
