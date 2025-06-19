#!/bin/sh

DINIT_SERVICE=root-fsck
DINIT_NO_CONTAINER=1

. @SCRIPT_PATH@/common.sh

command -v fsck > /dev/null 2>&1 || exit 0

FORCEARG=
FIXARG="-a"

if [ -r /proc/cmdline ]; then
    for x in $(cat /proc/cmdline); do
        case "$x" in
            fastboot|fsck.mode=skip)
                echo "Skipping root filesystem check (fastboot)."
                exit 0
                ;;
            forcefsck|fsck.mode=force)
                FORCEARG="-f"
                ;;
            fsckfix|fsck.repair=yes)
                FIXARG="-y"
                ;;
            fsck.repair=no)
                FIXARG="-n"
                ;;
        esac
    done
fi

mntent() {
    @HELPER_PATH@/mnt getent "$1" / "$2" 2>/dev/null
}

ROOTFSPASS=$(mntent /etc/fstab passno)
# skipped; every other number is treated as that we do check
# technically the pass number could be specified as bigger than
# for other filesystems, but we don't support this configuration
if [ "$ROOTFSPASS" = "0" ]; then
    echo "Skipping root filesystem check (fs_passno == 0)."
    exit 0
fi

ROOTDEV=$(mntent /proc/self/mounts fsname)
# e.g. zfs will not report a valid block device
[ -n "$ROOTDEV" -a -b "$ROOTDEV" ] || exit 0

ROOTFSTYPE=$(mntent /proc/self/mounts type)
# ensure it's a known filesystem
[ -n "$ROOTFSTYPE" ] || exit 0

# ensure we have a fsck for it
command -v "fsck.$ROOTFSTYPE" > /dev/null 2>&1 || exit 0

echo "Checking root file system (^C to skip)..."

fsck -C $FORCEARG $FIXARG -t "$ROOTFSTYPE" "$ROOTDEV"

# it's a bitwise-or, but we are only checking one filesystem
case $? in
    0) ;; # nothing
    1) # fixed errors
        echo "WARNING: The root filesystem was repaired, continuing boot..."
        sleep 2
        ;;
    2) # system should be rebooted
        echo "WARNING: The root filesystem was repaired, rebooting..."
        sleep 5
        reboot --use-passed-cfd -r
        ;;
    4) # uncorrected errors
        echo "WARNING: The root filesystem has unrecoverable errors."
        echo "         A recovery shell will now be started for you."
        echo "         The system will be rebooted when you are done."
        @DINIT_SULOGIN_PATH@
        reboot --use-passed-cfd -r
        ;;
    *) ;;
esac
