#!/bin/bash

#Exit on error
set -e

#Debug Mode
set -x

#Set the Internal File Separator to newlines & comma only
#IFS=$'\n',
IFS=$'\n'

FAAD=$(which faad)

IN_DIR=~/pCleaner-Input
OUT_DIR=~/pCleaner-Output

# Check that $IN_DIR & $OUT_DIR exist
if [ ! -e "$IN_DIR" ]; then
  mkdir -p "$IN_DIR"
fi

if [ ! -e "$OUT_DIR" ]; then
  mkdir -p "$OUT_DIR"
fi

# Check if this script is running on MacOS, and if so then clean up the Input Directory 
if [ $(uname -s) = Darwin ]; then
  find "$IN_DIR" -name ".DS_Store" -delete
fi

# Check if any new files have been downloaded
if [ -z $(find "$IN_DIR"/ -path "$IN_DIR"/archive -prune -o -type f -print -quit) ]; then
  echo "No files found. Please drop some files in $IN_DIR"
  exit 0
fi

for INFILE in $(find "$IN_DIR"/ -path "$IN_DIR"/archive -prune -o -type f -print); do

  INFILE_FORMAT=$(printf "$INFILE" | cut -d '?' -f 1 | cut -d '.' -f 2)
  if [ "$INFILE_FORMAT" = m4a ]; then
    echo "Unsupported format: m4a. File will be converted."
    "$FAAD" -q "$INFILE"
    rsync --remove-source-files "$INFILE" "$IN_DIR"/archive/
    exec "$0"
  fi
 
    # file has been closed, process it
    FEED_NAME=$(echo "$INFILE" | cut -d "/" -f5)
    EPISODE_TITLE=$(~pcc/.local/bin/greg check -f $FEED_NAME | head -1 | sed "s/^0: //")
    OUTFILE_PATH="$OUT_DIR"/"$FEED_NAME"
    OUTFILE_NAME=$(echo "$INFILE" | cut -d "/" -f6 | cut -d "." -f1)
    AD="0,0.050"
    T=-$(sox -t "$INFILE_FORMAT" "$INFILE" -n stats 2> >(fgrep 'RMS lev dB') | cut -d '-' -f2 | cut -d ' ' -f1)
    R=$(echo "$T" / 3 | bc)
    F=$(echo "$T" \* 3.5 | bc)
    #TIER=basic
    TIER=premium
    #AUDIO_FX_SETTINGS=$(cat ~pcc/pCleaner/sox-"$TIER"-settings)
    if [ "$TIER" = premium ]; then
#        OUTFILE_FORMAT_LIST='mp3
#flac
#wav'
          OUTFILE_FORMAT_LIST='wav'
          else
          OUTFILE_FORMAT_LIST='mp3'
    fi

    # Automatic handling of output formats from a space delimited list
    if [ ! -e "$OUTFILE_PATH" ]; then
      mkdir -p "$OUTFILE_PATH"
    fi

    for OUTFILE_FORMAT in $OUTFILE_FORMAT_LIST; do
      OUTFILE="$OUTFILE_PATH"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"

      AUDIO_FX=$(echo eval $(cat ~pcc/pCleaner/sox-"$TIER"-settings))

      #sox -V --no-clobber -t "$INFILE_FORMAT" "$INFILE" "$OUTFILE" "$AUDIO_FX"
      if [ "$TIER" = premium ]; then
        sox -V --no-clobber -t "$INFILE_FORMAT" "$INFILE" "$OUTFILE" highpass 20 lowpass 20k mcompand "$AD 6:$T,$R -6 $F" 160 "$AD 6:$T,$R -6 $F" 1000 "$AD 6:$T,$R -6 $F" 8000 "$AD 6:$T,$R -6 $F" gain -n -2
      else
        sox -V --no-clobber -t "$INFILE_FORMAT" "$INFILE" "$OUTFILE" $AD 6:$T,$R -6 $F gain -n -2
      fi

    done

  # Prevent future runs against the same file
  rsync --remove-source-files "$INFILE" "$IN_DIR"/archive/

done

unset IFS
