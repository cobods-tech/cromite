#!/usr/bin/env bash
set -Eeuo pipefail

# Verify a Cromite Android APK before delivery.
# Required: APK path. Optional: EXPECTED_PACKAGE, MIN_VERSION_CODE,
# EXPECTED_CERT_SHA256, REQUIRE_ZH_CN, INSTALL_WITH_ADB.
#
# Example:
# EXPECTED_PACKAGE=org.cromite.cromite \
# EXPECTED_CERT_SHA256=AA:BB:... \
# MIN_VERSION_CODE=1 REQUIRE_ZH_CN=1 \
#   tools/verify-android-apk.sh out/arm64/apks/ChromePublic.apk

APK="${1:?Usage: $0 path/to/ChromePublic.apk}"
EXPECTED_PACKAGE="${EXPECTED_PACKAGE:-org.cromite.cromite}"
MIN_VERSION_CODE="${MIN_VERSION_CODE:-0}"
EXPECTED_CERT_SHA256="${EXPECTED_CERT_SHA256:-}"
REQUIRE_ZH_CN="${REQUIRE_ZH_CN:-1}"
INSTALL_WITH_ADB="${INSTALL_WITH_ADB:-0}"

for tool in apkanalyzer apksigner unzip sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: required tool not found: $tool" >&2
    exit 2
  }
done

[[ -f "$APK" ]] || { echo "ERROR: APK not found: $APK" >&2; exit 2; }

PACKAGE="$(apkanalyzer manifest application-id "$APK")"
VERSION_CODE="$(apkanalyzer manifest version-code "$APK")"
VERSION_NAME="$(apkanalyzer manifest version-name "$APK")"
CERT_OUTPUT="$(apksigner verify --print-certs "$APK")"
CERT_SHA256="$(sed -n 's/.*certificate SHA-256 digest: //p' <<<"$CERT_OUTPUT" | head -n1 | tr '[:lower:]' '[:upper:]')"
APK_SHA256="$(sha256sum "$APK" | awk '{print $1}')"

[[ "$PACKAGE" == "$EXPECTED_PACKAGE" ]] || {
  echo "ERROR: package mismatch: expected $EXPECTED_PACKAGE, got $PACKAGE" >&2
  exit 1
}

[[ "$VERSION_CODE" =~ ^[0-9]+$ ]] || {
  echo "ERROR: invalid versionCode: $VERSION_CODE" >&2
  exit 1
}

(( VERSION_CODE > MIN_VERSION_CODE )) || {
  echo "ERROR: versionCode $VERSION_CODE must be greater than $MIN_VERSION_CODE" >&2
  exit 1
}

if [[ -n "$EXPECTED_CERT_SHA256" && "$CERT_SHA256" != "${EXPECTED_CERT_SHA256^^}" ]]; then
  echo "ERROR: signing certificate mismatch." >&2
  echo "Expected: $EXPECTED_CERT_SHA256" >&2
  echo "Actual:   $CERT_SHA256" >&2
  exit 1
fi

if [[ "$REQUIRE_ZH_CN" == "1" ]]; then
  if ! unzip -Z1 "$APK" | grep -Eiq '(^|/)(zh-CN|zh_CN)(\.pak|/|$)'; then
    echo "ERROR: no zh-CN locale resource found in APK." >&2
    exit 1
  fi
fi

echo "APK verification passed:"
echo "  package:      $PACKAGE"
echo "  versionName:  $VERSION_NAME"
echo "  versionCode:  $VERSION_CODE"
echo "  cert SHA-256: $CERT_SHA256"
echo "  APK SHA-256:  $APK_SHA256"

if [[ "$INSTALL_WITH_ADB" == "1" ]]; then
  command -v adb >/dev/null 2>&1 || {
    echo "ERROR: adb not found." >&2
    exit 2
  }
  adb install -r "$APK"
  adb shell pm path "$PACKAGE"
fi
