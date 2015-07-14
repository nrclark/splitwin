#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [ $# -eq 0 ]; then
    echo "No arguments supplied" >&2
    exit 1
fi

SOURCE_FILE=$1
EXTENSION=`echo "$1" | grep -Eo '[^.]*$'`

if [[ "$EXTENSION" = "gz" ]] ; then
    gzip -d -f "$SOURCE_FILE"
    exit 0
elif [[ "$EXTENSION" = "xz" ]] ; then
    xz -d -f "$SOURCE_FILE"
    exit 0
elif [[ "$EXTENSION" = "bz2" ]] ; then
    bzip2 -d -f "$SOURCE_FILE"
    exit 0
fi

echo "Unknown file format" >&2
exit 1
