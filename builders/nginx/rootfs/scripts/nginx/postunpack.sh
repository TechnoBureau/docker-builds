#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
#set -o nounset
set -o pipefail
#set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /home/nonroot/scripts/libnginx.sh
. /home/nonroot/scripts/libfs.sh

# Auxiliar Functions

########################
# Unset HTTP_PROXY header to protect vs HTTPPOXY vulnerability
# Ref: https://www.digitalocean.com/community/tutorials/how-to-protect-your-server-against-the-httpoxy-vulnerability
# Globals:
#   NGINX_*
# Arguments:
#   None
# Returns:
#   None
#########################
nginx_patch_httpoxy_vulnerability() {
    debug "Unsetting HTTP_PROXY header..."
    echo '# Unset the HTTP_PROXY header' >>"${NGINX_CONF_DIR}/fastcgi_params"
    echo 'fastcgi_param  HTTP_PROXY         "";' >>"${NGINX_CONF_DIR}/fastcgi_params"
}

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh

# Remove unnecessary directories that come with the tarball
rm -rf "${ROOT_DIR}/certs" "${ROOT_DIR}/server_blocks"
mkdir -p "${NGINX_BASE_DIR}/html"

# Ensure non-root user has write permissions on a set of directories - Build Time Folder Creation
for dir in "$NGINX_VOLUME_DIR" "$NGINX_CONF_DIR" "$NGINX_INITSCRIPTS_DIR" "$NGINX_SERVER_BLOCKS_DIR" "${NGINX_CONF_DIR}/product" "$NGINX_LOGS_DIR" "$NGINX_TMP_DIR" "${NGINX_CONF_BASE_PATH}" "${NGINX_SECRET_PATH}" "${NGINX_CERT_PATH}" "${NGINX_TEMPLATE_PATH}"; do
    #echo "checking .. $dir folder existence"
    ensure_dir_exists "$dir"
    #chmod -R g+rwX "$dir"
done

## Adding mime types while build
#cp "${NGINX_ROOT_DIR}/mime.types" "${NGINX_CONF_DIR}/mime.types"

mv "${ROOT_DIR}/nginx/conf/"* "${NGINX_CONF_DIR}/"
#mv "${ROOT_DIR}/nginx/logrotate.conf" "${HOME}/"

# Unset HTTP_PROXY header to protect vs HTTPPOXY vulnerability
nginx_patch_httpoxy_vulnerability

# Configure default HTTP port
nginx_configure_port "$NGINX_DEFAULT_HTTP_PORT_NUMBER"
# Configure default HTTPS port
nginx_configure_port "$NGINX_DEFAULT_HTTPS_PORT_NUMBER" "${ROOT_DIR}/scripts/nginx/templates/default-https-server-block.conf"

# shellcheck disable=SC1091

# Load additional libraries
. /home/nonroot/scripts/libfs.sh

# Users can mount their html sites at /app
mv "${NGINX_BASE_DIR}/html" /home/nonroot/app/
ln -sf /home/nonroot/app/html "${NGINX_BASE_DIR}/"
##Backward compatability for asserts html
rm -rf /usr/share/nginx/html
ln -sf /home/nonroot/app/html "/usr/share/nginx/"

# Users can mount their certificates at /certs
mv "${NGINX_CERT_PATH}" /home/nonroot/certs
ln -sf /home/nonroot/certs "${NGINX_CERT_PATH}"


# This file is necessary for avoiding the error
# "unable to write random state"
# Source: https://stackoverflow.com/questions/94445/using-openssl-what-does-unable-to-write-random-state-mean

touch ~/.rnd && chmod g+rw ~/.rnd

#generate_cronic_conf logrotate 'logrotate /home/nonroot/logrotate.conf -s /tmp/logrotate.status > /proc/1/fd/1 2>&1' --schedule '*/30 * * * *'

