#!/usr/bin/env bash
# SessionStart hook for the skill evolution loop.
# If any candidates are waiting in .agentic-sdlc/pending/, emit a reminder on
# stdout (surfaced into Claude's session context). Silent when empty. Exit 0.

set +e
trap 'exit 0' ERR

payload=$(cat)

project_root=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
if [[ -z "$project_root" ]]; then
    # Fallback to PWD (user's project). $0 points to plugin install dir when shipped.
    project_root="$PWD"
fi

pending_dir="$project_root/.agentic-sdlc/pending"

# Silent when dir doesn't exist yet.
[[ -d "$pending_dir" ]] || exit 0

# Collect candidate directories (each one has a SKILL.md).
shopt -s nullglob
candidates=()
for d in "$pending_dir"/*/; do
    [[ -f "$d/SKILL.md" ]] && candidates+=("$d")
done
shopt -u nullglob

# Silent when empty.
(( ${#candidates[@]} > 0 )) || exit 0

echo "[skill evolution] ${#candidates[@]} draft skill(s) pending review in .agentic-sdlc/pending/ — run /compound-promote to review and open a PR, or /compound-learn / /compound-evolve to refine manually:"
for d in "${candidates[@]}"; do
    name=$(basename "$d")
    # Extract the description from the SKILL.md frontmatter for context.
    desc=$(python3 -c "
import sys
try:
    with open('$d/SKILL.md') as f:
        content = f.read()
    if content.startswith('---'):
        fm = content.split('---', 2)[1]
        for line in fm.splitlines():
            if line.startswith('description:'):
                print(line.split(':', 1)[1].strip()[:120])
                break
except Exception:
    pass
" 2>/dev/null)
    if [[ -n "$desc" ]]; then
        echo "  - $name — $desc"
    else
        echo "  - $name"
    fi
done

exit 0
