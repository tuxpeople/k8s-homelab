#!/usr/bin/with-contenv bash
#
# See https://github.com/crocodilestick/Calibre-Web-Automated/issues/1224

set +e
echo "WORKAROUND - WORKAROUND - WORKAROUND - WORKAROUND - WORKAROUND"

# Download original script we replaced
curl -sL https://raw.githubusercontent.com/crocodilestick/Calibre-Web-Automated/refs/heads/main/root/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run -o /etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original
chmod +x /etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original

# Create a fake xdg-desktop-menu command that always succeeds
mkdir -p /tmp/mock-bin
echo -e '#!/bin/sh\nexit 0' > /tmp/mock-bin/xdg-desktop-menu
chmod +x /tmp/mock-bin/xdg-desktop-menu

# Export the modified PATH so it carries over to child scripts
export PATH="/tmp/mock-bin:$PATH"

# Run the original script
/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original

# Check what happened
if [ -x /usr/bin/calibredb ]; then
  echo "[calibre-binaries-setup-WORKAROUND] Calibre installation verified successfully"
else
  echo "[calibre-binaries-setup-WORKAROUND] Calibre installation failed"
fi

# Clean up
rm -rf /tmp/mock-bin
