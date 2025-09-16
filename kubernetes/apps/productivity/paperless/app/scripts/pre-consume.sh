#!/bin/bash

# Titel von https://ascii.today
# Variante "DOOM BY FRANS P. DE VRIES"

set -e

# Optionales Logging
echo "Pre-consume script starting…"

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
