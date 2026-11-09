#!/usr/bin/env bash
# The example's integration test on the booted emulator. The tool finds the app through the Dart VM service address
# the app logs, and sometimes never picks it up, though the app has started and logged it; it then waits with no
# limit of its own. So an attempt that hasn't finished in 10 minutes (one takes 3 to 6, its build included) is
# stopped and run once more; a test that fails isn't retried. The emulator's log is kept either way, for the run's
# artifact.
set -uo pipefail

for attempt in 1 2; do
  status=0
  timeout --kill-after=30 600 flutter test integration_test -d emulator-5554 || status=$?
  [ "$status" = 124 ] || break
  echo "Attempt $attempt of the integration test didn't finish in 10 minutes, so it was stopped."
  adb -s emulator-5554 shell am force-stop com.theoremreach.flutterexample || true
done
adb -s emulator-5554 logcat -d > "$RUNNER_TEMP/logcat.txt" 2>&1 || true
exit "$status"
