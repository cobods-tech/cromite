# Android APK delivery and update compatibility

This document records the non-negotiable release checks for the Chinese UI build.

## Identity

- Android manifest package configured by `build/cromite.gn_args`: `org.cromite.cromite`.
- Keep this package ID unchanged for every update build.
- Do not change the application identity or introduce a second package for V1.

## Signing continuity

- The first user-facing APK must be signed with a project-owned release keystore whose backup is retained securely by the owner.
- Every subsequent APK must be signed with that exact same keystore and signing certificate.
- Never commit keystore files, passwords, private keys, or signing secrets to Git.
- A debug-signed APK is not an acceptable first release if later updates are expected to use a different release key.

## Version continuity

- Every update must have a versionCode strictly greater than the installed versionCode.
- Keep the user-facing version name meaningful, but do not rely on versionName for Android update compatibility.
- Before delivery, compare package name, signing certificate, and versionCode against the previous APK.

## Required pre-delivery checks

1. Build the Android APK from the exact customized branch commit, not an unrelated upstream SHA.
2. Verify the APK package name is `org.cromite.cromite`.
3. Verify the signing certificate matches the retained release keystore.
4. Verify versionCode is greater than the previous delivered build.
5. Verify the APK can be installed over the previous build with `adb install -r` (or equivalent Android package installer update flow).
6. Verify existing app data remains present after the update.
7. Record the source commit, versionCode, certificate fingerprint, architecture, and SHA-256 checksum with each delivered APK.

## Current build infrastructure constraint

The repository's existing `.github/workflows/build_cromite.yaml` is manually dispatched and uses custom runner labels (`dev` / `ci`), custom container images, persistent build volumes, and repository secrets. Its input SHA is described as an upstream `uazo/cromite` SHA. The paired release workflow also checks out `uazo/cromite` and creates the release there, rather than publishing a fork-specific build. Neither workflow is a ready-made build path for this fork's custom branch until both are adapted and the required runner, artifact destination, and signing secrets are confirmed. The fork currently reports no workflow runs.

No APK is considered delivered until all checks above have been completed.