#!/usr/bin/env bash
#set -Eeuo pipefail

# This script builds a specific image from the docker-builds directory.
#
# Usage: ./build.sh <image-name>
#   - <image-name>: The name of the image to build (e.g., ubi, my-image, etc.)

# Get the absolute path of the script
BUILD_IMG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the main CI script
. "$BUILD_IMG_PATH/../../scripts/build/universal-ci.sh"

DEFAULT_IMAGE_NAME=$(basename "$BUILD_IMG_PATH")
IMAGE_NAME="${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}"

# Call the main build function with the image name and any additional arguments
main_build "$IMAGE_NAME" \
      -d "$BUILD_IMG_PATH/build.yaml" \
      -i "$BUILD_IMG_PATH/Dockerfile" \
      "$@"

exit $?