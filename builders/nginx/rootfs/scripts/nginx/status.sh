#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
#set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /home/nonroot/scripts/libnginx.sh
. /home/nonroot/scripts/liblog.sh

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh

if is_nginx_running; then
    info "nginx is already running"
else
    info "nginx is not running"
fi
