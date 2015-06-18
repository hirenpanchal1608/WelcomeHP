#!/bin/bash

set -e

export ROLLOUT_LINKER_WRAPPER="$0"

if [ -n "$ROLLOUT_REAL_CLANG" ]; then
  clang_path="$ROLLOUT_REAL_CLANG"
else
  clang_path=`/usr/bin/xcrun -f $(basename "$0")`
fi

for ((i=0; i<$#; i++)); do
  [ "${!i}" == "-filelist" ] || continue
  let i++
  filelist="${!i}"
  break
done
linker_cmd_file="${filelist%.LinkFileList}".rollout_linker_cmd
{
  echo "$clang_path"
  for ((i=1; i <= $#; i++)); do
    echo "${!i}";
  done
  echo
} > "$linker_cmd_file"

"$clang_path" "$@"
