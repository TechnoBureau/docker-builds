#!/usr/bin/env bash
#set -Eeuo pipefail

# This script builds a specific image from the docker-builds directory.
#
# Usage: ./build.sh <image-name>
#   - <image-name>: The name of the image to build (e.g., ubi, my-image, etc.)
#
# Environment controls (hummingbird images):
#   HB_VARIANTS   Space/comma-separated variants to build (default: all
#                 variants from properties.yml, e.g. "default builder").
#                 Example: HB_VARIANTS=default ./build.sh curl
#   HB_TAGS       Space-separated tags to push, overriding the auto-generated
#                 list (default: derived from properties.yml tags + the
#                 detected package version, e.g. "latest 8 8.21 8.21.0").
#                 Example: HB_TAGS="latest 8.21.0" ./build.sh curl
#   HB_VERSION    Overrides the auto-detected package version.
#   REGISTRY      Overrides the registry from variables.yml (e.g. ghcr.io/...).
#   SKIP_PUSH     Set to true to build without pushing.

# Get the absolute path of the script
BUILD_IMG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the main CI script
. "$BUILD_IMG_PATH/../../scripts/build/universal-ci.sh"

DEFAULT_IMAGE_NAME=$(basename "$BUILD_IMG_PATH")
IMAGE_NAME="${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}"

# Call the main build function; flavor (hummingbird) is auto-detected from
# Containerfile.j2 + properties.yml in the builder directory
main_build -i "$IMAGE_NAME" "$@"

exit $?
