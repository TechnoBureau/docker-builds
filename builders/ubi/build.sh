#!/usr/bin/env bash
set -Eeuo pipefail
# set -x
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/universal-ci.sh"
main_build ubi9 $@