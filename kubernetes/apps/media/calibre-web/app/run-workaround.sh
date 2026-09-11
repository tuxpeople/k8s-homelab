#!/usr/bin/with-contenv bash
#
# See https://github.com/crocodilestick/Calibre-Web-Automated/issues/1224

set +e
echo "WORKAROUND - WORKAROUND - WORKAROUND - WORKAROUND - WORKAROUND"

# Create a fake xdg-desktop-menu command that always succeeds
mkdir -p /tmp/mock-bin
echo -e '#!/bin/sh\nexit 0' > /tmp/mock-bin/xdg-desktop-menu
chmod +x /tmp/mock-bin/xdg-desktop-menu

curl -sL https://raw.githubusercontent.com/crocodilestick/Calibre-Web-Automated/refs/heads/main/root/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run | PATH="/tmp/mock-bin:$PATH" bash

if [ -x /usr/bin/calibredb ]; then
  echo "[calibre-binaries-setup-WORKAROUND] Calibre installation verified successfully"
else
  echo "[calibre-binaries-setup-WORKAROUND] Calibre installation failed"
  exit 1
fi

# Clean up
rm -rf /tmp/mock-bin
