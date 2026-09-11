#!/usr/bin/with-contenv bash
# See https://github.com/crocodilestick/Calibre-Web-Automated/issues/1224

set +e
echo "[calibre-binaries-setup-WORKAROUND] Starting workaround wrapper script"

# Download original script we replaced
curl -sL https://raw.githubusercontent.com/crocodilestick/Calibre-Web-Automated/refs/heads/main/root/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run -o /etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original
chmod +x /etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original

# Create fake xdg-* commands in system space
for FAKECOMMAND in xdg-desktop-menu xdg-mime; do
  echo -e '#!/bin/sh\nexit 0' > /usr/local/bin/${FAKECOMMAND}
  chmod +x /usr/local/bin/${FAKECOMMAND}
done

# Run the original script
/etc/s6-overlay/s6-rc.d/calibre-binaries-setup/run.original
ORIGINAL_EXIT_CODE=$?

# Verify fallback logic
if [ -x /usr/bin/calibredb ]; then
  echo "[calibre-binaries-setup-WORKAROUND] Calibre installation verified successfully"
  EXIT_STATUS=0
else
  echo "[calibre-binaries-setup-WORKAROUND] Calibre installation failed"
  EXIT_STATUS=$ORIGINAL_EXIT_CODE
fi

# Clean up system binary folder
for FAKECOMMAND in xdg-desktop-menu xdg-mime; do
  rm -f /usr/local/bin/x${FAKECOMMAND}
done

# Important: Exit with 0 if calibredb is ready, so s6 doesn't crash the container
exit $EXIT_STATUS
