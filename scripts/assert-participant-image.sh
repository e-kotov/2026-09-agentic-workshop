#!/usr/bin/env bash

set -euo pipefail

command -v jq >/dev/null
command -v herdr >/dev/null
command -v opencode >/dev/null

herdr plugin list | grep -Fq 'cache-hit'
grep -Fq "\$cache" "$HOME/.config/herdr/config.toml"

test -f "$HOME/.config/opencode/plugins/cache-hit-tui.tsx"
jq -e '
  any(
    .plugin[];
    (if type == "array" then .[0] else . end) == "./plugins/cache-hit-tui.tsx"
  )
' "$HOME/.config/opencode/tui.json" >/dev/null

printf 'Participant image cache-observability assertions passed for %s.\n' "$(uname -m)"
