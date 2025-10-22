#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

#set -o errexit
#set -o nounset
#set -o pipefail
#set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /home/nonroot/scripts/libos.sh
. /home/nonroot/scripts/libfs.sh
. /home/nonroot/scripts/libnginx.sh
. /home/nonroot/scripts/liblog.sh
. /home/nonroot/scripts/libentrypoint.sh

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh


# Ensure NGINX is stopped when this script ends
trap "nginx_stop" SIGINT SIGTERM SIGQUIT SIGHUP EXIT

# Configure HTTPS sample block using generated SSL certs
nginx_generate_sample_certs

# Run init scripts
custom_init_scripts


## If LOG_OUTPUT is unset or other than file then it will be redirected to stdout, else file level logging.
if [[ -z "${LOG_OUTPUT}" || "${LOG_OUTPUT}" != "file" ]]; then
  ln -sf "/proc/1/fd/1" "/var/log/nginx/nginx.log"
  ln -sf "/proc/1/fd/2" "/var/log/nginx/error.log"
else
  touch "/var/log/nginx/nginx.log"
  touch "/var/log/nginx/error.log"
fi


## Check for include directives in nginx.conf and create dummy files if they don't exist
nginx_ensure_includes_exist

## Configure Nginx Module which needs to be running
configure_nginx_module


