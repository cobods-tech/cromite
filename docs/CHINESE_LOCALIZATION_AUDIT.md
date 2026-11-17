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

The Cromite settings patch adds a GRDP file with four custom section-title messages; their previously empty translator descriptions have now been filled in with context. The first-run patch adds three translatable messages plus four non-translatable URL messages; the automatic-updater label now correctly uses the Cromite brand rather than the inherited Bromite name. The bottom-toolbar and startup-page patches add four more translatable messages. These Cromite-specific messages are not covered by Chromium's pre-existing XTB entries.

## Cromite GRDP integration correction

A further source audit found that the existing settings and first-run patches create GRDP fragments but do not add them to Chromium's parent `android_chrome_strings.grd`. A GRDP file is not compiled merely because it exists in the source tree: the parent GRD must include it with a `<part>` entry.

A new patch, `Integrate-Cromite-Android-string-parts.patch`, now adds both fragments at the **end** of the parent `<messages>` group, immediately before `</messages>`:
- `cromite_android_chrome_strings_grd/Cromite-settings-ui.grdp`
- `cromite_android_chrome_strings_grd/Welcome-screen.grdp`

It is ordered after the patches that create those files. The parts must be appended at the end of the existing messages group: inserting them at the beginning would change GRIT's sequential resource-ID allocation for existing Chromium strings and could invalidate upstream XTB mappings. The integration hunk was moved to the closing `</messages>` boundary for this reason. The hunk format and patch-list references have been checked, but the complete 329-patch series has not yet been applied to the exact Chromium 153.0.8010.37 checkout. The first actual build must confirm that the context applies, GRIT accepts the integration, and existing upstream message IDs remain unchanged.

## Cromite-specific English strings identified

An initial targeted review of the bottom-toolbar, startup-page, settings, and first-run patches identified 12 translatable messages. This is a **partial inventory, not a complete count**: a subsequent scan of other UI-related patches found additional custom strings in bookmark import/export, tab/session behavior, external intents, history retention, autofill, site permissions, and other settings. Do not treat the table below as the full localization workload:

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
| `IDS_CROMITE_CONTENT_SETTINGS_TITLE` | Cromite content settings |
| `IDS_FRE_CONTINUE` | Continue |
| `IDS_AUTO_UPDATER_CHECK` | Automatically check for Cromite app updates |
| `IDS_BROMITE_FRE_FOOTER_PRIVACY_POLICY` | First-run privacy-policy explanation with four link placeholders |

These are not guaranteed to exist in Chromium's upstream zh-CN translation bundles because they are introduced by Cromite patches. The first-run fragment also defines four URL-valued messages (`IDS_PRIVACY_LINK1` through `IDS_PRIVACY_LINK4`) with `translateable="false"`; those are not Chinese UI copy and must remain URLs.

Additional targeted scan results (not yet exhaustively deduplicated) include `IDS_MENU_EXIT`, bookmark import/export and overwrite prompts, `IDS_CLOSE_TABS_ON_EXIT_TITLE/SUMMARY`, custom-tab privacy settings, history-retention options, native autofill settings, view-source and bookmark-all-tabs menu entries, session permission choices, clear-data-on-exit settings, context-menu settings, autoplay/images/WebGL/WebRTC/viewport site-setting labels and descriptions, and share-intent prompts. The `Content-settings-infrastructure.patch` originally introduced a literal English preference title (`Cromite content settings`). It has now been changed to reference a new GRIT resource, `IDS_CROMITE_CONTENT_SETTINGS_TITLE`, added to the settings GRDP fragment. The resource is now localizable, although its zh-CN translation is still pending. This confirms that the 12-message table is only a starting subset.

## GRIT requirements for custom strings

Chromium's localization guidance establishes that:
- A GRDP file must be included by a parent GRD; a standalone GRDP file is not automatically compiled.
- A new GRD that is intended to be translated must be represented in `tools/gritsettings/translation_expectations.pyl`.
- Required XTB translation bundles/placeholders must exist for the locales expected by the build.
- Translation values belong in the locale-specific XTB bundle, not in the English source message.

Therefore, do not replace the English source text in the Cromite GRDP with Chinese. That would make Chinese the fallback source for every locale rather than a proper zh-CN translation. A previous experimental patch that did this was removed from the active patch list and deleted before any build.

Before adding translations, complete the patch-wide UI-string inventory, then verify the exact Chromium 153 parent GRD integration, generated message IDs, the parent GRD's translation-expectation coverage, and XTB paths. Do not guess message IDs or create a speculative XTB file. The eight messages in the two GRDP fragments are only part of the initial 12-message subset; toolbar and startup-page strings are defined elsewhere in the existing Android GRD.

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


Further patch review has expanded the known UI inventory substantially:

- Bookmark actions: import/export, overwrite confirmation, yes/no actions, save failure, select all, bookmark all tabs, and the tabs collection folder label.
- Privacy and session behavior: always-incognito mode and its sub-options, close-tabs-on-exit, custom-tab intent handling, opening external links in Incognito, history-retention choices, and session-scoped permission lifetimes.
- Browser actions and settings: exit, view source, proxy configuration, tablet UI, tab-switcher list mode, toolbar visibility, Global Privacy Control, Android native autofill, Android Credential Manager for passkeys, and first-run/startup behavior.
- Website controls: popup handling; images; JavaScript JIT; WebGL; WebRTC; autoplay; viewport protection; insecure private-network access; and their allowed/blocked/ask labels, explanations, exceptions, and prompts.
- Other feature surfaces: crash-report management, reader-mode action chip, and experimental user-script management (screen title, enable/disable state, add/view-source actions, file/version/URL labels, installation confirmation, and its security warning).

Branding/localization fixes already applied in this pass:
- The Android share-intent strings no longer refer to Bromite; their user-visible text now refers to Cromite.
- The proxy settings entry has a Simplified Chinese Android resource override (values-zh-rCN), while its internal chrome://proxy destination remains unchanged.
- The user-script GRIT messages now have meaningful translator descriptions instead of placeholder descriptions. The actual Simplified Chinese translations are still pending.

This inventory is still not exhaustive. It is based on targeted patch scans of user-facing Android/browser surfaces, not a full static extraction of every added UI string across all 329 patches. Some strings are inherited Chromium resources and should already resolve through upstream zh-CN XTBs; others are introduced by patches and need explicit coverage. Exact message IDs must be generated by GRIT from the pinned source, not guessed.

### Additional Android extension GRDP integration

The Android extension-support patch creates two additional Cromite-specific GRDP fragments in the same Android strings directory: `Enable-extensions-Android.grdp` and `Extensions-Android.grdp`. These were not covered by the original integration hunk. The integration patch now includes both fragments, and its entry has been moved to the very end of the patch list so that it runs after the extension-support patch has created them. The integration hunk currently appends all four Cromite-specific GRDP fragments immediately before the parent `</messages>` tag.

The Android extension strings also received translator-context descriptions. The upstream `chrome/app/extensions_strings.grdp` is an existing parent resource fragment modified by the extension patch; it is not one of the newly created Cromite Android GRDP files.

**Still unverified:** no exact Chromium 153.0.8010.37 checkout has yet applied the complete patch series. The final GRIT run must verify all four part paths, XML validity, message-name uniqueness, generated Android resources, and unchanged upstream resource-ID mappings.