#!/bin/bash

set -e

export ROLLOUT_COMPILER_WRAPPER="$0"

clang_path=`/usr/bin/xcrun -f $(basename "$0")`

if [[ $@ =~ RolloutDynamic_[0-9]{2}\.o ]]; then
  for ((i=0; i<$#; i++)); do
    [ "${!i}" == "-o" ] || continue
    let i++
    obj_path="${!i}"
    break
  done

  {
    echo "$clang_path"
    for ((i=1; i <= $#; i++)); do
      echo "${!i}";
    done
    echo
  } > "${obj_path%o}rollout_compile_cmd"
fi

"$clang_path" "$@"
