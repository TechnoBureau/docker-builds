#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0
#
# Environment configuration for nginx

# The values for all environment variables will be set in the below order of precedence
# 1. Custom environment variables defined below after IBM defaults
# 2. Constants defined in this file (environment variables with no default), i.e. ROOT_DIR
# 3. Environment variables overridden via external files using *_FILE variables (see below)
# 4. Environment variables set externally (i.e. current Bash context/Dockerfile/userdata)

# Load logging library
# shellcheck disable=SC1090,SC1091
. /home/nonroot/scripts/liblog.sh

export ROOT_DIR="/home/nonroot"
export NGINX_ROOT_DIR="/opt/nginx"
export VOLUME_DIR="/home/nonroot/app"

# Logging configuration
export MODULE="${MODULE:-nginx}"
export DEBUG="${DEBUG:-false}"

# By setting an environment variable matching *_FILE to a file path, the prefixed environment
# variable will be overridden with the value specified in that file
nginx_env_vars=(
    NGINX_HTTP_PORT_NUMBER
    NGINX_HTTPS_PORT_NUMBER
    NGINX_SKIP_SAMPLE_CERTS
    NGINX_ENABLE_ABSOLUTE_REDIRECT
    NGINX_ENABLE_PORT_IN_REDIRECT
)
for env_var in "${nginx_env_vars[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        if [[ -r "${!file_env_var:-}" ]]; then
            export "${env_var}=$(< "${!file_env_var}")"
            unset "${file_env_var}"
        else
            warn "Skipping export of '${env_var}'. '${!file_env_var:-}' is not readable."
        fi
    fi
done
unset nginx_env_vars
export WEB_SERVER_TYPE="nginx"

# Paths
export NGINX_BASE_DIR="${ROOT_DIR}/nginx"
export NGINX_VOLUME_DIR="${VOLUME_DIR}/nginx"
export NGINX_SBIN_DIR="${NGINX_SBIN_DIR:-${NGINX_ROOT_DIR}/bin}"
export NGINX_CONF_DIR="/etc/nginx"
export NGINX_HTDOCS_DIR="${NGINX_BASE_DIR}/html"
export NGINX_TMP_DIR="${NGINX_BASE_DIR}/tmp"
export NGINX_LOGS_DIR="/var/log/nginx"
export NGINX_SERVER_BLOCKS_DIR="${NGINX_CONF_DIR}/server_blocks"
export NGINX_INITSCRIPTS_DIR="${ROOT_DIR}/docker-entrypoint-initdb.d"
export NGINX_CONF_FILE="${NGINX_CONF_DIR}/nginx.conf"
export NGINX_PID_FILE="/tmp/nginx.pid"
export PATH="${NGINX_SBIN_DIR}:${ROOT_DIR}/common/bin:${PATH}"

# System users (when running with a privileged user)
export NGINX_DAEMON_USER="sagadmin"
export WEB_SERVER_DAEMON_USER="$NGINX_DAEMON_USER"
export NGINX_DAEMON_GROUP="sagadmin"
export WEB_SERVER_DAEMON_GROUP="$NGINX_DAEMON_GROUP"
export NGINX_DEFAULT_HTTP_PORT_NUMBER="8080"
export WEB_SERVER_DEFAULT_HTTP_PORT_NUMBER="$NGINX_DEFAULT_HTTP_PORT_NUMBER" # only used at build time
export NGINX_DEFAULT_HTTPS_PORT_NUMBER="8443"
export WEB_SERVER_DEFAULT_HTTPS_PORT_NUMBER="$NGINX_DEFAULT_HTTPS_PORT_NUMBER" # only used at build time

# NGINX configuration
export NGINX_HTTP_PORT_NUMBER="${NGINX_HTTP_PORT_NUMBER:-}"
export WEB_SERVER_HTTP_PORT_NUMBER="$NGINX_HTTP_PORT_NUMBER"
export NGINX_HTTPS_PORT_NUMBER="${NGINX_HTTPS_PORT_NUMBER:-}"
export WEB_SERVER_HTTPS_PORT_NUMBER="$NGINX_HTTPS_PORT_NUMBER"
export NGINX_SKIP_SAMPLE_CERTS="${NGINX_SKIP_SAMPLE_CERTS:-false}"
export NGINX_ENABLE_ABSOLUTE_REDIRECT="${NGINX_ENABLE_ABSOLUTE_REDIRECT:-no}"
export NGINX_ENABLE_PORT_IN_REDIRECT="${NGINX_ENABLE_PORT_IN_REDIRECT:-no}"

# Custom environment variables may be defined below
export PRODUCT_NAME="${PRODUCT_NAME:-wmio}"
export TENANT_NAME="${TENANT_NAME:-shared}"
export NAMESPACE_NAME="${NAMESPACE_NAME:-shared}"
export COMPONENT="${SUB_COMPONENT:-${COMPONENT:-nginx}}"
export HOSTNAME="${HOSTNAME:-nginx}"
export MODULES_CONF_FOLDER="${NGINX_CONF_DIR}/conf/modules"
export ENABLE_MODULES="${ENABLE_MODULES:-http_headers_more_filter,http_vhost_traffic_status,http_geoip2,http_sticky,http_opentracing,http_ot}"
export NGINX_CERT_PATH="${NGINX_CERT_PATH:-/etc/ssl/nginx}"
export NGINX_TEMPLATE_PATH="${NGINX_TEMPLATE_PATH:-${NGINX_CONF_DIR}/templates}"
export NGINX_DEFAULT_TLS_NAME="${NGINX_DEFAULT_TLS_NAME:-server}"

## Nginx Controller related variables
export NGINX_CONF_BASE_PATH="${NGINX_CONF_BASE_PATH:-${NGINX_CONF_DIR}/conf.d}"
export NGINX_SECRET_PATH="${NGINX_SECRET_PATH:-/etc/secrets}"
export NGINX_OPERATOR_CLASS_NAME="${NGINX_OPERATOR_CLASS_NAME:-wm-nginx}"
export NGINX_OPERATOR_LOG_LEVEL="${NGINX_OPERATOR_LOG_LEVEL:-0}"
export NGINX_OPERATOR_METRICS_PORT="${NGINX_OPERATOR_METRICS_PORT:-8080}"
export NGINX_DEFAULT_TLS_NAME="${NGINX_DEFAULT_TLS_NAME:-server}"

export LOG_LEVEL="${LOG_LEVEL:-}"
export LOG_OUTPUT="${LOG_OUTPUT:-}"

## Helm chart default environment variable values as higher priority, so it must be specified at the end.
if [[ -f "${HOME}/scripts/default-env.sh" ]]; then
    . "${HOME}/scripts/default-env.sh"
fi
