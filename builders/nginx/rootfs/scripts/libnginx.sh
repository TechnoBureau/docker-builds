#!/bin/bash
#
# NGINX library
#
# Loads the shared library set from /usr/local/bin (hummingbird prebuildfs) and
# provides the nginx-specific helpers used by setup.sh / postunpack.sh.

# shellcheck source=/usr/local/bin/liblog
. /usr/local/bin/liblog
# shellcheck source=/usr/local/bin/libfs
. /usr/local/bin/libfs
# shellcheck source=/usr/local/bin/libenv
. /usr/local/bin/libenv

# Functions

########################
# Get process id from pidfile
# Arguments:
#   $1 - pidfile path
# Returns:
#   Process id (empty when the file does not exist)
#########################
get_pid_from_file() {
    local file="${1:?missing pidfile}"
    [[ -f "$file" ]] && cat "$file"
}

########################
# Check if NGINX is running
# Globals:
#   NGINX_PID_FILE
# Returns:
#   Boolean
#########################
is_nginx_running() {
    local pid
    pid="$(get_pid_from_file "$NGINX_PID_FILE")"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

########################
# Check if NGINX is not running
# Globals:
#   NGINX_PID_FILE
# Returns:
#   Boolean
#########################
is_nginx_not_running() {
    ! is_nginx_running
}

########################
# Stop NGINX
# Globals:
#   NGINX_PID_FILE
# Returns:
#   None
#########################
nginx_stop() {
    is_nginx_running || return
    info "Stopping NGINX"
    local pid
    pid="$(get_pid_from_file "$NGINX_PID_FILE")"
    kill -QUIT "$pid" 2>/dev/null || true
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
  if ! command -v openssl >/dev/null; then
    warn "openssl not found, skipping NGINX Sample Certificate generation."
    return 0
  fi
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
  if [[ ! -f "${NGINX_CONF_DIR}/mime.types" ]]; then
    info "Creating placeholder mime.types file..."
    ensure_dir_exists "$(dirname "${NGINX_CONF_DIR}/mime.types")"
    echo "# Placeholder mime.types file" > "${NGINX_CONF_DIR}/mime.types"
  fi
}

########################
# Process static include files from nginx.conf
# Globals:
#   NGINX_CONF_FILE
# Returns:
#   None
#########################
function process_static_includes {
  if ! command -v grep >/dev/null || ! command -v sed >/dev/null || ! command -v awk >/dev/null || ! command -v tr >/dev/null; then
    warn "Required tools (grep, sed, awk, tr) not found, skipping NGINX process_static_includes configuration."
    return 0
  fi
  # Parse nginx.conf for static include directives (no wildcards), skipping
  # commented-out include lines
  local static_include_files
  static_include_files=$(grep -v '^\s*#' "${NGINX_CONF_FILE}" | grep -o 'include\s\+[^*;]*;' | sed 's/include\s\+//g' | sed 's/;//g' | tr -d '"' | tr -d "'")

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
# Returns:
#   None
#########################
function process_wildcard_includes {
  if ! command -v grep >/dev/null || ! command -v sed >/dev/null || ! command -v awk >/dev/null || ! command -v tr >/dev/null; then
    warn "Required tools (grep, sed, awk, tr) not found, skipping NGINX process_wildcard_includes configuration."
    return 0
  fi
  # Parse nginx.conf for wildcard include directives, skipping
  # commented-out include lines
  local wildcard_include_patterns
  wildcard_include_patterns=$(grep -v '^\s*#' "${NGINX_CONF_FILE}" | grep -o 'include\s\+[^;]*\*[^;]*;' | sed 's/include\s\+//g' | sed 's/;//g' | tr -d '"' | tr -d "'")

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
    return 0
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
