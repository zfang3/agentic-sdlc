#!/usr/bin/env bash
# SessionStart asyncRewake hook — drain the trace queue written by SessionEnd.
#
# Wired with `"asyncRewake": true` in hooks/hooks.json. Runs backgrounded.
# On exit 2, stderr is injected into the running session as a system reminder.
#
# Why the /tmp/ staging detour: headless subprocesses spawned via `claude -p`
# cannot write to .claude/ (runtime security feature — agents can't self-modify
# their own config). Shell code CAN write to .claude/. So the distiller writes
# to a /tmp/ staging dir and this shell mirrors staging → .agentic-sdlc/pending/
# after the subprocess returns.

set +e
trap 'exit 0' ERR

# Recursion guard: don't drain from inside a drain-spawned claude -p subprocess.
if [[ -n "$SKILL_DRAIN_RUNNING" ]]; then
    exit 0
fi

payload=$(cat)
project_root=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
if [[ -z "$project_root" ]]; then
    # Fallback to PWD (user's project). $0 points to plugin install dir when shipped.
    project_root="$PWD"
fi

QUEUE_DIR="$project_root/.agentic-sdlc/tmp/trace-queue"
PENDING_DIR="$project_root/.agentic-sdlc/pending"
LOG="$project_root/.agentic-sdlc/tmp/skill-distiller.log"
LOCK="$project_root/.agentic-sdlc/tmp/.drain.lock"
mkdir -p "$(dirname "$LOCK")" "$(dirname "$LOG")" "$PENDING_DIR" 2>/dev/null

# Lockfile: only one drain running at a time.
if [[ -f "$LOCK" ]]; then
    exit 0
fi
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Collect queue entries.
shopt -s nullglob
entries=("$QUEUE_DIR"/*.json)
shopt -u nullglob

if (( ${#entries[@]} == 0 )); then
    exit 0
fi

# Locate claude binary — hook contexts can have minimal PATH.
# Override priority: $CLAUDE_BIN env var → $PATH → common install locations.
# If your install lives somewhere else, set CLAUDE_BIN in your shell or in
# .claude/settings.local.json's `env` block.
if [[ -n "$CLAUDE_BIN" && -x "$CLAUDE_BIN" ]]; then
    : # use as-is
else
    CLAUDE_BIN=$(command -v claude 2>/dev/null)
fi
if [[ -z "$CLAUDE_BIN" ]]; then
    for p in \
        /opt/homebrew/bin/claude \
        /usr/local/bin/claude \
        /usr/bin/claude \
        /snap/bin/claude \
        /run/current-system/sw/bin/claude \
        "$HOME/.npm-global/bin/claude" \
        "$HOME/.local/bin/claude" \
        "$HOME/.bun/bin/claude" \
        "$HOME/.asdf/shims/claude"
    do
        [[ -x "$p" ]] && CLAUDE_BIN="$p" && break
    done
fi
if [[ -z "$CLAUDE_BIN" ]]; then
    echo "$(date -Iseconds) drain-abort claude-not-found (set CLAUDE_BIN to override)" >> "$LOG"
    exit 0
fi

echo "$(date -Iseconds) drain-start entries=${#entries[@]}" >> "$LOG"

processed=0
skipped=0
new_candidates=0
updated_candidates=0

for entry in "${entries[@]}"; do
    transcript_path=$(python3 -c "import json; print(json.load(open('$entry')).get('transcript_path',''))" 2>/dev/null)
    session_id=$(python3 -c "import json; print(json.load(open('$entry')).get('session_id','unknown'))" 2>/dev/null)

    if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
        echo "$(date -Iseconds) drain-entry $(basename "$entry") skip=missing-transcript" >> "$LOG"
        rm -f "$entry"
        skipped=$((skipped + 1))
        continue
    fi

    # Low-signal gate: skip transcripts with <N user turns. Tolerate whitespace
    # variation in the JSONL serialization ("type":"user" or "type": "user").
    # Threshold is configurable via SKILL_DISTILLER_MIN_TURNS (default 2).
    min_turns="${SKILL_DISTILLER_MIN_TURNS:-2}"
    user_turns=$(grep -cE '"type"[[:space:]]*:[[:space:]]*"user"' "$transcript_path" 2>/dev/null || echo 0)
    if [[ "$user_turns" =~ ^[0-9]+$ ]] && (( user_turns < min_turns )); then
        echo "$(date -Iseconds) drain-entry $(basename "$entry") skip=low-signal turns=$user_turns min=$min_turns" >> "$LOG"
        rm -f "$entry"
        skipped=$((skipped + 1))
        continue
    fi

    # Staging dir: the distiller writes here; we mirror into .agentic-sdlc/pending/
    # after it returns (subprocess writes to .claude/ are blocked by runtime).
    STAGING="/tmp/skill-distiller-$session_id-$$"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"

    echo "$(date -Iseconds) drain-entry $(basename "$entry") distill transcript=$transcript_path staging=$STAGING" >> "$LOG"

    SKILL_DRAIN_RUNNING=1 "$CLAUDE_BIN" -p "Run the skill-distiller procedure.

Inputs:
- Transcript: $transcript_path
- Project root: $project_root
- Staging dir (WRITE YOUR OUTPUTS HERE, NOT TO .claude/): $STAGING

Follow your agent instructions precisely. Default to skip." \
        --agent skill-distiller \
        --dangerously-skip-permissions \
        --add-dir "$project_root" \
        --add-dir "$STAGING" \
        >> "$LOG" 2>&1
    rc=$?

    # Mirror staging → .agentic-sdlc/pending/. Shell can write to .claude/.
    for slug_dir in "$STAGING"/*/; do
        [[ -d "$slug_dir" ]] || continue
        slug=$(basename "$slug_dir")
        target="$PENDING_DIR/$slug"

        if [[ -d "$target" ]]; then
            # Existing candidate → overwrite files present in staging (typically just v0_evidence.md).
            for f in "$slug_dir"*; do
                [[ -f "$f" ]] || continue
                cp "$f" "$target/$(basename "$f")"
            done
            updated_candidates=$((updated_candidates + 1))
            echo "$(date -Iseconds) drain-mirror update slug=$slug" >> "$LOG"
        else
            # New candidate → create the dir and copy all staged files in.
            mkdir -p "$target"
            cp "$slug_dir"/* "$target/" 2>/dev/null
            new_candidates=$((new_candidates + 1))
            echo "$(date -Iseconds) drain-mirror new slug=$slug" >> "$LOG"
        fi
    done

    rm -rf "$STAGING"
    echo "$(date -Iseconds) drain-entry $(basename "$entry") done rc=$rc" >> "$LOG"
    rm -f "$entry"
    processed=$((processed + 1))
done

total_pending=$(find "$PENDING_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
echo "$(date -Iseconds) drain-end processed=$processed skipped=$skipped new=$new_candidates updated=$updated_candidates total_pending=$total_pending" >> "$LOG"

# Wake Claude if we produced new candidates. Silent exit 0 otherwise.
# (Updated-only runs don't wake — nothing new for the user to review.)
if (( new_candidates > 0 )); then
    pending_names=$(find "$PENDING_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | tr '\n' ' ')
    echo "[skill evolution] Distilled $processed previous session(s) in the background — $new_candidates new candidate(s) in .agentic-sdlc/pending/ (current pending: $pending_names). Run /compound-promote to review." >&2
    exit 2
fi

exit 0
