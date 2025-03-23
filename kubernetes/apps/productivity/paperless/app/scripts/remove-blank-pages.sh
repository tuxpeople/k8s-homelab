#!/bin/bash
set -e -o pipefail
export LC_ALL=C

#IN="$1"
IN="$DOCUMENT_WORKING_PATH"

PAGES=$(pdfinfo "$IN" | grep ^Pages: | tr -dc '0-9')
THRESHOLD=0.002

non_blank() {
    for i in $(seq 1 $PAGES); do
        PERCENT=$(gs -o - -dFirstPage=${i} -dLastPage=${i} -sDEVICE=inkcov "${IN}" | grep CMYK | nawk 'BEGIN { sum=0; } {sum += $1 + $2 + $3 + $4;} END { printf "%.5f\n", sum } ')
        if awk "BEGIN { exit !($PERCENT > $THRESHOLD) }"; then
            echo $i
        else
            echo >&2 Color-sum is $PERCENT: will remove blank page $i of $IN
        fi
    done
}

NON_BLANK=$(non_blank)

if [ -n "$NON_BLANK" ]; then
    NON_BLANK=$(echo $NON_BLANK | tr ' ' ",")
    qpdf "$IN" --replace-input --pages . $NON_BLANK --
fi
