#!/bin/bash
BIN_DIR="$(cd "$(dirname "$0")" && pwd )"
BASE_DIR="$(dirname "$BIN_DIR")"
PROJECT_DIR=$(dirname "$BASE_DIR")

if [[ ! -z "$1" ]] ; then
  xcode_dir="$1"
else
  xcode_dir=$(echo "$PROJECT_DIR/"*.xcodeproj)
fi

app_key=$2

"$BIN_DIR"/xcode_ruby_helpers/install.rb << EOF
{
  "xcode_dir": "$xcode_dir",
  "app_key": "$app_key",
  "files_to_add": [
    "Rollout-ios-SDK/Rollout/RolloutDynamic.m",
    "Rollout-ios-SDK/Rollout/Rollout.framework"
  ],
  "sdk_subdir": "Rollout-ios-SDK"
}
EOF
