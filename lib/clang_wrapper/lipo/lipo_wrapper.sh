#!/bin/bash

set -e

lipo_path=`/usr/bin/xcrun -f $(basename "$0")`

for ((i=0; i<$#; i++)); do
  [ "${!i}" == "-output" ] || continue
  let i++
  lipo_output="${!i}"
  break
done
lipo_cmd_file="${lipo_output%/*/*}"/rollout_lipo_cmd
{
  echo "$lipo_path"
  for ((i=1; i <= $#; i++)); do
    echo "${!i}";
  done
} > "$lipo_cmd_file"

"$lipo_path" "$@"
