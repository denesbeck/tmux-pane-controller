#!/usr/bin/env bash

TPC_CONFIG_DIR="$HOME/.config/tpc"
TPC_INDEX_FILE="$TPC_CONFIG_DIR/index.yml"
TPC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ensure_config_dir() {
  mkdir -p "$TPC_CONFIG_DIR"
  if [[ ! -f "$TPC_INDEX_FILE" ]]; then
    echo "layouts: []" > "$TPC_INDEX_FILE"
  fi
}

get_hash() {
  local dir="$1"
  echo -n "$dir" | b3sum --no-names
}

get_config_file() {
  local hash="$1"
  echo "$TPC_CONFIG_DIR/${hash}.yml"
}

config_exists() {
  local hash
  hash=$(get_hash "$PWD")
  [[ -f "$(get_config_file "$hash")" ]]
}
