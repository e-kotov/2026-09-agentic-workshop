#!/usr/bin/env bash

set -euo pipefail

command -v jq >/dev/null
command -v herdr >/dev/null
command -v opencode >/dev/null

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

herdr plugin list | grep -F 'cache-hit' >/dev/null
grep -Fq "\$cache" "$CONFIG_HOME/herdr/config.toml"

test -f "$CONFIG_HOME/opencode/opencode.json"
jq -e '
  .provider.workshop.npm == "@ai-sdk/openai-compatible" and
  .provider.workshop.options.baseURL == "https://diw-workshop-proxy.ekotov.workers.dev/v1" and
  .provider.workshop.options.apiKey == "{env:WORKSHOP_API_KEY}" and
  (.provider.workshop.models | keys | sort) == [
    "meta/muse-spark-1.2-contributor",
    "meta/muse-spark-1.3-contributor",
    "zai/glm-5.3-flash"
  ]
' "$CONFIG_HOME/opencode/opencode.json" >/dev/null
test -z "${WORKSHOP_API_KEY:-}"
test ! -e "$HOME/.local/share/opencode/auth.json"

test -f "$CONFIG_HOME/opencode/plugins/cache-hit-tui.tsx"
test -f "$CONFIG_HOME/opencode/plugins/context-dashboard-tui.tsx"
test -f "$CONFIG_HOME/opencode/lib/context-dashboard-logic.mjs"
grep -Fq 'from "../lib/context-dashboard-logic.mjs"' \
  "$CONFIG_HOME/opencode/plugins/context-dashboard-tui.tsx"
jq -e '
  any(.plugin[]; (if type == "array" then .[0] else . end) == "./plugins/cache-hit-tui.tsx") and
  any(
    .plugin[];
    type == "array" and
    .[0] == "./plugins/context-dashboard-tui.tsx" and
    .[1].mode == "compact" and
    .[1].placement == "sidebar"
  )
' "$CONFIG_HOME/opencode/tui.json" >/dev/null

printf 'Participant image OpenCode configuration assertions passed for %s.\n' "$(uname -m)"
