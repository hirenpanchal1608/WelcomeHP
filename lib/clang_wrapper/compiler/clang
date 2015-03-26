#!/bin/bash

set -e

echo "In Rollout.io compiler wrapper ($0)"
export ROLLOUT_COMPILER_WRAPPER="$0"

clang_path=`/usr/bin/xcrun -f $(basename "$0")`

if [[ $@ =~ RolloutDynamic.o ]]; then
  obj_path=`echo $@ | sed -e 's/.* -o \(.*RolloutDynamic.o\).*/\1/'`
  {
    echo "$clang_path"
    for ((i=1; i <= $#; i++)); do
      echo "${!i}";
    done
    echo
  } > "${obj_path%o}rollout_compile_cmd"

  m_path=`echo $@ | sed -e 's@.* \(/.*RolloutDynamic.m\).*@\1@'`
  cat < /dev/null > "${m_path%/*}/RolloutSwizzlerDynamic.include"
fi

"$clang_path" "$@"
