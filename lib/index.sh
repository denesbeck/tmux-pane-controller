#!/usr/bin/env bash

index_add() {
  local name="$1" description="$2" hash="$3"

  # Remove existing entry with same hash if any
  index_remove_by_hash "$hash"

  yq -i ".layouts += [{\"name\": \"$name\", \"description\": \"$description\", \"hash\": \"$hash\"}]" "$TPC_INDEX_FILE"
}

index_remove_by_hash() {
  local hash="$1"
  yq -i "del(.layouts[] | select(.hash == \"$hash\"))" "$TPC_INDEX_FILE"
}

index_remove_by_name() {
  local name="$1"
  yq -i "del(.layouts[] | select(.name == \"$name\"))" "$TPC_INDEX_FILE"
}

index_get_hash_by_name() {
  local name="$1"
  yq ".layouts[] | select(.name == \"$name\") | .hash" "$TPC_INDEX_FILE"
}

index_list() {
  local count
  count=$(yq '.layouts | length' "$TPC_INDEX_FILE")

  if [[ "$count" -eq 0 ]]; then
    echo "No layouts registered."
    return
  fi

  printf "%-25s %-45s %s\n" "NAME" "DESCRIPTION" "HASH"
  printf "%-25s %-45s %s\n" "----" "-----------" "----"

  yq -r '.layouts[] | [.name, .description, .hash] | @tsv' "$TPC_INDEX_FILE" | while IFS=$'\t' read -r name desc hash; do
    printf "%-25s %-45s %.12s\n" "$name" "$desc" "$hash"
  done
}

index_purge() {
  echo "layouts: []" > "$TPC_INDEX_FILE"
}
