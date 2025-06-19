#!/bin/sh

DINIT_SERVICE=bless-boot
DINIT_NO_CONTAINER=1

. @SCRIPT_PATH@/common.sh

bless=@BLESS_BOOT_PATH@

[ -x $bless ] || exit 0

case "$($bless status)" in
    indeterminate)
        # bless quietly
        $bless good
        ;;
    bad)
        # notify and bless
        echo "Successful boot from bad image, clearing..."
        $bless good
        ;;
    *)
        # probably not used
        ;;
esac

exit 0
