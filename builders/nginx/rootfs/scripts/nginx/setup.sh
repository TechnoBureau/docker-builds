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

# Ensure NGINX environment variables settings are valid
# nginx_validate

# Ensure NGINX is stopped when this script ends
trap "nginx_stop" EXIT

# Ensure NGINX daemon user exists when running as 'root'
am_i_root && ensure_user_exists "$NGINX_DAEMON_USER" --group "$NGINX_DAEMON_GROUP"

# Ensure non-root user has write permissions on a set of directories - Runtime Folder creation
for dir in "$NGINX_VOLUME_DIR" "$NGINX_CONF_DIR" "$NGINX_INITSCRIPTS_DIR" "$NGINX_SERVER_BLOCKS_DIR" "$NGINX_LOGS_DIR" "$NGINX_TMP_DIR" "${NGINX_CONF_BASE_PATH}" "${NGINX_SECRET_PATH}" "${NGINX_CERT_PATH}" "${NGINX_TEMPLATE_PATH}"; do
    #echo "checking .. $dir folder existence"
    ensure_dir_exists "$dir"
    #chmod -R g+rwX "$dir"
done

# Configure HTTPS sample block using generated SSL certs
nginx_generate_sample_certs

# Run init scripts
custom_init_scripts

# Fix logging issue when running as root
! am_i_root || chmod o+w "$(readlink /dev/stdout)" "$(readlink /dev/stderr)"

# Configure HTTPS port number
if [[ -f "${NGINX_CONF_DIR}/certs/server.crt" ]] && [[ -n "${NGINX_HTTPS_PORT_NUMBER:-}" ]] && [[ ! -f "${NGINX_SERVER_BLOCKS_DIR}/default-https-server-block.conf" ]] && is_file_writable "${NGINX_SERVER_BLOCKS_DIR}/default-https-server-block.conf"; then
    cp "${ROOT_DIR}/scripts/nginx/templates/default-https-server-block.conf" "${NGINX_SERVER_BLOCKS_DIR}/default-https-server-block.conf"
fi

if [[ ! -f "${NGINX_CONF_DIR}/mime.types" ]] && [[ -f "${NGINX_ROOT_DIR}/mime.types" ]]; then
 ln -s "${NGINX_ROOT_DIR}/mime.types" "${NGINX_CONF_DIR}/mime.types"
fi

## logs backup intiialization
function add_log_archive_softlinks {
  DATE=$(date '+%Y-%m-%d-%H-%M-%S')

  IFS="," read -a products_list <<< "${PRODUCT_NAME}"

  for pindex in "${!products_list[@]}"
  do
    if test -L "${NGINX_LOGS_DIR}/${products_list[${pindex}]}"
    then
      info "${NGINX_LOGS_DIR}/${products_list[${pindex}]} is a soft link. Skipping..."
    else
      info "Adding common logging softlinks for ${NGINX_LOGS_DIR}/${products_list[${pindex}]}..."

      rm -rf "${NGINX_LOGS_DIR}/${products_list[${pindex}]}"
      # if [ ! -d "${NGINX_LOGS_DIR}" ]; then
      #   mkdir -p "${NGINX_LOGS_DIR}"
      # fi
      mkdir -p "/opt/softwareag/logs/${products_list[${pindex}]}/${TENANT_NAME}/${NAMESPACE_NAME}/${COMPONENT}/${DATE}/${HOSTNAME}/logs"
      ln -s "/opt/softwareag/logs/${products_list[${pindex}]}/${TENANT_NAME}/${NAMESPACE_NAME}/${COMPONENT}/${DATE}/${HOSTNAME}/logs" "${NGINX_LOGS_DIR}/${products_list[${pindex}]}"

      chmod -R 777 "/opt/softwareag/logs/${products_list[${pindex}]}"
      touch "${NGINX_LOGS_DIR}/${products_list[${pindex}]}/nginx.log"
      touch "${NGINX_LOGS_DIR}/${products_list[${pindex}]}/error.log"
      chmod 777 "${NGINX_LOGS_DIR}/${products_list[${pindex}]}/nginx.log"
      chmod 777 "${NGINX_LOGS_DIR}/${products_list[${pindex}]}/error.log"
    fi
  done
}


#add_log_archive_softlinks

## If LOG_OUTPUT is unset or other than file then it will be redirected to stdout, else file level logging.
if [[ -z "${LOG_OUTPUT}" || "${LOG_OUTPUT}" != "file" ]]; then
  ln -sf "/proc/1/fd/1" "${NGINX_LOGS_DIR}/nginx.log"
  ln -sf "/proc/1/fd/2" "${NGINX_LOGS_DIR}/error.log"
else
  touch "${NGINX_LOGS_DIR}/nginx.log"
  touch "${NGINX_LOGS_DIR}/error.log"
fi

## Enabling Debug logging for the error_log based on Environment variable.
if [[ "${LOG_LEVEL:-}" == "debug" || -n "${LOG_LEVEL:-}" ]]; then
  # Find all .conf files under NGINX_CONF_DIR
  find "${NGINX_CONF_DIR}" -type f -name "*.conf" | while read conf_file; do
    # Use sed to find and replace 'error_log ... ;' with 'error_log ... debug;'
    sed -i 's|error_log \([^;]*\);|error_log \1 debug;|' "$conf_file"
  done
fi


## Check for include directives in nginx.conf and create dummy files if they don't exist
nginx_ensure_includes_exist

## Configure Nginx Module which needs to be running
configure_nginx_module

# Initialize NGINX
nginx_initialize

