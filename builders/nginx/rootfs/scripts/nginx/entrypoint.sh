#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

#set -o errexit
#set -o nounset
#set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /home/nonroot/scripts/libcommon.sh
. /home/nonroot/scripts/libnginx.sh

# Default environment from helm charts - It will generate default-env.sh and it should be refered in application env and it must be specified at end the script to overwrite image env values
. /home/nonroot/scripts/libenv.sh

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh

#print_welcome_page

if [[ "$1" = "run.sh" ]]; then
    info "** Starting NGINX setup **"
    /home/nonroot/scripts/nginx/setup.sh
    info "** NGINX setup finished! **"
fi

echo ""
exec "$@"
