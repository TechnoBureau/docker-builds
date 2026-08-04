#!/usr/bin/env bash
#set -Eeuo pipefail

# This script builds a specific image from the docker-builds directory.
#
# Usage: ./build.sh <image-name>
#   - <image-name>: The name of the image to build (e.g., ubi, my-image, etc.)
#
# Environment controls (hummingbird images, env wins over variables.yml):
#   HB_VARIANTS   Space/comma-separated variants to build (default: all
#                 variants from properties.yml, e.g. "default builder").
#                 Example: HB_VARIANTS=default ./build.sh curl
#   HB_TAGS       Space-separated tags to push, overriding the auto-generated
#                 list (default: derived from properties.yml tags + the
#                 detected package version, e.g. "latest 8 8.21 8.21.0").
#                 Example: HB_TAGS="latest 8.21.0" ./build.sh curl
#   HB_VERSION    Overrides the auto-detected package version.
#   HB_REGISTRIES Comma-separated registries to push to, overriding all
#                 variables.yml values (e.g. "ghcr.io/org,quay.io/org").
#   REGISTRY      Overrides a single registry (legacy).
#   SKIP_PUSH     Set to true to build without pushing (variables.yml
#                 skip_push: true is the config-file equivalent).
#   PLATFORMS     Comma-separated archs to build (e.g. "linux/amd64,linux/arm64");
#                 variables.yml platforms: is the config-file equivalent.
#
# Configuration files
#   properties.yml     image identity: main_package, repository, stream,
#                      tags, variants, rpm_packages
#   variables.yml      build controls — SHARED for all builders at
#                      builders/variables.yml, plus optional per-image
#                      builders/<image>/variables.yml deep-merged over it for
#                      additional/override values. Lives in this repo, not in
#                      the code repo (docker-build-scripts).
#   Supported keys (env overrides win):
#     registries:   list of strings ("quay.io/org") or maps
#                   ({name, prefix, push}) — push to several registries
#     registry:     scalar fallback when registries is absent
#     skip_push:    true|false — build without pushing
#     platforms:    list or comma-separated string of archs to build
#     default_variants, default_user, labels, oscap, rpm packages
#   Env overrides: HB_VARIANTS, HB_TAGS, HB_VERSION, HB_REGISTRIES, REGISTRY,
#   SKIP_PUSH, PLATFORMS.

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
