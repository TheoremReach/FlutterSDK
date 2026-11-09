#!/usr/bin/env bash
# The example's integration test on the booted emulator. The tool sometimes never starts the test on an app that has
# started and connected: it waits for the test's isolate to register its service extension, which takes under a second
# when it works, and then waits with no limit of its own. Each launch is a fresh chance, so an attempt that hasn't
# finished in time is stopped and run again, up to three times. The first gets 10 minutes, since it builds the app; the
# others reuse the build and get 5. A test that fails isn't retried. The emulator's log is kept either way, for the
# run's artifact.
set -uo pipefail

attempt=0
for limit in 600 300 300; do
  attempt=$((attempt + 1))
  status=0
  timeout --kill-after=30 "$limit" flutter test integration_test -d emulator-5554 || status=$?
  [ "$status" = 124 ] || break
  echo "::warning::Attempt $attempt of the integration test didn't finish in $((limit / 60)) minutes, so it was stopped."
  adb -s emulator-5554 shell am force-stop com.theoremreach.flutterexample || true
done
adb -s emulator-5554 logcat -d > "$RUNNER_TEMP/logcat.txt" 2>&1 || true
exit "$status"
