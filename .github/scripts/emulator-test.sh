#!/usr/bin/env bash
# The example's integration test on the booted emulator, under a time limit: flutter test waits without end when the
# app never connects to it. The emulator's log is kept either way, for the run's artifact.
set -uo pipefail

status=0
timeout 900 flutter test integration_test -d emulator-5554 || status=$?
adb -s emulator-5554 logcat -d > "$RUNNER_TEMP/logcat.txt" 2>&1 || true
[ "$status" = 124 ] && echo "The integration test didn't finish within 15 minutes."
exit "$status"
