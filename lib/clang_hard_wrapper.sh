#!/bin/bash

# This wrapper can be used to work around the swift projects ignoring LD env issue
#
# 1. Save clang location 
#    original_clang_location="`xcrun -f clang`"        
# 2. Unless already installed: 
#     sudo mv "$original_clang_location" "$original_clang_location".real_clang_wrapped_by_Rollout.io
# 3. Create the wrapper link
#     sudo ln -s "<project-Rollout-SDK>"/clang_hard_wrapper.sh "$original_clang_location"
# 4. Add the following line to .rollout/clang_hard_wrapper.config:
#     mkdir ~/.rollout/  && vim ~/.rollout/clang_hard_wrapper.config 
#     <target name>=<absolute path to rollout sdk inside the project>


set -e

[ -z "$ROLLOUT_CLANG_HARD_WRAPPER_printVersionAndExit" ] || {
  echo 1
  exit
}

echo "In Rollout.io clang hard wrapper ($0)"

real_clang="$0".real_clang_wrapped_by_Rollout.io
clang_name=`basename "$0"`

[ -z "$ROLLOUT_REAL_CLANG" -a -z "$ROLLOUT_LINKER_WRAPPER" -a -z "$ROLLOUT_COMPILER_WRAPPER" -a -z "$ROLLOUT_TWEAKER" ] || {
  "$real_clang" "$@"
  exit
}

for ((i=1; i <= $#; i++)); do
  [ "${!i}" == "-filelist" ] || continue

  filelist_arg_index=$(($i + 1))
  target=`basename "${!filelist_arg_index%.LinkFileList}"`

  while read line; do
    t="${line%=*}"
    [ "$target" == "$t" ] || continue
    
    export ROLLOUT_REAL_CLANG=$real_clang
    custom_clang="${line#*=}"/lib//clang_wrapper/linker/$clang_name
    echo "Rollout clang hard wrapper: will execute custom clang ($custom_clang)"
    "$custom_clang" "$@"
    exit
  done < "$HOME"/.rollout/clang_hard_wrapper.config
done

"$real_clang" "$@"
