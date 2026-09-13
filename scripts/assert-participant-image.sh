#!/usr/bin/env bash

set -euo pipefail

command -v jq >/dev/null
command -v herdr >/dev/null
command -v opencode >/dev/null

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

herdr plugin list | grep -Fq 'cache-hit'
grep -Fq "\$cache" "$CONFIG_HOME/herdr/config.toml"

test -f "$CONFIG_HOME/opencode/plugins/cache-hit-tui.tsx"
jq -e '
  any(
    .plugin[];
    (if type == "array" then .[0] else . end) == "./plugins/cache-hit-tui.tsx"
  )
' "$CONFIG_HOME/opencode/tui.json" >/dev/null

printf 'Participant image cache-observability assertions passed for %s.\n' "$(uname -m)"
