#!/bin/sh
# shellcheck disable=SC1091

#set -o errexit
#set -o nounset
#set -o pipefail
#set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /tmp/scripts/libos.sh
. /tmp/scripts/libfs.sh
. /tmp/scripts/libnginx.sh
. /tmp/scripts/liblog.sh
. /tmp/scripts/libentrypoint.sh

# Load NGINX environment variables
. /tmp/scripts/nginx-env.sh


# Ensure NGINX is stopped when this script ends
trap "nginx_stop" SIGINT SIGTERM SIGQUIT SIGHUP EXIT

# Configure HTTPS sample block using generated SSL certs
nginx_generate_sample_certs

# Run init scripts
custom_init_scripts


## Check for include directives in nginx.conf and create dummy files if they don't exist
nginx_ensure_includes_exist

## Configure Nginx Module which needs to be running
configure_nginx_module


