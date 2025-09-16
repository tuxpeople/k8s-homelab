#!/bin/bash

# Titel von https://ascii.today
# Variante "DOOM BY FRANS P. DE VRIES"

set -e

# Optionales Logging
echo "Pre-consume script starting…"

# https://github.com/ocrmypdf/OCRmyPDF/issues/1483
cat <<"EOF"
______ _                        _ _          _  __________________
|  ___(_)                      (_) |        | | | ___ \  _  \  ___|
| |_   ___  __  _ __ ___   __ _ _| | ___  __| | | |_/ / | | | |_ ___
|  _| | \ \/ / | '_ ` _ \ / _` | | |/ _ \/ _` | |  __/| | | |  _/ __|
| |   | |>  <  | | | | | | (_| | | |  __/ (_| | | |   | |/ /| | \__ \
\_|   |_/_/\_\ |_| |_| |_|\__,_|_|_|\___|\__,_| \_|   |___/ \_| |___/
EOF
MIME_TYPE=$(file --mime-type -b "${DOCUMENT_SOURCE_PATH}")

if [ "$MIME_TYPE" == "application/pdf" ]; then
        gs -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -sOutputFile="${DOCUMENT_WORKING_PATH}" "${DOCUMENT_SOURCE_PATH}"
fi

exit 0


# Stelle sicher, dass pymupdf installiert ist (nur beim ersten Lauf nötig, ggf. rausnehmen)
pip install --quiet pymupdf

# Remove Forms
cat <<"EOF"
______                         _                          _       _
|  ___|                       | |                        (_)     | |
| |_ ___  _ __ _ __ ___  _   _| | __ _ _ __ ___  ___ _ __ _ _ __ | |_
|  _/ _ \| '__| '_ ` _ \| | | | |/ _` | '__/ __|/ __| '__| | '_ \| __|
| || (_) | |  | | | | | | |_| | | (_| | |  \__ \ (__| |  | | |_) | |_
\_| \___/|_|  |_| |_| |_|\__,_|_|\__,_|_|  |___/\___|_|  |_| .__/ \__|
                                                           | |
                                                           |_|
EOF
/usr/src/paperless/scripts/paperless-preprocess-forms.py

# # Remove Text with bad characters
# cat <<"EOF"
#  ______     _      _                              _       _
# |___  /    (_)    | |                            (_)     | |
#    / /  ___ _  ___| |__   ___ _ __  ___  ___ _ __ _ _ __ | |_
#   / /  / _ \ |/ __| '_ \ / _ \ '_ \/ __|/ __| '__| | '_ \| __|
# ./ /__|  __/ | (__| | | |  __/ | | \__ \ (__| |  | | |_) | |_
# \_____/\___|_|\___|_| |_|\___|_| |_|___/\___|_|  |_| .__/ \__|
#                                                    | |
#                                                    |_|
# EOF
# /usr/src/paperless/scripts/paperless-preprocess-removebadchars.py
