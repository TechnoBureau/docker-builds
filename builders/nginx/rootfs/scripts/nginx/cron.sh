#!/bin/bash

# shellcheck disable=SC1090,SC1091

#set -o errexit
#set -o pipefail

# Load NGINX environment variables
. /home/nonroot/scripts/nginx-env.sh
. /home/nonroot/scripts/libservice.sh


function cloud_sync(){
  local logs_dir=${1:-${LOGS_PATH}}
  if [[ ${CLOUD_PROVIDER} == "aws" ]]; then
    aws s3 sync ${logs_dir} s3://${LOGS_BKP_STORAGE_NAME}/${APP_NAME}/${LOGS_BKP_TENANT_ID}/${HOSTNAME}/ --exclude "*"  --include "*.gz"  --exclude ".*"
  else
    az storage blob sync -c ${LOGS_BKP_STORAGE_NAME} -s ${logs_dir} -d ${APP_NAME}/${LOGS_BKP_TENANT_ID}/${HOSTNAME}/ --delete-destination false --include-pattern "*.gz"
  fi
}

if [ ! -z ${logbkstatus} ]
then
  if [[ ${logbkstatus} == "enabled" ]]
  then
    ## Required aws cli and az-cli to be installed but currently it doesn't contain
    IFS="," read -a products_list <<< "${PRODUCT_NAME}"
    for pindex in "${!products_list[@]}"
    do
      if ls "${dir}"/*.gz 1> /dev/null 2>&1; then
        cloud_sync "${HOME}/nginx/${products_list[${pindex}]}"
      fi
    done
  fi
fi

## Run logrotate
log_rotate_run "${NGINX_BASE_DIR}"