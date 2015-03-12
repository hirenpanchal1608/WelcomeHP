#!/bin/bash

BIN_DIR="$(cd "$(dirname "$0")" && pwd )"
BASE_DIR="$(dirname "$BIN_DIR")"
PROJECT_DIR=$(dirname "$BASE_DIR")

if [[ ! -z "$1" ]] ; then
  xcode_dir="$1"
else
  xcode_dir=$(echo "$PROJECT_DIR/"*.xcodeproj)
fi

"$BIN_DIR"/xcode_ruby_helpers/uninstall.rb "$xcode_dir"
