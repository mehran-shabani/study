#!/usr/bin/env bash
set -euo pipefail
: "${ANDROID_KEYSTORE_BASE64:?Configure the fixed release key in GitHub Secrets}"
: "${ANDROID_STORE_PASSWORD:?Missing store password}"
: "${ANDROID_KEY_PASSWORD:?Missing key password}"
: "${ANDROID_KEY_ALIAS:?Missing key alias}"
mkdir -p android/signing
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/signing/study-release.jks
printf 'storeFile=signing/study-release.jks\nstorePassword=%s\nkeyPassword=%s\nkeyAlias=%s\n' \
  "$ANDROID_STORE_PASSWORD" "$ANDROID_KEY_PASSWORD" "$ANDROID_KEY_ALIAS" > android/key.properties
chmod 600 android/signing/study-release.jks android/key.properties
