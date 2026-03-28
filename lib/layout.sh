#!/usr/bin/env bash

# Recursively apply a layout tree to tmux panes.
#
# The algorithm:
# 1. Read the node at the given yq path
# 2. If it's a leaf (has "name"), run the command in the target pane
# 3. If it's a container (has "split" + "panes"), split the target pane
#    into N children and recurse into each
#
# When splitting, tmux splits the *remaining* space. So for children
# with sizes [50, 25, 25], the split percentages are:
#   - Skip first child (it keeps the original pane)
#   - Child 2: 25 / (100 - 50) = 50% of remaining
#   - Child 3: 25 / (100 - 50 - 25) = 100% of remaining

apply_layout() {
  local config_file="$1"
  local yq_path="$2"
  local target_pane="$3"

  local has_split
  has_split=$(yq "${yq_path} | has(\"split\")" "$config_file")

  if [[ "$has_split" == "true" ]]; then
    apply_container "$config_file" "$yq_path" "$target_pane"
  else
    apply_leaf "$config_file" "$yq_path" "$target_pane"
  fi
}

apply_leaf() {
  local config_file="$1"
  local yq_path="$2"
  local target_pane="$3"

  local command
  command=$(yq -r "${yq_path}.command // \"\"" "$config_file")

  if [[ -n "$command" ]]; then
    tmux send-keys -t "$target_pane" "$command" C-m
  fi
}

apply_container() {
  local config_file="$1"
  local yq_path="$2"
  local target_pane="$3"

  local split_dir child_count i
  split_dir=$(yq -r "${yq_path}.split" "$config_file")
  child_count=$(yq "${yq_path}.panes | length" "$config_file")

  # Map split direction to tmux flag
  local tmux_split_flag
  if [[ "$split_dir" == "vertical" ]]; then
    tmux_split_flag="-h"  # vertical divider = side by side
  else
    tmux_split_flag="-v"  # horizontal divider = stacked
  fi

  # Collect child sizes
  local -a sizes=()
  for ((i = 0; i < child_count; i++)); do
    local size
    size=$(yq "${yq_path}.panes[$i].size // 50" "$config_file")
    sizes+=("$size")
  done

  # Create panes by splitting.
  # The first child keeps the original pane. Each subsequent child is split
  # off from the original pane. tmux split-window -p N gives N% to the new
  # pane and keeps (100-N)% in the source pane.
  #
  # We split in reverse order so the original pane always represents the
  # "remaining" space for the first children.
  #
  # Example: sizes [50, 25, 25]
  #   Split off last child (25): -p 25 → new gets 25%, original keeps 75%
  #   Split off second child (25): 25/75 = 33% → -p 33 → new gets 25%, original keeps 50%
  #   First child keeps the original pane (50%) — no split needed.

  local -a pane_ids=()
  # Pre-fill array so we can assign by index
  for ((i = 0; i < child_count; i++)); do
    pane_ids+=("")
  done
  pane_ids[0]="$target_pane"

  local remaining=100
  for ((i = child_count - 1; i >= 1; i--)); do
    local split_pct=$(( sizes[i] * 100 / remaining ))

    local new_pane
    new_pane=$(tmux split-window $tmux_split_flag -t "$target_pane" -p "$split_pct" -P -F '#{pane_id}')
    pane_ids[$i]="$new_pane"

    remaining=$((remaining - sizes[i]))
  done

  # Recurse into each child
  for ((i = 0; i < child_count; i++)); do
    apply_layout "$config_file" "${yq_path}.panes[$i]" "${pane_ids[$i]}"
  done
}

load_layout() {
  local config_file="$1"

  # Check if we're inside tmux
  if [[ -z "$TMUX" ]]; then
    echo "Error: tpc must be run inside a tmux session." >&2
    return 1
  fi

  local current_pane
  current_pane=$(tmux display-message -p '#{pane_id}')

  echo "Loading layout..."
  apply_layout "$config_file" ".layout" "$current_pane"
  echo "Layout loaded."
}
