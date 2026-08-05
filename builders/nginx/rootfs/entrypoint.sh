#!/bin/sh

# shellcheck disable=SC1091

#set -o errexit
#set -o nounset
#set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /usr/local/bin/scripts/libcommon.sh
. /usr/local/bin/scripts/libnginx.sh

# Default environment from helm charts - It will generate default-env.sh and it should be refered in application env and it must be specified at end the script to overwrite image env values
. /usr/local/bin/scripts/libenv.sh

# Load NGINX environment variables
. /usr/local/bin/scripts/nginx-env.sh

#print_welcome_page

if [[ "$1" = "run.sh" ]]; then
    info "** Starting NGINX setup **"
    /usr/local/bin/scripts/nginx/setup.sh
    info "** NGINX setup finished! **"
fi

echo ""
exec "$@"
