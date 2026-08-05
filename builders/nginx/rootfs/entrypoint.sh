#!/bin/bash

# shellcheck disable=SC1091

#set -o errexit
#set -o nounset
#set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries (prebuildfs shared libs + nginx additions, all in /usr/local/bin)
# shellcheck source=/usr/local/bin/liblog
. /usr/local/bin/liblog
# shellcheck source=/usr/local/bin/libenv
. /usr/local/bin/libenv

# Dump the current environment to ${HOME}/scripts/default-env.sh so that
# nginx-env.sh can apply it as the highest-priority override
ensure_dir_exists "${HOME}/scripts" || true
env_dump "${HOME}/scripts/default-env.sh" || true

# shellcheck source=/usr/local/bin/libnginx.sh
. /usr/local/bin/libnginx.sh

# Load NGINX environment variables
# shellcheck source=/usr/local/bin/nginx-env.sh
. /usr/local/bin/nginx-env.sh

if [[ "$1" = "run.sh" ]]; then
    info "** Starting NGINX setup **"
    /usr/local/bin/nginx/setup.sh
    info "** NGINX setup finished! **"
fi

echo ""
exec "$@"
