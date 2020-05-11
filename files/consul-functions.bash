put_consul_kv() {
  local key_path=$1
  local data=$2

  # echo "$key_path = $data"

  ## Put data in key path on consul key value store
  local response=$(curl -s -X PUT -d "$data" ${key_path})

  if [ "$response" == "true" ]; then
    return 0
  fi

  return 1
}

add_container_metadata() {
  local kv_prefix=${1:-"http://$(hostname -i):8500/v1/kv/atlas-service"}

  log_info "Setting container metadata in consul cluster."

  ## Add container hostname to $kv_prefix/<hostname>/hostname
  put_consul_kv $kv_prefix/$HOSTNAME/hostname "$HOSTNAME"

  ## Add tomcat protocol scheme to $kv_prefix/<hostname>/scheme
  put_consul_kv $kv_prefix/$HOSTNAME/scheme "$SCHEME"

  ## Add tomcat port to $kv_prefix/<hostname>/port
  put_consul_kv $kv_prefix/$HOSTNAME/port "$PORT"

  ## Add tomcat context path to $kv_prefix/<hostname>/context_path
  put_consul_kv $kv_prefix/$HOSTNAME/context_path "$CONTEXT_PATH"

  ## Add Atlassian product's base URL to $kv_prefix/<hostname>/base_url
  put_consul_kv $kv_prefix/$HOSTNAME/base_url "${SCHEME}://${PROXY_NAME}${CONTEXT_PATH}"
}

consul_cluster_up() {
  local health_response=$(curl -s http://$(hostname -i):8500/v1/health/service/consul)
  local health_status=$(echo $health_response | jq '.[].Checks[] | select( .Status == "passing") | .Status')
  # echo $health_response

  if [ "$health_status" == "passing" ]; then
    log_info "Consul cluster is up!"
    return 0
  fi

  return 1
}

container_metadata_exist() {
  local kv_prefix=${1:-"http://$(hostname -i):8500/v1/kv/atlas-service"}
  local response=$(curl -s "$kv_prefix/${HOSTNAME}")

  echo $response
}

wait_for_consul_cluster_and_add_container_metadata() {
  local kv_url="http://$(hostname -i):8500/v1/kv"

  while [[ ! consul_cluster_up ]]; do
    log_warn "Waiting for consul cluster..."
    sleep 3
  done

  sleep 1

  # container_metadata_exist

  add_container_metadata

  return 0
}

update_consul_config_file() {

  log_info "Updating Consul configuration with service definition."

cat > /etc/consul/service.json <<-EOF
{
  "service": {
    "name": "$(hostname -s)",
    "tags": ["starting"],
    "address": "$(hostname -i)",
    "port": $PORT,
    "enableTagOverride": false,
    "checks": [
      {
        "tcp": "localhost:${PORT}",
        "interval": "30s"
      }
    ]
  }
}
EOF
}
