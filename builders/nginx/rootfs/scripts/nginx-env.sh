#!/bin/bash
# Environment configuration for nginx
# Load logging library (shared prebuildfs lib, see lib/hummingbird/prebuildfs)
# shellcheck source=/usr/local/bin/liblog
. /usr/local/bin/liblog

# Paths consumed by libnginx.sh
export NGINX_CONF_DIR="/etc/nginx"
export NGINX_CONF_FILE="${NGINX_CONF_DIR}/nginx.conf"
export NGINX_PID_FILE="/tmp/nginx.pid"
export NGINX_CERT_PATH="${NGINX_CERT_PATH:-/etc/nginx/certs}"
export NGINX_DEFAULT_TLS_NAME="${NGINX_DEFAULT_TLS_NAME:-server}"
export NGINX_SKIP_SAMPLE_CERTS="${NGINX_SKIP_SAMPLE_CERTS:-false}"
export NGINX_TEMPLATE_PATH="${NGINX_TEMPLATE_PATH:-${NGINX_CONF_DIR}/templates}"
export MODULES_CONF_FOLDER="${MODULES_CONF_FOLDER:-/usr/share/nginx/modules}"

## Helm chart default environment variable values as higher priority, so it must be specified at the end.
if [[ -f "${HOME}/scripts/default-env.sh" ]]; then
    . "${HOME}/scripts/default-env.sh"
fi
