# Chromium 153 Chinese UI localization audit

Audited against this fork's `build/RELEASE` (153.0.8010.37) and current `build/cromite_patches_list.txt`.

## Findings

1. Chromium 153 has upstream Simplified Chinese Android UI translation catalogs:
   - `chrome/browser/ui/android/strings/translations/android_chrome_strings_zh-CN.xtb`
   - `chrome/app/resources/chromium_strings_zh-CN.xtb`
   - `chrome/app/resources/generated_resources_zh-CN.xtb`
   - `components/browser_ui/strings/android/translations/browser_ui_strings_zh-CN.xtb`
   - `chrome/android/features/tab_ui/java/strings/translations/android_chrome_tab_ui_strings_zh-CN.xtb`
2. These catalogs belong to the exact Chromium 153 source line, so they should be reused rather than retranslating Chromium's existing UI strings.
3. The Cromite patch list already applies:
   - `Restore-Simplified-NTP-launch.patch`
   - `Add-option-to-use-home-page-as-NTP.patch`
   - `Move-navigation-bar-to-bottom.patch`
   - `Cromite-Branding--improve-settings-ui.patch`
   - `Show-NTP-at-startup.patch`
4. There is currently no dedicated Cromite Simplified Chinese translation patch in `build/patches/`.
5. Cromite's settings patch introduces a custom GRDP catalog with four section-title strings. Those strings need explicit Simplified Chinese translations and a build-time check; upstream Chromium catalogs alone cannot translate new Cromite-only message IDs.
6. The Android GN configuration sets `chrome_public_manifest_package = "org.cromite.cromite"`. Preserve it across all releases.

## Implementation sequence

1. Reuse the upstream Chromium 153 zh-CN catalogs unchanged.
2. Add translations for Cromite-only message IDs in the correct GRIT translation catalog, using the message IDs emitted by the GRD/GRDP integration.
3. Confirm the Android build includes zh-CN locale resources in the delivered APK (not merely that translation source files exist).
4. Test the installed app with Android's app language set to Simplified Chinese and inspect menus, settings, NTP, tab UI, and Cromite-specific settings.
5. Only then begin the separate visual/layout patch series. Keep translation and layout changes in separate patches to simplify review and rollback.

## Important limitation

A source-tree presence check is not a localization test. A successful APK must be inspected and run with zh-CN selected. No claim of complete Chinese localization should be made until every user-facing screen in the agreed scope has been checked.
