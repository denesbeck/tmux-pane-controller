# tpc - tmux pane controller

A CLI tool for managing predefined tmux pane layouts. Define your pane structure in YAML, validate it, and load it with a single command.

## Features

- Nested pane layouts with configurable split directions and sizes
- Per-directory layout configs stored in `~/.config/tpc/`
- Directory paths hashed with BLAKE3 for privacy
- Layout validation before loading
- Central index for O(1) layout listing

## Dependencies

- [tmux](https://github.com/tmux/tmux)

## Install

```bash
brew tap denesbeck/tpc
brew install tpc
```

## Usage

```
tpc init                  Create a layout config for the current directory
tpc edit                  Edit the layout config for the current directory
tpc load                  Load the layout for the current directory
tpc load <name>           Load a layout by name
tpc load <path>           Load a layout from a YAML file
tpc check                 Validate the layout for the current directory
tpc check <name|path>     Validate a layout by name or file path
tpc list                  List all registered layouts
tpc remove                Remove the layout for the current directory
tpc remove <name>         Remove a layout by name
tpc purge                 Remove all layouts
```

## Config format

Layouts are YAML files with a recursive tree structure. Each node is either a **container** (has `split` + `panes`) or a **leaf** (has `name` + `command`).

```yaml
layout:
  name: my-layout
  description: "Project dev environment"
  split: vertical
  panes:
    - split: horizontal
      size: 50
      panes:
        - name: editor
          size: 50
          command: "nvim"
        - name: lazygit
          size: 50
          command: "lazygit"
    - split: horizontal
      size: 50
      panes:
        - split: vertical
          size: 50
          panes:
            - name: server
              size: 50
              command: "node server.js"
            - name: client
              size: 50
              command: "node client.js"
        - name: terminal
          size: 50
          command: ""
```

This produces:

```
+---------------------+-----------+-----------+
|                     |  server   |  client   |
|       editor        |           |           |
|       (nvim)        |           |           |
|                     |           |           |
+---------------------+-----------+-----------+
|                     |                       |
|      lazygit        |                       |
|                     |                       |
|                     |                       |
+---------------------+-----------------------+
```

### Rules

- `split` is either `vertical` (left | right) or `horizontal` (top / bottom)
- `size` is a percentage relative to the parent container
- Sizes within a container must sum to 100
- Containers must have at least 2 children
- Nesting depth is unlimited

## Config storage

```
~/.config/tpc/
  index.yml              # central index (name, description, hash)
  <blake3-hash>.yml      # layout configs, one per directory
```

## Companion plugin

Use [tpc-capture](https://github.com/denesbeck/tpc-capture) to capture your current tmux pane layout into a tpc config file.

## License

MIT
