#!/usr/bin/env bash
# SessionEnd hook — cheap queue write, <200ms. No LLM calls.
#
# The actual distillation runs on the next session's SessionStart via
# on-session-start-drain.sh (asyncRewake). Splitting these two events lets us:
# - stay well inside the SessionEnd teardown window (no background survival issues)
# - persist work across sessions (even if terminal is killed before drain fires)
# - avoid recursion entirely (this hook never spawns another claude process)

set +e
trap 'exit 0' ERR

# Recursion guard: if we're inside a drain-spawned claude -p, skip the queue write.
# (Without this, every drain run would re-queue itself.)
if [[ -n "$SKILL_DRAIN_RUNNING" ]]; then
    exit 0
fi

payload=$(cat)

project_root=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
if [[ -z "$project_root" ]]; then
    # Fallback to PWD (user's project). Script-relative fallback is WRONG here
    # because when shipped via `/plugin install`, $0 resolves to the plugin's
    # install cache, not the user's project.
    project_root="$PWD"
fi

QUEUE_DIR="$project_root/.agentic-sdlc/tmp/trace-queue"
LOG="$project_root/.agentic-sdlc/tmp/skill-distiller.log"
mkdir -p "$QUEUE_DIR" "$(dirname "$LOG")" 2>/dev/null

session_id=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id","unknown"))' 2>/dev/null)
transcript_path=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null)
reason=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("reason",""))' 2>/dev/null)

if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    echo "$(date -Iseconds) queue-skip no-transcript session=$session_id" >> "$LOG"
    exit 0
fi

ts=$(date -u +%Y%m%dT%H%M%SZ)
entry="$QUEUE_DIR/$ts-$session_id.json"

SESSION_ID="$session_id" TRANSCRIPT="$transcript_path" CWD="$project_root" REASON="$reason" QUEUED_AT="$(date -Iseconds)" \
python3 -c '
import json, os
print(json.dumps({
    "session_id":     os.environ["SESSION_ID"],
    "transcript_path": os.environ["TRANSCRIPT"],
    "cwd":            os.environ["CWD"],
    "reason":         os.environ["REASON"],
    "queued_at":      os.environ["QUEUED_AT"],
}))' > "$entry" 2>/dev/null

echo "$(date -Iseconds) queued session=$session_id reason=$reason transcript=$transcript_path" >> "$LOG"
exit 0
