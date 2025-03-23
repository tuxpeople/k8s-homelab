#!/bin/bash
#set -x -e -o pipefail
set -e -o pipefail
export LC_ALL=C

#IN="$1"
IN="$DOCUMENT_WORKING_PATH"

# Check for PDF format
TYPE=$(file -b "$IN")

if [ "${TYPE%%,*}" != "PDF document" ]; then
    echo >&2 "Skipping $IN - non PDF [$TYPE]."
    exit 0
fi

# PDF file - proceed

#PAGES=$(pdfinfo "$IN" | grep ^Pages: | tr -dc '0-9')
PAGES=$(pdfinfo "$IN" | awk '/Pages:/ {print $2}')

echo >&2 Total pages $PAGES

# Threshold for HP scanners
# THRESHOLD=1
# Threshold for Canon MX925
THRESHOLD=1

non_blank() {
    for i in $(seq 1 $PAGES); do
        PERCENT=$(gs -o - -dFirstPage=${i} -dLastPage=${i} -sDEVICE=ink_cov "${IN}" | grep CMYK | nawk 'BEGIN { sum=0; } {sum += $1 + $2 + $3 + $4;} END {  printf "%.5f\n", sum } ')
        echo >&2 -n "Color-sum in page $i is $PERCENT: "
        if awk "BEGIN { exit !($PERCENT > $THRESHOLD) }"; then
            echo $i
            echo >&2 "Page added to document"
        else
            echo >&2 "Page removed from document"
        fi
    done
}

NON_BLANK=$(non_blank)

if [ -n "$NON_BLANK" ]; then
    NON_BLANK=$(echo $NON_BLANK | tr ' ' ",")
    qpdf "$IN" --replace-input --pages . $NON_BLANK --
fi
