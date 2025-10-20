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


# Unset HTTP_PROXY header to protect vs HTTPPOXY vulnerability
nginx_patch_httpoxy_vulnerability


# This file is necessary for avoiding the error
# "unable to write random state"
# Source: https://stackoverflow.com/questions/94445/using-openssl-what-does-unable-to-write-random-state-mean

# Ensure the .rnd is created in the nonroot HOME
touch "${HOME}/.rnd" && chmod g+rw "${HOME}/.rnd"


