#!/bin/bash

set -e

echo "In Rollout.io lipo wrapper"

lipo_path=`/usr/bin/xcrun -f $(basename "$0")`

lipo_cmd_file="`echo $@ | sed -e 's/^.* -output //' -e 's/ -.*//' -e 's@\(/[^/]*\)\{2\}$@@'`"/rollout_lipo_cmd
{
  echo "$lipo_path"
  for ((i=1; i <= $#; i++)); do
    echo "${!i}";
  done
} > "$lipo_cmd_file"

"$lipo_path" "$@"
