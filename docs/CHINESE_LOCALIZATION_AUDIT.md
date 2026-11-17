# Chromium 153 Chinese UI localization audit

Audited against this fork's `build/RELEASE` (153.0.8010.37), the current patch list, and Chromium's GRIT localization documentation.

## Confirmed upstream localization

Chromium's Android GRD catalog declares a Simplified Chinese output and translation bundle (`zh-CN` / `android_chrome_strings_zh-CN.xtb`). The catalog is the source for many standard Android browser strings. Reuse the Chromium 153 catalogs rather than translating Chromium's existing strings from scratch.

Related source files include:
- `chrome/browser/ui/android/strings/translations/android_chrome_strings_zh-CN.xtb`
- `chrome/app/resources/chromium_strings_zh-CN.xtb`
- `chrome/app/resources/generated_resources_zh-CN.xtb`
- `components/browser_ui/strings/android/translations/browser_ui_strings_zh-CN.xtb`
- `chrome/android/features/tab_ui/java/strings/translations/android_chrome_tab_ui_strings_zh-CN.xtb`

## Existing Cromite UI patch inventory

The current patch list already applies:
- `Restore-Simplified-NTP-launch.patch`
- `Add-option-to-use-home-page-as-NTP.patch`
- `Move-navigation-bar-to-bottom.patch`
- `Cromite-Branding--improve-settings-ui.patch`
- `Show-NTP-at-startup.patch`

The Cromite settings patch adds a GRDP file with four custom section-title messages. These are Cromite-specific and are not covered by Chromium's pre-existing XTB entries.

## GRIT requirements for custom strings

Chromium's localization guidance establishes that:
- A GRDP file must be included by a parent GRD; a standalone GRDP file is not automatically compiled.
- A new GRD that is intended to be translated must be represented in `tools/gritsettings/translation_expectations.pyl`.
- Required XTB translation bundles/placeholders must exist for the locales expected by the build.
- Translation values belong in the locale-specific XTB bundle, not in the English source message.

Therefore, do not replace the English source text in the Cromite GRDP with Chinese. That would make Chinese the fallback source for every locale rather than a proper zh-CN translation. A previous experimental patch that did this was removed from the active patch list and deleted before any build.

Before changing Cromite's four custom messages, verify the exact Chromium 153 parent GRD integration, generated message IDs, translation expectation entries, and XTB paths. Do not guess message IDs or create a speculative XTB file.

## Package identity

The Android GN configuration sets `chrome_public_manifest_package = "org.cromite.cromite"`. Preserve this package ID across all releases to maintain update compatibility.

## Implementation sequence

1. Verify the Chromium 153 zh-CN catalogs are included in the Android target and APK.
2. Verify how the existing Cromite GRDP is integrated into the parent GRD and whether the current patch set compiles it.
3. Add proper zh-CN translations for Cromite-only messages using the actual generated message IDs and locale bundle.
4. Inspect the built APK and test the app with Simplified Chinese selected. Check menus, settings, NTP, tab UI, and Cromite-specific settings.
5. Keep localization changes separate from the visual/layout redesign so they can be reviewed and rolled back independently.

## Validation status

- Upstream zh-CN catalog declarations: confirmed from Chromium source.
- Cromite custom-string translation integration: not yet verified.
- Full APK locale packaging: not yet verified.
- Runtime Chinese UI: not yet tested.
- APK build, release signing, and in-place update: not yet completed.

A source-tree presence check is not a localization test. Do not claim complete Chinese localization until the APK has been inspected and every user-facing screen in the agreed scope has been checked.
