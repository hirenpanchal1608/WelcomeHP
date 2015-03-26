#!/bin/bash

set -e

echo "In Rollout.io linker wrapper ($0)"
export ROLLOUT_LINKER_WRAPPER="$0"

if [ -n "$ROLLOUT_REAL_CLANG" ]; then
  clang_path="$ROLLOUT_REAL_CLANG"
else
  clang_path=`/usr/bin/xcrun -f $(basename "$0")`
fi

linker_cmd_file="`echo $@ | sed -e 's/.* -filelist //' -e 's/ -.*//' -e 's/\.[^.]*$//'`".rollout_linker_cmd
{
  echo "$clang_path"
  for ((i=1; i <= $#; i++)); do
    echo "${!i}";
  done
  echo
} > "$linker_cmd_file"

"$clang_path" "$@"
