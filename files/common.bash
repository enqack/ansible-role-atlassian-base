
add_env_var_to_user() {
  local var=$1
  local value=$2
  local user=$3

  echo "export $var=\"$value\"" >> "/home/$user/.profile"
}

add_run_user_env_var() {
  local var=$1
  local value=$2

  add_env_var_to_user "$var" "$value" "$RUN_USER"
}

create_container_metadata_config() {
  add_env_var_to_user CONTEXT_PATH "$CONTEXT_PATH" consul
  add_env_var_to_user SCHEME "$SCHEME" consul
  add_env_var_to_user PORT "$PORT" consul
  add_env_var_to_user PROXY_NAME "$PROXY_NAME" consul
  add_env_var_to_user PROXY_PORT "$PROXY_PORT" consul
}

set_setenv_property() {
  local property=$1
  local value=$2

  sed -i -e "s#^$property.*#$property=\"$value\"#g" ${INSTALL_DIR}/bin/setenv.sh
}

## used by crowd's custom-launch.sh
config_line() {
    local key="$(echo $2 | sed -e 's/[]\/()$*.^|[]/\\&/g')"
    if [ -n "$3" ]; then
      local value="$(echo $3 | sed -e 's/[\/&]/\\&/g')"
      sed -i -e "s/^$key\s*=\s*.*/$key=$value/" $1
    else
      sed -n -e "s/^$key\s*=\s*//p" $1
    fi
}



log() {
  local message="$1"
  local priority="${2:-local0.notice}"
  logger -t $(basename "$0") "$message"
}

## The levels are, in order of decreasing importance:
log_emerg() {
  log "$1" "${2:-daemon}.emerg"
}

log_alert() {
  log "$1" "${2:-daemon}.alert"
}

log_crit() {
  log "$1" "${2:-daemon}.crit"
}

log_err() {
  log "$1" "${2:-daemon}.err"
}

log_warn() {
  log "$1" "${2:-daemon}.warning"
}

log_notice() {
  log "$1" "${2:-daemon}.notice"
}

log_info() {
  log "$1" "${2:-daemon}.info"
}

log_debug() {
  log "$1" "${2:-daemon}.debug"
}
