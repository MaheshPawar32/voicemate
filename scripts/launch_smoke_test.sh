#!/usr/bin/env bash
# Installs an APK on a connected device/emulator, cold-launches it twice and
# fails if the process dies or logs a FATAL EXCEPTION. A successful compile is
# not proof that the app launches.
set -euo pipefail
APK="${1:?usage: launch_smoke_test.sh <apk>}"
PKG=com.dev.vokey
adb wait-for-device
adb uninstall "$PKG" >/dev/null 2>&1 || true
adb install -r "$APK"
for run in 1 2; do
  adb logcat -c
  adb shell am start -W -n "$PKG/.MainActivity"
  sleep 10
  if adb logcat -d | grep -q "FATAL EXCEPTION"; then
    adb logcat -d | grep -A30 "FATAL EXCEPTION"
    echo "Launch $run crashed"; exit 1
  fi
  if [ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
    echo "Launch $run: process not running"; exit 1
  fi
  echo "Launch $run OK"
  adb shell am force-stop "$PKG"
done
