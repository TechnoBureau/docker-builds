#!/bin/bash
# shellcheck disable=SC1091

set -o errexit
#set -o nounset
set -o pipefail

# Load Generic Libraries
. /home/nonroot/scripts/nginx-env.sh
. /home/nonroot/scripts/libservice.sh

cronic_start