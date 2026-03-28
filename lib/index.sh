#!/usr/bin/env bash

index_add() {
  local name="$1" description="$2" hash="$3"

  # Remove existing entry with same hash if any
  index_remove_by_hash "$hash"

  NAME="$name" DESC="$description" HASH="$hash" \
    yq -i '.layouts += [{"name": env(NAME), "description": env(DESC), "hash": env(HASH)}]' "$TPC_INDEX_FILE"
}

index_remove_by_hash() {
  local hash="$1"
  HASH="$hash" yq -i 'del(.layouts[] | select(.hash == env(HASH)))' "$TPC_INDEX_FILE"
}

index_remove_by_name() {
  local name="$1"
  NAME="$name" yq -i 'del(.layouts[] | select(.name == env(NAME)))' "$TPC_INDEX_FILE"
}

index_get_hash_by_name() {
  local name="$1"
  NAME="$name" yq -r '.layouts[] | select(.name == env(NAME)) | .hash' "$TPC_INDEX_FILE"
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
