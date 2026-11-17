# APK signing and in-place update guarantee

## Non-negotiable Android identity

Every delivered APK must keep:

- Application ID: `org.cromite.cromite`
- The same release signing key and certificate across all releases
- A strictly increasing Android `versionCode`

Changing the application ID or signing certificate can prevent Android from installing an update over the existing app. Do not switch between debug and release keys.

## Required GitHub Actions secrets

The Android release workflow now fails before starting the expensive build unless all of these repository Actions secrets exist:

- `KEYSTORE`: the encrypted release keystore payload expected by the existing build workflow
- `KEYSTORE_PASSPHRASE`: passphrase used to decrypt that payload
- `KEYSTORE_PASSWORD`: Android keystore password
- `CROMITE_PREF_HASH_SEED_BIN`: existing Cromite build secret
- `KEYSTORE_CERT_SHA256`: SHA-256 fingerprint of the certificate belonging to the release key

The certificate fingerprint must be 64 hexadecimal digits. Colons are optional. It is a public certificate fingerprint, not the private key.

## How to obtain the fingerprint

Use the exact release keystore that will be retained for every future build. With the keystore file available locally, run:

```bash
keytool -list -v -keystore cromite.keystore
```

Find the `SHA256:` certificate fingerprint and save that value as the GitHub Actions repository secret `KEYSTORE_CERT_SHA256`.

Do not generate a new keystore just to obtain this value. Do not upload or commit the keystore or its password to the repository. Keep a secure offline backup of the original keystore.

## Automated release checks

Before building, the workflow checks that the five secrets above are present and that the fingerprint has the correct format.

After building the Android arm64 APK, `tools/verify-android-apk.sh` checks:

- application ID equals `org.cromite.cromite`
- `versionCode` is a valid positive integer greater than the configured minimum
- APK signing certificate matches `KEYSTORE_CERT_SHA256`
- a zh-CN locale resource is present
- APK SHA-256 is calculated for artifact integrity

The release workflow sets `REQUIRE_CERT_SHA256=1`, so a missing expected fingerprint is a hard failure. Fingerprint comparison ignores colon separators and letter case.

## What this does not prove yet

No APK has been built or installed by this workflow yet. The first real release must still be tested by installing it over an existing Cromite APK with:

```bash
adb install -r ChromePublic.apk
```

A successful verifier run plus a successful `adb install -r` on a device are the release acceptance criteria. Keep the previous installed APK until the replacement has been confirmed working.

## Build-runner prerequisite (important)

The current `.github/workflows/build_cromite.yaml` is **not a GitHub-hosted `ubuntu-latest` build**. Both jobs select the runner label from the workflow input (default: `ci`, alternative: `dev`). The build job also depends on host-specific Docker images, persistent workspace paths, and mounted directories including `/storage/images` and `/win_sdk`.

This means the workflow requires a compatible self-hosted runner with those labels and the expected Cromite build environment. Merely having a GitHub account, repository write access, or configured Actions secrets is not enough to make the build start. If no matching runner is online, the job remains queued; if a generic runner is substituted without adapting the build environment, the container and volume setup will fail.

Before dispatching the expensive Chromium build, verify all of the following:

1. A self-hosted runner is registered to this repository or organization with the selected label (`ci` or `dev`) and is online.
2. The runner has Docker and the required host directories/volumes used by the workflow.
3. The expected Cromite build images can be pulled or built by that runner.
4. All five release secrets listed above are configured.
5. The first release is built as Android arm64, release mode (`debug=false`), then verified and installed over the existing app.

The repository Actions run list was empty when this checklist was added, so there is no successful or failed build run to use as evidence that the runner environment is already working. Do not claim an APK build is underway until an actual workflow run exists.

A later build-system improvement may replace this inherited custom-runner workflow with a documented cloud build environment. Do not simply change the runner to `ubuntu-latest`: Chromium's source/build footprint and the workflow's custom container/volume assumptions make that an unsafe one-line substitution.

