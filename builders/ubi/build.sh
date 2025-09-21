#!/usr/bin/env bash
set -Eeuo pipefail
#set -x
BUILD_IMG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Temporarily allow unset variables while sourcing the external script which may reference optional params
set +u
source "$BUILD_IMG_PATH/../../scripts/build/universal-ci.sh"
set -u
main_build ubi $@