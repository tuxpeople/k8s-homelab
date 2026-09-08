#!/usr/bin/with-contenv bash
#
# See https://github.com/crocodilestick/Calibre-Web-Automated/issues/1224

set +e
echo "WORKAROUND - WORKAROUND - WORKAROUND - WORKAROUND - WORKAROUND"
curl -s https://raw.githubusercontent.com/crocodilestick/Calibre-Web-Automated/refs/heads/main/root/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run -o /etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original
chmod +x /etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original
/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original
setup_exit=$?

if [ -x /usr/bin/calibredb ]; then
    echo "[calibre-binaries-setup] Calibre installation verified successfully"
    exit 0
fi

exit $setup_exit
