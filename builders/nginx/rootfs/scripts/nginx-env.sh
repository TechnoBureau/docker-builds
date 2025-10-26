#!/bin/sh
# Environment configuration for nginx
# Load logging library
# shellcheck disable=SC1090,SC1091
. /home/nonroot/scripts/liblog.sh

# Logging configuration
export DEBUG="${DEBUG:-false}"

# Paths
export NGINX_CONF_DIR="/etc/nginx"
export NGINX_SERVER_BLOCKS_DIR="${NGINX_CONF_DIR}/server_blocks"
export NGINX_CONF_FILE="${NGINX_CONF_DIR}/nginx.conf"
export NGINX_PID_FILE="/tmp/nginx.pid"
# Custom environment variables may be defined below
export MODULES_CONF_FOLDER="${NGINX_CONF_DIR}/modules"
export ENABLE_MODULES="${ENABLE_MODULES:-http_headers_more_filter,http_vhost_traffic_status,http_geoip2,http_sticky,http_opentracing,http_ot}"
export NGINX_CERT_PATH="${NGINX_CERT_PATH:-/etc/nginx/certs}"
export NGINX_TEMPLATE_PATH="${NGINX_TEMPLATE_PATH:-${NGINX_CONF_DIR}/templates}"

## Nginx Controller related variables
export NGINX_DEFAULT_TLS_NAME="${NGINX_DEFAULT_TLS_NAME:-server}"

export LOG_LEVEL="${LOG_LEVEL:-}"
export LOG_OUTPUT="${LOG_OUTPUT:-}"

## Helm chart default environment variable values as higher priority, so it must be specified at the end.
if [[ -f "${HOME}/scripts/default-env.sh" ]]; then
    . "${HOME}/scripts/default-env.sh"
fi
