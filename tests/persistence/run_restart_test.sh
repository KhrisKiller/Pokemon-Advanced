#!/usr/bin/env bash
# Persistence across real application restarts: save in one Godot process, load in another.
# Fails if either process fails its checks or logs an engine/script error.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
status=0
for phase in write verify; do
  out="$("$GODOT" --headless --path . res://tests/persistence/restart_check.tscn -- --phase=$phase 2>&1)"
  code=$?
  echo "$out" | grep -E "RESTART CHECK|SCRIPT ERROR|^ERROR" || true
  if [ $code -ne 0 ]; then
    echo "phase '$phase' exited with $code"; status=1
  fi
  if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR"; then
    echo "phase '$phase' logged engine errors"; status=1
  fi
  [ $status -ne 0 ] && break
done
[ $status -eq 0 ] && echo "Restart persistence test passed."
exit $status
