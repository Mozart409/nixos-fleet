#!/usr/bin/env bash
# Integration test script for next-wallpaper functionality
# Run with: bash modules/desktop/test-next-wallpaper.sh

set -euo pipefail

TEST_DIR=$(mktemp -d)
STATE_DIR="$TEST_DIR/state"
WALLPAPER_DIR="$TEST_DIR/wallpapers"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== next-wallpaper integration test suite ==="
echo "Test directory: $TEST_DIR"
echo

setup() {
  rm -rf "$STATE_DIR" "$WALLPAPER_DIR"
  mkdir -p "$WALLPAPER_DIR" "$STATE_DIR"
  for i in {1..10}; do
    touch "$WALLPAPER_DIR/wallpaper_$i.jpg"
  done
}

create_script() {
  local script="$1"
  local stateDir="$2"
  local wallpaperDir="$3"
  
  cat > "$script" << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail

wallpaperDir="WALLPAPER_DIR_PLACEHOLDER"
stateDir="STATE_DIR_PLACEHOLDER"
queueFile="$stateDir/queue.txt"
historyFile="$stateDir/history.txt"
currentFile="$stateDir/current.txt"
forwardFile="$stateDir/forward.txt"
lockFile="$stateDir/.lock"
maxHistory=50
awwwCmd="AWWW_CMD_PLACEHOLDER"
notifyCmd="NOTIFY_CMD_PLACEHOLDER"

show_notification() {
  local wallpaper="$1"
  local filename
  filename="$(basename "$wallpaper")"
  $notifyCmd -t 2000 -i "$wallpaper" "Wallpaper" "$filename" || true
}

build_queue() {
  mkdir -p "$stateDir"
  find "$wallpaperDir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -print0 \
    | shuf -z \
    | while IFS= read -r -d "" file; do printf '%s\n' "$file"; done \
    > "$queueFile"
  if [ ! -s "$queueFile" ]; then
    rm -f "$queueFile"
    return 1
  fi
}

reset_queue() {
  rm -f "$queueFile" "$historyFile" "$currentFile" "$forwardFile"
  echo "Queue and history reset."
  exit 0
}

save_current() {
  local wallpaper="$1"
  mkdir -p "$stateDir"
  echo "$wallpaper" > "$currentFile"
}

push_forward() {
  local wallpaper="$1"
  mkdir -p "$stateDir"
  echo "$wallpaper" >> "$forwardFile"
}

show_previous() {
  if [ ! -s "$historyFile" ]; then
    echo "No previous wallpaper in history" >&2
    exit 1
  fi

  if [ -f "$currentFile" ]; then
    current="$(cat "$currentFile")"
    if [ -f "$current" ]; then
      push_forward "$current"
    fi
  fi

  wallpaper="$(tail -n 1 "$historyFile")"
  if [ ! -f "$wallpaper" ]; then
    echo "Previous wallpaper no longer exists: $wallpaper" >&2
    sed -i '$ d' "$historyFile"
    exit 1
  fi
  sed -i '$ d' "$historyFile"
  save_current "$wallpaper"
  if [ $# -eq 0 ]; then
    set -- --transition-type random
  fi
  show_notification "$wallpaper"
  $awwwCmd img "$wallpaper" "$@"
}

add_to_history() {
  local wallpaper="$1"
  mkdir -p "$stateDir"
  echo "$wallpaper" >> "$historyFile"
  local count
  count="$(wc -l < "$historyFile")"
  if [ "$count" -gt "$maxHistory" ]; then
    tail -n "$maxHistory" "$historyFile" > "$historyFile.tmp"
    mv "$historyFile.tmp" "$historyFile"
  fi
}

get_next_wallpaper() {
  while [ -s "$queueFile" ]; do
    wallpaper="$(head -n 1 "$queueFile")"
    tail -n +2 "$queueFile" > "$queueFile.tmp" || true
    if [ -s "$queueFile.tmp" ]; then
      mv "$queueFile.tmp" "$queueFile"
    else
      rm -f "$queueFile.tmp" "$queueFile"
    fi
    if [ -f "$wallpaper" ]; then
      echo "$wallpaper"
      return 0
    fi
  done
  return 1
}

if [ "$#" -gt 0 ] && [ "$1" = "--reset" ]; then
  reset_queue
fi

if [ "$#" -gt 0 ] && [ "$1" = "--previous" ]; then
  shift
  show_previous "$@"
fi

exec 200>"$lockFile"
flock -x 200

if [ -s "$forwardFile" ]; then
  wallpaper="$(tail -n 1 "$forwardFile")"
  sed -i '$ d' "$forwardFile"

  if [ -f "$wallpaper" ]; then
    if [ -f "$currentFile" ]; then
      current="$(cat "$currentFile")"
      if [ -f "$current" ]; then
        add_to_history "$current"
      fi
    fi

    save_current "$wallpaper"

    if [ $# -eq 0 ]; then
      set -- --transition-type random
    fi

    show_notification "$wallpaper"
    $awwwCmd img "$wallpaper" "$@"
  fi
fi

if [ -f "$currentFile" ]; then
  current="$(cat "$currentFile")"
  if [ -f "$current" ]; then
    add_to_history "$current"
  fi
fi

rm -f "$forwardFile"

if [ ! -s "$queueFile" ]; then
  if ! build_queue; then
    echo "next-wallpaper: No wallpapers found in $wallpaperDir" >&2
    exit 1
  fi
fi

wallpaper=""
while true; do
  if ! wallpaper="$(get_next_wallpaper)"; then
    if ! build_queue; then
      echo "next-wallpaper: No valid wallpapers found in $wallpaperDir" >&2
      exit 1
    fi
    continue
  fi
  break
done

save_current "$wallpaper"

if [ $# -eq 0 ]; then
  set -- --transition-type random
fi

show_notification "$wallpaper"
$awwwCmd img "$wallpaper" "$@"
SCRIPT_EOF

  sed -i "s|WALLPAPER_DIR_PLACEHOLDER|$wallpaperDir|g" "$script"
  sed -i "s|STATE_DIR_PLACEHOLDER|$stateDir|g" "$script"
  sed -i "s|AWWW_CMD_PLACEHOLDER|$TEST_DIR/awww|g" "$script"
  sed -i "s|NOTIFY_CMD_PLACEHOLDER|$TEST_DIR/notify-send|g" "$script"
  
  chmod +x "$script"
}

mock_awww() {
  cat > "$TEST_DIR/awww" << 'AWWW_EOF'
#!/bin/bash
echo "awww called with: $@" >> /tmp/test-awww.log
AWWW_EOF
  chmod +x "$TEST_DIR/awww"
}

mock_notify_send() {
  cat > "$TEST_DIR/notify-send" << 'NOTIFY_EOF'
#!/bin/bash
echo "notify: $@" >> /tmp/test-notify.log
NOTIFY_EOF
  chmod +x "$TEST_DIR/notify-send"
}

test_next_creates_queue() {
  echo -n "Test: next-wallpaper creates queue... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  
  if [ ! -s "$STATE_DIR/queue.txt" ]; then
    echo "FAIL: queue.txt not created"
    return 1
  fi
  
  queue_count=$(wc -l < "$STATE_DIR/queue.txt")
  if [ "$queue_count" -lt 9 ]; then
    echo "FAIL: queue should have ~9 wallpapers left, got $queue_count"
    return 1
  fi
  
  echo "PASS"
}

test_next_creates_current() {
  echo -n "Test: next-wallpaper creates current.txt... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  
  if [ ! -f "$STATE_DIR/current.txt" ]; then
    echo "FAIL: current.txt not created"
    return 1
  fi
  
  current=$(cat "$STATE_DIR/current.txt")
  if [ ! -f "$current" ]; then
    echo "FAIL: current.txt points to non-existent file"
    return 1
  fi
  
  echo "PASS"
}

test_next_adds_to_history() {
  echo -n "Test: second next adds first to history... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first_current=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second_current=$(cat "$STATE_DIR/current.txt")
  
  if [ ! -s "$STATE_DIR/history.txt" ]; then
    echo "FAIL: history.txt not created after second next"
    return 1
  fi
  
  history_first=$(head -n 1 "$STATE_DIR/history.txt")
  if [ "$history_first" != "$first_current" ]; then
    echo "FAIL: history should contain first wallpaper"
    return 1
  fi
  
  if [ "$second_current" = "$first_current" ]; then
    echo "FAIL: second wallpaper should be different"
    return 1
  fi
  
  echo "PASS"
}

test_previous_returns_first() {
  echo -n "Test: previous returns to first wallpaper... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  prev=$(cat "$STATE_DIR/current.txt")
  
  if [ "$prev" != "$first" ]; then
    echo "FAIL: previous should return to first wallpaper"
    echo "  first: $first"
    echo "  second: $second"
    echo "  prev: $prev"
    return 1
  fi
  
  echo "PASS"
}

test_previous_twice() {
  echo -n "Test: previous twice goes back two wallpapers... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  third=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  prev1=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  prev2=$(cat "$STATE_DIR/current.txt")
  
  if [ "$prev1" != "$second" ]; then
    echo "FAIL: first previous should return to second"
    echo "  expected: $second"
    echo "  got: $prev1"
    return 1
  fi
  
  if [ "$prev2" != "$first" ]; then
    echo "FAIL: second previous should return to first"
    echo "  expected: $first"
    echo "  got: $prev2"
    return 1
  fi
  
  echo "PASS"
}

test_previous_empty_history_fails() {
  echo -n "Test: previous fails with empty history... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  if "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1; then
    echo "FAIL: should fail with empty history"
    return 1
  fi
  
  echo "PASS"
}

test_deleted_wallpaper_skipped() {
  echo -n "Test: deleted wallpapers are skipped in previous... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second=$(cat "$STATE_DIR/current.txt")
  
  rm -f "$first"
  
  if "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1; then
    echo "FAIL: should fail when previous wallpaper was deleted"
    return 1
  fi
  
  if [ -f "$STATE_DIR/history.txt" ] && grep -q "$first" "$STATE_DIR/history.txt"; then
    echo "FAIL: deleted wallpaper should be removed from history"
    return 1
  fi
  
  echo "PASS"
}

test_reset_clears_all() {
  echo -n "Test: --reset clears all state... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  
  "$TEST_DIR/next-wallpaper" --reset > /dev/null 2>&1 || true
  
  if [ -f "$STATE_DIR/queue.txt" ] || [ -f "$STATE_DIR/history.txt" ] || [ -f "$STATE_DIR/current.txt" ]; then
    echo "FAIL: reset should clear all state files"
    return 1
  fi
  
  echo "PASS"
}

test_queue_exhaustion_rebuilds() {
  echo -n "Test: queue exhaustion triggers rebuild... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  for i in {1..12}; do
    "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  done
  
  history_count=$(wc -l < "$STATE_DIR/history.txt" 2>/dev/null || echo 0)
  
  if [ "$history_count" -lt 10 ]; then
    echo "FAIL: should have cycled through wallpapers, got $history_count in history"
    return 1
  fi
  
  echo "PASS"
}

test_no_duplicates_in_cycle() {
  echo -n "Test: no duplicates in a full cycle... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  seen=""
  for i in {1..10}; do
    "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
    current=$(cat "$STATE_DIR/current.txt")
    if echo "$seen" | grep -qF "$current"; then
      echo "FAIL: duplicate wallpaper in cycle"
      return 1
    fi
    seen="$seen"$'\n'"$current"
  done
  
  echo "PASS"
}

test_forward_stack() {
  echo -n "Test: forward stack allows returning after previous... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  third=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  prev1=$(cat "$STATE_DIR/current.txt")
  
  if [ "$prev1" != "$second" ]; then
    echo "FAIL: first previous should return to second"
    return 1
  fi
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  next1=$(cat "$STATE_DIR/current.txt")
  
  if [ "$next1" != "$third" ]; then
    echo "FAIL: next after previous should return to third (from forward stack)"
    echo "  expected: $third"
    echo "  got: $next1"
    return 1
  fi
  
  echo "PASS"
}

test_forward_stack_multiple() {
  echo -n "Test: forward stack with multiple previous... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  third=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  prev=$(cat "$STATE_DIR/current.txt")
  
  if [ "$prev" != "$first" ]; then
    echo "FAIL: two previous should return to first"
    return 1
  fi
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  next1=$(cat "$STATE_DIR/current.txt")
  
  if [ "$next1" != "$second" ]; then
    echo "FAIL: next should return to second (from forward stack)"
    echo "  expected: $second"
    echo "  got: $next1"
    return 1
  fi
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  next2=$(cat "$STATE_DIR/current.txt")
  
  if [ "$next2" != "$third" ]; then
    echo "FAIL: second next should return to third (from forward stack)"
    echo "  expected: $third"
    echo "  got: $next2"
    return 1
  fi
  
  echo "PASS"
}

test_forward_stack_cleared_on_new_next() {
  echo -n "Test: forward stack cleared when getting new wallpaper... "
  setup
  mock_awww
  mock_notify_send
  rm -f /tmp/test-awww.log /tmp/test-notify.log
  
  create_script "$TEST_DIR/next-wallpaper" "$STATE_DIR" "$WALLPAPER_DIR"
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  first=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  second=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  third=$(cat "$STATE_DIR/current.txt")
  
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  "$TEST_DIR/next-wallpaper" --previous > /dev/null 2>&1 || true
  
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  "$TEST_DIR/next-wallpaper" > /dev/null 2>&1 || true
  
  if [ -s "$STATE_DIR/forward.txt" ]; then
    echo "FAIL: forward stack should be empty after getting new wallpapers"
    return 1
  fi
  
  echo "PASS"
}

main() {
  test_next_creates_queue
  test_next_creates_current
  test_next_adds_to_history
  test_previous_returns_first
  test_previous_twice
  test_previous_empty_history_fails
  test_deleted_wallpaper_skipped
  test_reset_clears_all
  test_queue_exhaustion_rebuilds
  test_no_duplicates_in_cycle
  test_forward_stack
  test_forward_stack_multiple
  test_forward_stack_cleared_on_new_next
  
  echo
  echo "=== All tests passed ==="
}

main
