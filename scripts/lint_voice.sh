#!/usr/bin/env bash
# Voice lint — scans user-facing Swift UI strings for banned voice patterns.
#
# Per docs/product_direction_2026.md §4. Bans (1) AI-tells, (2) bro-coded
# language, (3) femvertising weight-loss copy, (4) AI-framing language in
# user-facing copy.
#
# Scope: ONLY string literals that appear as arguments to UI string APIs:
#   - Text("...")
#   - Text(verbatim: "...")
#   - ItalicAccentText("...", italic: [...])
#   - .accessibilityLabel("...")
#   - .accessibilityHint("...")
#   - .navigationTitle("...")
#   - Label("...", systemImage: ...)
#
# Skipped: print/os_log debugging, code comments, ExerciseInstructions.swift
# (existing prose corpus with its own review), Workout/ engine internals.
#
# Allowlist a needed hit with `// voice-lint:allow` on the same line.
#
# Usage:
#   Scripts/lint_voice.sh            # report mode — exit 0
#   Scripts/lint_voice.sh --strict   # CI mode — exit 1 on hit

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_DIR="${REPO_ROOT}/PlankApp"
STRICT=0
if [[ "${1:-}" == "--strict" ]]; then STRICT=1; fi

# Files / dirs to skip — existing corpora reviewed separately, or pure code.
SKIP_PATHS=(
  'ExerciseInstructions.swift'   # voice-spoken exercise notes, separate review
  'WorkoutPreset.swift'          # legacy descriptions; flagged separately
  'WorkoutGeneratorSelfCheck.swift'  # debug-only validators
  'ExerciseBankData.swift'       # internal exercise notes
  'DebugAuthView.swift'          # debug-only screen
)

# UI-string API regex — string literal MUST be the argument to one of these.
UI_API_REGEX='(\bText\(|\bText\(verbatim:|\bItalicAccentText\(|\.accessibilityLabel\(|\.accessibilityHint\(|\.navigationTitle\(|\bLabel\("|\.buttonStyle\(.*\bText\()'

# Banned patterns: <regex>|<reason>
PATTERNS=(
  '—|em dash — #1 Gen Z AI-slop tell; use period, comma, or line break'
  '\bdelve\b|generic AI vocab; use concrete verb'
  '\bleverage\b|generic AI vocab; rephrase'
  '\bembrace\b|generic AI vocab; rephrase'
  '\bdive in\b|generic AI vocab; use specific action'
  '\belevate\b|generic AI vocab; rephrase'
  '\balgorithm\b|AI-framing language banned'
  '\bAI-powered\b|AI-framing language banned'
  '\byour data\b|AI-framing language; rephrase as Jeni-voice'
  '\bcrush\b|bro-coded; replace'
  '\bdestroy\b|bro-coded; replace'
  '\bbeast mode\b|bro-coded; remove'
  '\bshred\b|bro-coded; replace'
  '\btorch\b|bro-coded + fatphobic'
  '\bshed (the |those |pounds|fat|weight)\b|fatphobic'
  '\bmelt the fat\b|fatphobic; remove'
  '\bsnatched\b|femvertising-coded'
  '\bsummer body\b|femvertising-coded'
  '\bdream body\b|femvertising-coded'
  '\bbikini body\b|femvertising-coded'
)

hits=0
cd "$SCAN_DIR" || exit 2

# Build a -path '!...' filter for find.
FIND_ARGS=(. -type f -name '*.swift')
for skip in "${SKIP_PATHS[@]}"; do
  FIND_ARGS+=( -not -name "$skip" )
done

# Scan only Swift files matching the find filter.
files=$(find "${FIND_ARGS[@]}" 2>/dev/null)

for entry in "${PATTERNS[@]}"; do
  pattern="${entry%%|*}"
  reason="${entry#*|}"

  matches=""
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Per-file: lines that
    #   contain the banned pattern AND
    #   contain a UI-string API marker AND
    #   are NOT a pure comment line AND
    #   are NOT a print()/os_log() AND
    #   are NOT allowlisted
    out=$(grep -nE "$pattern" "$file" 2>/dev/null \
          | grep -E "$UI_API_REGEX" \
          | grep -vE '^[0-9]+:\s*//' \
          | grep -vE '\bprint\(|\bos_log\(' \
          | grep -vE 'voice-lint:allow' || true)
    if [[ -n "$out" ]]; then
      while IFS= read -r line; do
        matches+="$file:$line"$'\n'
      done <<< "$out"
    fi
  done <<< "$files"

  if [[ -n "$matches" ]]; then
    echo ""
    echo "── pattern: ${pattern}"
    echo "   reason:  ${reason}"
    echo "$matches" | sed 's|^\./|   |'
    count=$(echo -n "$matches" | grep -c '' || true)
    hits=$((hits + count))
  fi
done

echo ""
if [[ $hits -eq 0 ]]; then
  echo "✓ voice lint clean"
  exit 0
else
  echo "✗ ${hits} voice-lint hit(s)"
  if [[ $STRICT -eq 1 ]]; then exit 1; fi
  exit 0
fi
