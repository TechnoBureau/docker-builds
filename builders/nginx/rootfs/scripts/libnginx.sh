#!/bin/sh
#
# NGINX library

# shellcheck disable=SC1090,SC1091

# Load Generic Libraries
. /home/nonroot/scripts/libfs.sh
. /home/nonroot/scripts/libfile.sh
. /home/nonroot/scripts/liblog.sh
. /home/nonroot/scripts/libos.sh
. /home/nonroot/scripts/libservice.sh
. /home/nonroot/scripts/libvalidations.sh

# Functions

########################
# Check if NGINX is running
# Globals:
#   NGINX_TMP_DIR
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_nginx_running() {
    local pid
    pid="$(get_pid_from_file "$NGINX_PID_FILE")"
    if [[ -n "$pid" ]]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if NGINX is not running
# Globals:
#   NGINX_TMP_DIR
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_nginx_not_running() {
    ! is_nginx_running
}

########################
# Stop NGINX
# Globals:
#   NGINX_TMP_DIR
# Arguments:
#   None
# Returns:
#   None
#########################
nginx_stop() {
    ! is_nginx_running && return
    info "Stopping NGINX"
    stop_service_using_pid "$NGINX_PID_FILE" "QUIT"
}

########################
# Ensure an NGINX application configuration exists (in server block format)
# Globals:
#   NGINX_*
# Arguments:
#   $1 - App name
# Flags:
#   --type - Application type, which has an effect on what configuration template will be used, allowed values: php, (empty)
#   --hosts - Host listen addresses
#   --server-name - Server name (if not specified, a catch-all server block will be created)
#   --server-aliases - Server aliases
#   --allow-remote-connections - Whether to allow remote connections or to require local connections
#   --disable - Whether to render the app's server blocks with a .disabled prefix
#   --disable-http - Whether to render the app's HTTP server block with a .disabled prefix
#   --disable-https - Whether to render the app's HTTPS server block with a .disabled prefix
#   --http-port - HTTP port number
#   --https-port - HTTPS port number
#   --additional-configuration - Additional server block configuration (no default)
#   --external-configuration - Configuration external to server block (no default)
#   --document-root - Path to document root directory
# Returns:
#   true if the configuration was enabled, false otherwise
########################
ensure_nginx_app_configuration_exists() {
    export app="${1:?missing app}"
    # Default options
    local type=""
    local -a hosts=()
    local server_name
    local -a server_aliases=()
    local allow_remote_connections="yes"
    local disable="no"
    local disable_http="no"
    local disable_https="no"
    # Template variables defaults
    export additional_configuration=""
    export external_configuration=""
    export document_root="${ROOT_DIR}/${app}"
    export http_port="${NGINX_HTTP_PORT_NUMBER:-"$NGINX_DEFAULT_HTTP_PORT_NUMBER"}"
    export https_port="${NGINX_HTTPS_PORT_NUMBER:-"$NGINX_DEFAULT_HTTPS_PORT_NUMBER"}"
    # Validate arguments
    local var_name
    shift
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --hosts | \
            --server-aliases)
            var_name="$(echo "$1" | sed -e "s/^--//" -e "s/-/_/g")"
            shift
            read -r -a "${var_name?}" <<<"$1"
            ;;
        --disable | \
            --disable-http | \
            --disable-https)

            var_name="$(echo "$1" | sed -e "s/^--//" -e "s/-/_/g")"
            export "${var_name?}=yes"
            ;;
        --type | \
            --server-name | \
            --allow-remote-connections | \
            --http-port | \
            --https-port | \
            --additional-configuration | \
            --external-configuration | \
            --document-root | \
            --extra-directory-configuration)

            var_name="$(echo "$1" | sed -e "s/^--//" -e "s/-/_/g")"
            shift
            export "${var_name?}"="$1"
            ;;
        *)
            echo "Invalid command line flag $1" >&2
            return 1
            ;;
        esac
        shift
    done
    # Construct host string in the format of "listen host1:port1", "listen host2:port2", ...
    export http_listen_configuration=""
    export https_listen_configuration=""
    if [[ "${#hosts[@]}" -gt 0 ]]; then
        for host in "${hosts[@]}"; do
            http_listen=$'\n'"listen ${host}:${http_port};"
            https_listen=$'\n'"listen ${host}:${https_port} ssl;"
            [[ -z "${http_listen_configuration:-}" ]] && http_listen_configuration="$http_listen" || http_listen_configuration="${http_listen_configuration}${http_listen}"
            [[ -z "${https_listen_configuration:-}" ]] && https_listen_configuration="$https_listen" || https_listen_configuration="${https_listen_configuration}${https_listen}"
        done
    else
        http_listen_configuration=$'\n'"listen ${http_port} default_server;"
        https_listen_configuration=$'\n'"listen ${https_port} ssl default_server;"
    fi
    # Construct server_name block
    export server_name_configuration=""
    if ! is_empty_value "${server_name:-}"; then
        server_name_configuration="server_name ${server_name}"
        if [[ "${#server_aliases[@]}" -gt 0 ]]; then
            server_name_configuration+=" ${server_aliases[*]}"
        fi
        server_name_configuration+=";"
    else
        server_name_configuration="
# Catch-all server block
# See: https://nginx.org/en/docs/http/server_names.html#miscellaneous_names
server_name _;"
    fi
    # ACL configuration
    export acl_configuration=""
    if ! is_boolean_yes "$allow_remote_connections"; then
        acl_configuration="
default_type text/html;
if (\$remote_addr != 127.0.0.1) {
    return 403 'For security reasons, this URL is only accessible using localhost (127.0.0.1) as the hostname.';
}
# Avoid absolute redirects when connecting through a SSH tunnel
absolute_redirect off;"
    fi
    # Indent configurations
    server_name_configuration="$(indent $'\n'"$server_name_configuration" 4)"
    acl_configuration="$(indent "$acl_configuration" 4)"
    additional_configuration=$'\n'"$(indent "$additional_configuration" 4)"
    external_configuration=$'\n'"$external_configuration"
    http_listen_configuration="$(indent "$http_listen_configuration" 4)"
    https_listen_configuration="$(indent "$https_listen_configuration" 4)"
    # Render templates
    # We remove lines that are empty or contain only newspaces with 'sed', so the resulting file looks better
    local template_name="app"
    [[ -n "$type" && "$type" != "php" ]] && template_name="app-${type}"
    local template_dir="${ROOT_DIR}/scripts/nginx/templates"
    local http_server_block="${NGINX_SERVER_BLOCKS_DIR}/${app}-server-block.conf"
    local https_server_block="${NGINX_SERVER_BLOCKS_DIR}/${app}-https-server-block.conf"
    local -r disable_suffix=".disabled"
    (is_boolean_yes "$disable" || is_boolean_yes "$disable_http") && http_server_block+="$disable_suffix"
    (is_boolean_yes "$disable" || is_boolean_yes "$disable_https") && https_server_block+="$disable_suffix"
    if is_file_writable "$http_server_block"; then
        # Create file with root group write privileges, so it can be modified in non-root containers
        [[ ! -f "$http_server_block" ]] && touch "$http_server_block" && chmod g+rw "$http_server_block"
        render-template "${template_dir}/${template_name}-http-server-block.conf.tpl" | sed '/^\s*$/d' >"$http_server_block"
    elif [[ ! -f "$http_server_block" ]]; then
        error "Could not create server block for ${app} at '${http_server_block}'. Check permissions and ownership for parent directories."
        return 1
    else
        warn "The ${app} server block file '${http_server_block}' is not writable. Configurations based on environment variables will not be applied for this file."
    fi
    if is_file_writable "$https_server_block"; then
        # Create file with root group write privileges, so it can be modified in non-root containers
        [[ ! -f "$https_server_block" ]] && touch "$https_server_block" && chmod g+rw "$https_server_block"
        render-template "${template_dir}/${template_name}-https-server-block.conf.tpl" | sed '/^\s*$/d' >"$https_server_block"
    elif [[ ! -f "$https_server_block" ]]; then
        error "Could not create server block for ${app} at '${https_server_block}'. Check permissions and ownership for parent directories."
        return 1
    else
        warn "The ${app} server block file '${https_server_block}' is not writable. Configurations based on environment variables will not be applied for this file."
    fi
}

########################
# Generate sample TLS certificates without passphrase for sample HTTPS server_block
# Globals:
#   NGINX_*
# Arguments:
#   None
# Returns:
#   None
#########################
nginx_generate_sample_certs() {
    local certs_dir="${NGINX_CERT_PATH}"

    if ! is_boolean_yes "$NGINX_SKIP_SAMPLE_CERTS" && [[ ! -f "${certs_dir}/$NGINX_DEFAULT_TLS_NAME.crt" ]]; then
        # Check certificates directory exists and is writable
        if [[ -d "$certs_dir" && -w "$certs_dir" ]]; then

            if [[ ! -z "$NAMESPACE_NAME" ]]; then
                local namespace_name="-$NAMESPACE_NAME"
            fi
            SSL_KEY_FILE="${certs_dir}/${NGINX_DEFAULT_TLS_NAME}${namespace_name}.key"
            SSL_CERT_FILE="${certs_dir}/${NGINX_DEFAULT_TLS_NAME}${namespace_name}.crt"
            SSL_CSR_FILE="${certs_dir}/${NGINX_DEFAULT_TLS_NAME}${namespace_name}.csr"
            SSL_SUBJ="/CN=example.com"
            SSL_EXT="subjectAltName=DNS:example.com,DNS:www.example.com,IP:127.0.0.1"
            rm -f "$SSL_KEY_FILE" "$SSL_CERT_FILE"
            if command -v "openssl" >/dev/null; then
                openssl genrsa -out "$SSL_KEY_FILE" 4096
                # OpenSSL version 1.0.x does not use the same parameters as OpenSSL >= 1.1.x
                if [[ "$(openssl version | grep -oE "[0-9]+\.[0-9]+")" == "1.0" ]]; then
                    openssl req -new -sha256 -out "$SSL_CSR_FILE" -key "$SSL_KEY_FILE" -nodes -subj "$SSL_SUBJ"
                else
                    openssl req -new -sha256 -out "$SSL_CSR_FILE" -key "$SSL_KEY_FILE" -nodes -subj "$SSL_SUBJ" -addext "$SSL_EXT"
                fi
                openssl x509 -req -sha256 -in "$SSL_CSR_FILE" -signkey "$SSL_KEY_FILE" -out "$SSL_CERT_FILE" -days 1825 -extfile <(echo -n "$SSL_EXT")
                rm -f "$SSL_CSR_FILE"
            else
                warn "openssl not found, skipping sample HTTPS certificates generation"
            fi
        else
            warn "The certificates directories '${certs_dir}' does not exist or is not writable, skipping sample HTTPS certificates generation"
        fi
    fi
}

########################
# Parse nginx.conf and check for include files (static and wildcard patterns)
# Globals:
#   NGINX_CONF_FILE
#   NGINX_TEMPLATE_PATH
# Arguments:
#   None
# Returns:
#   None
#########################
function nginx_ensure_includes_exist {
  info "Checking for include files in nginx.conf..."

  # Check if nginx.conf exists
  if [[ ! -f "${NGINX_CONF_FILE}" ]]; then
    warn "nginx.conf not found at ${NGINX_CONF_FILE}, skipping include check"
    return
  fi

  # Process static include files
  process_static_includes

  # Process wildcard include patterns
  process_wildcard_includes

  # Process template files
  process_template_files

  # Check for mime.types which is commonly included
  if [[ ! -f "${NGINX_CONF_DIR}/mime.types" ]] && [[ ! -f "${NGINX_ROOT_DIR}/mime.types" ]]; then
    info "Creating placeholder mime.types file..."
    ensure_dir_exists "$(dirname "${NGINX_CONF_DIR}/mime.types")"
    echo "# Placeholder mime.types file" > "${NGINX_CONF_DIR}/mime.types"
  fi
}

########################
# Process static include files from nginx.conf
# Globals:
#   NGINX_CONF_FILE
# Arguments:
#   None
# Returns:
#   None
#########################
function process_static_includes {
  # Parse nginx.conf for static include directives (no wildcards)
  local static_include_files
  static_include_files=$(grep -o 'include\s\+[^*;]*;' "${NGINX_CONF_FILE}" | sed 's/include\s\+//g' | sed 's/;//g' | tr -d '"' | tr -d "'")

  # Process each static include file
  while IFS= read -r include_file; do
    # Skip empty lines
    [[ -z "${include_file}" ]] && continue

    # Skip lines with wildcards (handled separately)
    [[ "${include_file}" == *"*"* ]] && continue

    # Get absolute path
    local include_path
    if [[ "${include_file}" == /* ]]; then
      # Already an absolute path
      include_path="${include_file}"
    else
      # Relative path - assume relative to NGINX_CONF_DIR
      include_path="${NGINX_CONF_DIR}/${include_file}"
    fi

    # Check if the file exists
    if [[ ! -f "${include_path}" ]]; then
      info "Creating placeholder file for ${include_path}..."
      ensure_dir_exists "$(dirname "${include_path}")"
      echo "# Placeholder file for nginx include: ${include_file}" > "${include_path}"
    fi
  done <<< "${static_include_files}"
}

########################
# Process wildcard include patterns from nginx.conf
# Globals:
#   NGINX_CONF_FILE
# Arguments:
#   None
# Returns:
#   None
#########################
function process_wildcard_includes {
  # Parse nginx.conf for wildcard include directives
  local wildcard_include_patterns
  wildcard_include_patterns=$(grep -o 'include\s\+[^;]*\*[^;]*;' "${NGINX_CONF_FILE}" | sed 's/include\s\+//g' | sed 's/;//g' | tr -d '"' | tr -d "'")

  # Process each wildcard include pattern
  while IFS= read -r include_pattern; do
    # Skip empty lines
    [[ -z "${include_pattern}" ]] && continue

    # Extract directory and filename pattern
    local pattern_dir
    local filename_pattern

    if [[ "${include_pattern}" == /* ]]; then
      # Absolute path
      pattern_dir=$(dirname "${include_pattern}")
      filename_pattern=$(basename "${include_pattern}")
    else
      # Relative path - assume relative to NGINX_CONF_DIR
      pattern_dir="${NGINX_CONF_DIR}/$(dirname "${include_pattern}")"
      filename_pattern=$(basename "${include_pattern}")
    fi

    # Create directory if it doesn't exist
    ensure_dir_exists "${pattern_dir}"

    # Check if any files match the pattern
    shopt -s nullglob
    local matching_files=("${pattern_dir}"/${filename_pattern})
    shopt -u nullglob

    # If no matching files exist, create a placeholder file
    if [[ ${#matching_files[@]} -eq 0 || "${matching_files[0]}" == "${pattern_dir}/${filename_pattern}" ]]; then
      # Create a placeholder file that matches the pattern
      # Replace * with "placeholder" in the filename
      local placeholder_filename
      placeholder_filename=$(echo "${filename_pattern}" | sed 's/\*/placeholder/')
      local placeholder_path="${pattern_dir}/${placeholder_filename}"

      info "Creating placeholder file for wildcard pattern ${include_pattern}..."
      echo "# Placeholder file for nginx wildcard include: ${include_pattern}" > "${placeholder_path}"
    fi
  done <<< "${wildcard_include_patterns}"
}

########################
# Process template files (.tmpl) and create corresponding .conf files
# Globals:
#   NGINX_TEMPLATE_PATH
#   NGINX_CONF_DIR
# Arguments:
#   None
# Returns:
#   None
#########################
function process_template_files {
  info "Checking for template files (.tmpl) and creating corresponding .conf files if needed..."

  # Define template directories to check
  local template_dirs=("${NGINX_TEMPLATE_PATH}")

  # Add additional template directories if needed
  if [[ -d "${NGINX_CONF_DIR}/templates" ]]; then
    template_dirs+=("${NGINX_CONF_DIR}/templates")
  fi

  # Check each template directory
  for template_dir in "${template_dirs[@]}"; do
    if [[ ! -d "${template_dir}" ]]; then
      info "Template directory ${template_dir} does not exist, skipping..."
      continue
    fi

    info "Checking template files in ${template_dir}..."

    # Find all .tmpl files in the template directory
    shopt -s nullglob
    local template_files=("${template_dir}"/*.tmpl)
    shopt -u nullglob

    # Process each template file
    for template_file in "${template_files[@]}"; do
      # Get the base name without .tmpl extension
      local base_name=$(basename "${template_file}" .tmpl)

      # Determine the target .conf file path
      local target_dir
      local target_file

      # Check if the filename contains "nginx"
      if [[ "${base_name}" == *"nginx"* ]]; then
        # For nginx templates, put them in conf.d directory
        target_dir="${NGINX_CONF_DIR}/conf.d"
        target_file="${target_dir}/${base_name}.conf"
      else
        # For other templates, put them in the same directory as the template but without .tmpl
        target_dir=$(dirname "${template_file}")
        target_file="${target_dir}/${base_name}"
      fi

      # Create the target file if it doesn't exist
      if [[ ! -f "${target_file}" ]]; then
        info "Creating placeholder file for template ${template_file} at ${target_file}..."
        ensure_dir_exists "${target_dir}"
        echo "# Placeholder file generated from template: ${template_file}" > "${target_file}"
      fi
    done
  done
}

########################
# Enable/Disable Modules
# Arguments:
#   None
# Returns:
#   None
#########################
function configure_nginx_module {
  local enable_module=${1:-"$ENABLE_MODULES"}
  if ! command -v grep >/dev/null || ! command -v sed >/dev/null || ! command -v awk >/dev/null || ! command -v tr >/dev/null; then
    warn "Required tools (grep, sed, awk, tr) not found, skipping NGINX module configuration."
    return 1
  fi
  local modules
  modules="$(grep -oP 'load_module\s+"\K[^"]+' "$MODULES_CONF_FOLDER"/*.conf | sed 's/\.so$//' | sed 's/^ngx_//' | awk -F/ '{print $NF}' | tr '\n' ',' | sed 's/,$//')"

  # Disable all modules and enable required modules
  IFS=',' read -ra all_modules <<< "$modules"
  for module in "${all_modules[@]}"; do
      sed -i "s|^load_module.*${module}.so|#&|" "$MODULES_CONF_FOLDER"/*.conf
  done

  IFS=',' read -ra enable_array <<< "$enable_module"
  for module in "${enable_array[@]}"; do
      sed -i 's|^#\(load_module\s*".*ngx_'${module}'_module\.so"\)|\1|' "$MODULES_CONF_FOLDER"/*.conf
  done
}