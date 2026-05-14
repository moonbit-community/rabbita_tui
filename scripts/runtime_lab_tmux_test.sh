#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/moonbit-tui-runtime-lab-build}"
EXE="${EXE:-/tmp/moonbit-tui-runtime-lab.exe}"
SOCKET="${SOCKET:-/tmp/moonbit-tui-runtime-lab.sock}"
SESSION="runtime-lab"

fail() {
  echo "runtime-lab tmux regression failed: $*" >&2
  tmux -S "$SOCKET" capture-pane -ep -S -200 -t "$SESSION" 2>/dev/null >&2 || true
  tmux -S "$SOCKET" kill-server >/dev/null 2>&1 || true
  exit 1
}

build_example() {
  local output rsp
  output="$(moon run examples/runtime-lab --target native --target-dir "$BUILD_DIR" --build-only)"
  rsp="$(printf '%s\n' "$output" | sed -n 's/.*"\([^"]*runtime-lab\.rspfile\)".*/\1/p')"
  [[ -n "$rsp" ]] || fail "could not locate runtime-lab rspfile"
  grep -v '^-run$' "$rsp" | xargs /usr/bin/cc -o "$EXE"
}

capture() {
  tmux -S "$SOCKET" capture-pane -ep -S -200 -t "$SESSION"
}

assert_screen_contains() {
  local needle="$1"
  local screen
  screen="$(capture)"
  grep -F "$needle" <<<"$screen" >/dev/null ||
    fail "screen did not contain: $needle"
}

wait_screen_contains() {
  local needle="$1"
  local attempts="${2:-30}"
  local delay="${3:-0.1}"
  for _ in $(seq 1 "$attempts"); do
    local screen
    screen="$(capture)"
    if grep -F "$needle" <<<"$screen" >/dev/null; then
      return 0
    fi
    sleep "$delay"
  done
  fail "screen did not contain: $needle"
}

send_literal() {
  tmux -S "$SOCKET" send-keys -t "$SESSION" -l "$1"
}

main() {
  command -v tmux >/dev/null || fail "tmux is required"
  build_example
  tmux -S "$SOCKET" kill-server >/dev/null 2>&1 || true
  tmux -S "$SOCKET" new-session -d -s "$SESSION" -x 88 -y 24 "$EXE"
  wait_screen_contains "runtime-lab" 80 0.1
  wait_screen_contains "Cmd::log/err_log" 80 0.1

  send_literal "p"
  wait_screen_contains "safe stdout/stderr emitted"

  send_literal "$(printf '\033[1;2A')"
  wait_screen_contains "shift+up"

  send_literal "t"
  wait_screen_contains "timed out" 30 0.1

  send_literal "x"
  wait_screen_contains "exec process exit 0" 40 0.1

  tmux -S "$SOCKET" send-keys -t "$SESSION" C-c
  sleep 0.2
  tmux -S "$SOCKET" kill-server >/dev/null 2>&1 || true
}

main "$@"
