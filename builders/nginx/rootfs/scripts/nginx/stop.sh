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
. /home/nonroot/scripts/libos.sh
. /home/nonroot/scripts/liblog.sh

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh

error_code=0

# https://learnk8s.io/graceful-shutdown
# https://medium.com/codecademy-engineering/kubernetes-nginx-and-zero-downtime-in-production-2c910c6a5ed8

sleep 20

if is_nginx_running; then
    "${NGINX_SBIN_DIR}/nginx" -c "$NGINX_CONF_FILE" -s quit
    QUIET=1 nginx_stop
    if ! retry_while "is_nginx_not_running"; then
        error "nginx could not be stopped"
        error_code=1
    else
        info "nginx stopped"
    fi
else
    info "nginx is not running"
fi

exit "$error_code"
