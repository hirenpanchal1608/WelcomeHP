#!/bin/bash

set -e

echo "In Rollout.io linker wrapper"

clang_path=`/usr/bin/xcrun -f $(basename "$0")`

linker_cmd_file="`echo $@ | sed -e 's/.* -filelist //' -e 's/ -.*//' -e 's/\.[^.]*$//'`".rollout_linker_cmd
{
  echo "$clang_path"
  for ((i=1; i <= $#; i++)); do
    echo "${!i}";
  done
  echo
} > "$linker_cmd_file"

"$clang_path" "$@"
