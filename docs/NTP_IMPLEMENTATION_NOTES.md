# New Tab Page (NTP) Implementation Notes

## User-facing V1 target

- A quiet, compact start page with Cromite branding, a rounded search/address field, and circular frequently used site shortcuts.
- No news/feed stream, advertising cards, or decorative filler.
- Keep bookmarks, downloads, site shortcuts, and existing customization actions reachable.
- Use Simplified Chinese for every browser-owned label and message.

## Existing Cromite NTP patch audited

The active patch `build/patches/Restore-Simplified-NTP-launch.patch` already changes the Android NTP substantially:

- Adds `ntp_shortcuts.xml` with two horizontal actions: Bookmarks and Downloads.
- Adds `MostVisitedTilesGridLayout`, replacing the horizontal tile layout with a responsive grid capped at four columns and four rows.
- Adds an empty-state placeholder for the most-visited area.
- Adds a shortcuts ViewStub to `new_tab_page_layout.xml` and wires Bookmarks / Downloads navigation in `NewTabPageCoordinator.initializeShortcuts()`.
- Forces the search-provider logo off (`mSearchProviderHasLogo = false`, and `setSearchProviderInfo()` overwrites `hasLogo` and `isGoogle` to false), so the current patch does **not** provide Cromite branding. A separate Cromite-owned logo/header needs to be designed and wired.
- The shortcuts row is currently only two text-and-icon actions, not the requested circular site shortcut grid. The most-visited site tiles are a separate grid.

## Existing functionality currently suppressed by the NTP patch

The patch also makes changes that conflict with the requirement to retain original browser features:

- `TileDragDelegateImpl.isAutoScrollEnabled()` changes from `true` to `false`.
- `TileDragDelegateImpl.getTileViewData()` returns `null` instead of the tile's data.
- `TileDragDelegateImpl.getOuterView()` returns `null` instead of the outer scroll view.
- `TileDragDelegateImpl.showDivider()` and `hideDivider()` become empty.
- `TileRenderer.renderTileSection()` comments out divider creation and the Add Custom Link button insertion.

These are not just visual simplifications; they disable or bypass existing tile interaction/custom-link behavior. Do not copy these changes into a new design without first deciding how to preserve custom-link creation, tile reordering, and related accessibility behavior. The preferred direction is to keep the new compact grid but restore equivalent user actions rather than silently removing them.

## Implementation boundaries

- Keep Chromium's existing NTP search box and navigation delegate; do not create a parallel search implementation.
- Add a small Cromite brand header/logo as a separate view in the NTP layout. Do not re-enable a third-party search-engine logo as a substitute for browser branding.
- Reuse the existing site suggestion tile models, click routing, and custom-link store. Style the tiles as compact circular icons with readable Chinese labels, while retaining long-press/edit behavior.
- Bookmarks and Downloads may remain as secondary quick actions; they should not displace the primary site shortcuts.
- Hide feed/news modules through the existing feature/configuration path rather than deleting their implementation or changing unrelated profile/network behavior.
- Confirm the exact pinned Chromium 153.0.8010.37 source before creating patches; current patch hunks are based on that source line context but have not been applied and compiled in this project.

## Verification status

- The existing patch was inspected directly in the repository.
- The NTP branding, site-tile presentation, and interaction regressions listed above are confirmed from its added/changed hunks.
- No new NTP implementation patch has been created.
- No full Chromium source patch-application test, Android compilation, runtime screenshot test, accessibility test, or APK test has been performed.
