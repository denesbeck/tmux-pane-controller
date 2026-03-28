#!/usr/bin/env bash

validate_layout() {
  local config_file="$1"
  local errors=0

  # Check file exists
  if [[ ! -f "$config_file" ]]; then
    echo "Error: File not found: $config_file" >&2
    return 1
  fi

  # Check valid YAML
  if ! yq '.' "$config_file" > /dev/null 2>&1; then
    echo "Error: Invalid YAML syntax." >&2
    return 1
  fi

  # Check root layout key exists
  local has_layout
  has_layout=$(yq 'has("layout")' "$config_file")
  if [[ "$has_layout" != "true" ]]; then
    echo "Error: Missing root 'layout' key." >&2
    return 1
  fi

  # Check layout has split and panes
  local has_split
  has_split=$(yq '.layout | has("split")' "$config_file")
  if [[ "$has_split" != "true" ]]; then
    echo "Error: Root layout must have a 'split' key." >&2
    return 1
  fi

  local has_panes
  has_panes=$(yq '.layout | has("panes")' "$config_file")
  if [[ "$has_panes" != "true" ]]; then
    echo "Error: Root layout must have a 'panes' key." >&2
    return 1
  fi

  # Recursively validate the tree
  validate_node "$config_file" ".layout" "layout"
}

validate_node() {
  local config_file="$1"
  local yq_path="$2"
  local display_path="$3"
  local errors=0
  local i

  local has_split
  has_split=$(yq "${yq_path} | has(\"split\")" "$config_file")

  if [[ "$has_split" == "true" ]]; then
    validate_container "$config_file" "$yq_path" "$display_path" || errors=1
  else
    validate_leaf "$config_file" "$yq_path" "$display_path" || errors=1
  fi

  return "$errors"
}

validate_leaf() {
  local config_file="$1"
  local yq_path="$2"
  local display_path="$3"
  local errors=0

  # Leaf must have a name
  local name
  name=$(yq -r "${yq_path}.name // \"\"" "$config_file")
  if [[ -z "$name" ]]; then
    echo "Error: ${display_path} — leaf pane missing 'name'." >&2
    errors=1
  fi

  # Leaf should not have panes
  local has_panes
  has_panes=$(yq "${yq_path} | has(\"panes\")" "$config_file")
  if [[ "$has_panes" == "true" ]]; then
    echo "Error: ${display_path} — leaf pane '${name}' should not have 'panes'." >&2
    errors=1
  fi

  return "$errors"
}

validate_container() {
  local config_file="$1"
  local yq_path="$2"
  local display_path="$3"
  local errors=0
  local i

  # Validate split direction
  local split_dir
  split_dir=$(yq -r "${yq_path}.split" "$config_file")
  if [[ "$split_dir" != "vertical" && "$split_dir" != "horizontal" ]]; then
    echo "Error: ${display_path} — 'split' must be 'vertical' or 'horizontal', got '${split_dir}'." >&2
    errors=1
  fi

  # Must have panes
  local has_panes
  has_panes=$(yq "${yq_path} | has(\"panes\")" "$config_file")
  if [[ "$has_panes" != "true" ]]; then
    echo "Error: ${display_path} — container must have 'panes'." >&2
    return 1
  fi

  # Must have at least 2 panes
  local child_count
  child_count=$(yq "${yq_path}.panes | length" "$config_file")
  if [[ "$child_count" -lt 2 ]]; then
    echo "Error: ${display_path} — container must have at least 2 panes, got ${child_count}." >&2
    errors=1
  fi

  # Validate sizes sum to 100
  local total=0
  for ((i = 0; i < child_count; i++)); do
    local size
    size=$(yq "${yq_path}.panes[$i].size // 0" "$config_file")
    if [[ "$size" -le 0 || "$size" -ge 100 ]]; then
      echo "Error: ${display_path}.panes[$i] — 'size' must be between 1 and 99, got ${size}." >&2
      errors=1
    fi
    total=$((total + size))
  done

  if [[ "$total" -ne 100 ]]; then
    echo "Error: ${display_path} — child sizes must sum to 100, got ${total}." >&2
    errors=1
  fi

  # Container should not have a command
  local has_command
  has_command=$(yq "${yq_path} | has(\"command\")" "$config_file")
  if [[ "$has_command" == "true" ]]; then
    echo "Warning: ${display_path} — container has 'command' which will be ignored." >&2
  fi

  # Recurse into children
  for ((i = 0; i < child_count; i++)); do
    local child_name
    child_name=$(yq -r "${yq_path}.panes[$i].name // \"[$i]\"" "$config_file")
    validate_node "$config_file" "${yq_path}.panes[$i]" "${display_path} > ${child_name}" || errors=1
  done

  return "$errors"
}
