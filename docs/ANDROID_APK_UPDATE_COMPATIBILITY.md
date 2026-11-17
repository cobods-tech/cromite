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

## Fork-specific build workflow update

The fork's `.github/workflows/build_cromite.yaml` has been adjusted to:
- Build the commit selected by the current workflow dispatch branch (`github.sha`) instead of requiring an upstream `uazo/cromite` SHA.
- Pass `github.repository` into the Cromite source Docker build so the container fetches this fork's source and patch set.
- Use the fork commit SHA for persistent build-cache directory names.
- Default to Android arm64, which is the intended first APK target.
- Calculate a SHA-256 checksum and upload the arm64 APK plus checksum as a GitHub Actions artifact.

The source Dockerfile now accepts `CROMITE_REPOSITORY` and fetches the requested commit from that repository.

## Remaining execution prerequisites

These workflow changes are committed but have not been executed. The workflow still depends on the repository owner providing the infrastructure expected by the original project:
- A working self-hosted GitHub Actions runner with the `ci` label (or selecting another configured label).
- Docker, sufficient disk space, memory, and the persistent `/storage/images` mounts expected by the workflow.
- Repository Actions secrets required by the existing build: `KEYSTORE`, `KEYSTORE_PASSPHRASE`, `KEYSTORE_PASSWORD`, and `CROMITE_PREF_HASH_SEED_BIN`.

Do not start the workflow until the runner and signing secrets are confirmed. No build run or APK artifact has been produced by these commits.


## Android versionCode continuity

The Android arm64 build step now adjusts the checked-out Chromium `chrome/VERSION` PATCH field before GN generation. It selects a patch value greater than the source PATCH and based on the GitHub Actions workflow run number. Chromium derives Android version codes from the BUILD/PATCH components, so this makes successive builds from the same Chromium BUILD line installable as upgrades rather than reusing an identical versionCode.

This mechanism is a build-time safeguard, not yet a verified release guarantee. It must be checked against the first real APK's manifest and then against the next build's manifest. The workflow fails if the computed PATCH exceeds 999. Never deliver an update unless its actual package name, signing certificate, and versionCode have been compared with the installed APK.


## Workflow correctness review (2026-11-18)

A static review found and corrected two workflow issues:
- GitHub Actions repository `contents` permission is now `read`, so checkout can read the selected fork commit.
- The Python version-file writer now emits actual newline characters. The previous double-escaped sequence would have written literal `\\n` text into `chrome/VERSION`.

The Android version-code strategy is based on Chromium's version-code generator: Android versionCode incorporates the BUILD number and a three-digit PATCH field, followed by package/ABI digits. Incrementing PATCH within the same BUILD line therefore raises versionCode for successive builds. This still requires confirmation against the first actual APK manifest.

The workflow has not been run. Its self-hosted runner labels, persistent storage mounts, Docker image availability, and encrypted keystore/pref-hash secrets remain unverified. The repository currently has no recorded Actions build run for this branch.
