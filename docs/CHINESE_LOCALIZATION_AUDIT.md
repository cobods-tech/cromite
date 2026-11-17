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

A further source audit found that the settings, first-run, and Android extension patches create Cromite-specific GRDP fragments but do not add them to Chromium's parent `android_chrome_strings.grd`. A GRDP file is not compiled merely because it exists in the source tree: the parent GRD must include it with a `<part>` entry.

A new patch, `Integrate-Cromite-Android-string-parts.patch`, now adds all four Android fragments at the **end** of the parent `<messages>` group, immediately before `</messages>`:
- `cromite_android_chrome_strings_grd/Cromite-settings-ui.grdp`
- `cromite_android_chrome_strings_grd/Welcome-screen.grdp`
- `cromite_android_chrome_strings_grd/Enable-extensions-Android.grdp`
- `cromite_android_chrome_strings_grd/Extensions-Android.grdp`

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

Before adding translations, complete the patch-wide UI-string inventory, then verify the exact Chromium 153 parent GRD integration, generated message IDs, the parent GRD's translation-expectation coverage, and XTB paths. Do not guess message IDs or create a speculative XTB file. The eight messages in the original settings and first-run GRDP fragments are only part of the initial 12-message subset; the two extension GRDP fragments add six more messages, and toolbar/startup-page strings are defined elsewhere in the existing Android GRD.

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

The Android extension-support patch creates two additional Cromite-specific GRDP fragments in the same Android strings directory: `Enable-extensions-Android.grdp` and `Extensions-Android.grdp`. These were not covered by the original integration hunk. The integration patch now includes both fragments, and its entry has been moved to the very end of the patch list so that it runs after the extension-support patch has created them. The integration hunk appends all four Cromite-specific GRDP fragments immediately before the parent `</messages>` tag. The hunk line number has been corrected to the closing-tag position in the pinned Chromium 153.0.8010.37 source (file line 7831); the complete patch series still requires a real `git am` test against that checkout.

The Android extension strings also received translator-context descriptions. The upstream `chrome/app/extensions_strings.grdp` is an existing parent resource fragment modified by the extension patch; it is not one of the newly created Cromite Android GRDP files.

**Important correction:** `7831` is the current line number written in the integration patch hunk, not a verified line number from an exact Chromium 153.0.8010.37 checkout. It must not be treated as confirmed. No exact pinned-source checkout has yet applied the complete patch series. The final GRIT run must verify all four part paths, XML validity, message-name uniqueness, generated Android resources, and unchanged upstream resource-ID mappings.

### Additional ad-blocking and extension UI

The patch review also found custom Adblock Plus settings and Android extension-management strings. These include enabling/disabling ad blocking, checking filter-list updates, privileged anti-circumvention/snippet controls and explanations, opening filter repositories and documentation, selected filter-list counts, extension storage usage, clearing/resetting extension data, and enabling experimental Android extensions.

The newly added extension GRDP messages are now part of the Android GRIT catalog. Translator descriptions for the Adblock Plus settings messages that previously had empty descriptions have also been added. The extension toggle and summary messages now have translator context.

Updater menu labels previously displayed 'Update Bromite' and 'Restart Bromite'; these visible labels now say Cromite. This is a branding-only text correction. The underlying legacy updater endpoints and implementation have **not** been changed in this localization pass; they require a separate compatibility/security review before any endpoint change.

### Remaining scope

Custom GRIT messages are not yet translated into zh-CN because their numeric message IDs have not been generated from the pinned Chromium source. The proxy menu entry is one Android-resource exception already given a zh-CN override. The patch-wide scan is still targeted rather than exhaustive, and the complete source checkout/build has not been run.

### Other GRIT catalogs

The experimental user-scripts patch adds components/user_scripts/strings/userscripts_strings.grdp and explicitly includes it from components/components_strings.grd. This is already wired to its parent catalog; its translations belong to the components strings zh-CN XTB rather than the Android Chrome strings XTB. Its 11 messages include user-script settings, enable/disable labels, add/view-source actions, metadata labels, an installation confirmation with a FILE placeholder, and a security warning.

The Adblock Plus Android patch adds strings to chrome/browser/adblock/android/adblock_strings.grd, while the Eyeo patch also modifies the existing components/error_page_strings.grdp. These belong to separate GRIT catalogs and must be audited against their own zh-CN outputs/translation expectations; they must not be incorrectly appended to the Android Chrome GRD.

## APK verification workflow hardening (2026-11-18)

The Android arm64 post-build verification step now searches configured Android SDK roots and common SDK installation directories for `apkanalyzer` and `apksigner`, then adds their containing directories to `PATH` before invoking the APK verifier. This avoids relying solely on an undocumented pre-existing PATH configuration in the custom build container.

This is a workflow robustness change only. It has not been exercised on the self-hosted runner; the SDK installation layout, tool discovery, APK locale-entry check, package metadata, signing certificate, and actual APK output still require a real build run.


### Targeted site-permission string audit (2026-11-18)

A focused read of the active site-permission patches covered:
- `Add-autoplay-site-setting.patch`
- `Site-setting-for-images.patch`
- `JIT-site-settings.patch`
- `Add-webRTC-site-settings.patch`
- `Change-popup-site-setting.patch`

The custom source messages include autoplay, image loading, JavaScript JIT/WebAssembly, WebRTC, and popup/redirect labels, summaries, exception-list labels, and explanatory copy. They are currently English source strings and therefore remain part of the Cromite-specific zh-CN translation workload. The WebRTC enabled/disabled summaries are the literal strings "Enabled" and "Disabled"; the JIT description is "Enable the JIT compiler and WebAssembly support in V8". These are not missing/empty messages.

No Chinese text was left in the English GRDP source messages. An attempted direct source-string translation was reverted because it would make Chinese the fallback text for every locale, contrary to the GRIT localization requirements above. The correct next step is to obtain generated message IDs from a successful pinned Chromium 153 GRIT run, then add translations to the correct zh-CN XTB catalog(s). This targeted review does not establish that all site-permission strings or all custom UI strings have been found.
