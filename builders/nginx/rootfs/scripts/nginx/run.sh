#!/bin/sh

# shellcheck disable=SC1091

set -o errexit
#set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /home/nonroot/scripts/liblog.sh

info "** Starting NGINX **"
exec nginx -g " daemon off;"
