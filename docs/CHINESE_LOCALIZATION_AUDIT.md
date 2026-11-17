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

The Cromite settings patch adds a GRDP file with four custom section-title messages. The first-run patch adds three translatable messages plus four non-translatable URL messages. The bottom-toolbar and startup-page patches add four more translatable messages. These Cromite-specific messages are not covered by Chromium's pre-existing XTB entries.

## Cromite GRDP integration correction

A further source audit found that the existing settings and first-run patches create GRDP fragments but do not add them to Chromium's parent `android_chrome_strings.grd`. A GRDP file is not compiled merely because it exists in the source tree: the parent GRD must include it with a `<part>` entry.

A new patch, `Integrate-Cromite-Android-string-parts.patch`, now adds both:
- `cromite_android_chrome_strings_grd/Cromite-settings-ui.grdp`
- `cromite_android_chrome_strings_grd/Welcome-screen.grdp`

It is ordered after the patches that create those files. The hunk format and patch-list references have been checked, but the complete 329-patch series has not yet been applied to a Chromium checkout. The first actual build must confirm that GRIT accepts the integration and that no message IDs collide.

## Cromite-specific English strings identified

The current patch set adds 11 translatable user-facing English messages that need Simplified Chinese coverage. They come from three source areas: the bottom-toolbar patch (2), the startup-page patch (2), and the settings/first-run GRDP fragments (7):

| Message ID | English source |
|---|---|
| `IDS_MOVE_TOOLBAR_BOTTOM_TITLE` | Move toolbar to bottom |
| `IDS_DISABLE_TOOLBAR_SWIPE_UP` | Disable toolbar swipe up |
| `IDS_SHOW_NTP_AT_STARTUP_TITLE` | Show NTP at startup |
| `IDS_SHOW_NTP_AT_STARTUP_SUMMARY` | Enable showing a NewTabPage at startup and allows selection of the last open tab |
| `IDS_BROWSING_DATA_SECTION_TITLE` | Browsing data |
| `IDS_DATA_EXPOSED_TO_WEBSITE_SECTION_TITLE` | Data exposed to the websites |
| `IDS_INCOGNITO_RELATED_SECTION_TITLE` | Incognito mode |
| `IDS_DATA_EXPOSED_TO_DEVICE_SECTION_TITLE` | Data exposed in the device |
| `IDS_FRE_CONTINUE` | Continue |
| `IDS_AUTO_UPDATER_CHECK` | Automatic checks for Bromite app updates |
| `IDS_BROMITE_FRE_FOOTER_PRIVACY_POLICY` | First-run privacy-policy explanation with four link placeholders |

These are not guaranteed to exist in Chromium's upstream zh-CN translation bundles because they are introduced by Cromite patches. The first-run fragment also defines four URL-valued messages (`IDS_PRIVACY_LINK1` through `IDS_PRIVACY_LINK4`) with `translateable="false"`; those are not Chinese UI copy and must remain URLs.

## GRIT requirements for custom strings

Chromium's localization guidance establishes that:
- A GRDP file must be included by a parent GRD; a standalone GRDP file is not automatically compiled.
- A new GRD that is intended to be translated must be represented in `tools/gritsettings/translation_expectations.pyl`.
- Required XTB translation bundles/placeholders must exist for the locales expected by the build.
- Translation values belong in the locale-specific XTB bundle, not in the English source message.

Therefore, do not replace the English source text in the Cromite GRDP with Chinese. That would make Chinese the fallback source for every locale rather than a proper zh-CN translation. A previous experimental patch that did this was removed from the active patch list and deleted before any build.

Before adding translations, verify the exact Chromium 153 parent GRD integration, generated message IDs, the parent GRD's translation-expectation coverage, and XTB paths. Do not guess message IDs or create a speculative XTB file. The seven messages in the two GRDP fragments are only part of the 11-message inventory; toolbar and startup-page strings are defined elsewhere in the existing Android GRD.

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
- Cromite GRDP parent integration: added to the patch series; not yet build-verified.
- Cromite custom-string zh-CN translations: not yet added; generated message IDs must be obtained from the exact GRIT build.
- Full APK locale packaging: not yet verified.
- Runtime Chinese UI: not yet tested.
- APK build, release signing, and in-place update: not yet completed.

A source-tree presence check is not a localization test. Do not claim complete Chinese localization until the APK has been inspected and every user-facing screen in the agreed scope has been checked.
