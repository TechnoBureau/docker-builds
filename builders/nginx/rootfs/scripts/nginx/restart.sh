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

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh

/home/nonroot/scripts/nginx/stop.sh
/home/nonroot/scripts/nginx/start.sh
