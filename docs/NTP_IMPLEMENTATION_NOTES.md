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

## Custom-link action restoration patch

A follow-up patch, `build/patches/Restore-NTP-custom-link-entry.patch`, now restores the Add Custom Link tile in the simplified grid. The original NTP patch comments out the call that inserts this action. The replacement uses `MostVisitedTilesGridLayout.addNonTileViewWithWidth()`, which is implemented by the grid layout introduced in the same NTP patch and accepts the same view/width arguments.

The follow-up is listed immediately after `Restore-Simplified-NTP-launch.patch`, so it applies after the line it restores. This is a narrow source-level restoration; it has not yet been applied with `git am` to a full Chromium 153.0.8010.37 checkout or compiled. Tile drag/reorder and auto-scroll remain unresolved because the grid intentionally has no horizontal scroll container and its drag delegate currently returns null for tile data/outer view.

## Tile data lookup restoration

A second narrow follow-up, `build/patches/Restore-NTP-tile-data-lookup.patch`, restores `TileDragDelegateImpl.getTileViewData()` by returning `((SuggestionsTileView) view).getData()`. This matches the original `MostVisitedTilesLayout.getTileViewData()` implementation and the simplified grid still renders `SuggestionsTileView` children. The patch is listed after the simplified NTP patch and custom-link restoration.

This restores the view-to-`SiteSuggestion` lookup needed by reorder logic, but it does **not** restore the full drag interaction: `isAutoScrollEnabled()` remains false and `getOuterView()` still returns null because the grid is not backed by the original horizontal scroll container. Full touch drag/reorder remains unverified and must not be described as restored.

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

## Grid drag/reorder compatibility finding (2026-11-18)

A deeper check of the drag implementation shows that restoring the view-to-data lookup is necessary but not sufficient to claim drag sorting works in the 4-column grid:

- `MostVisitedTilesGridLayout` exposes tile-only indexing through `getTileCount()` / `getTileAt()`; the separate Add Custom Link action is added as a non-tile child and is not part of the draggable tile list.
- `TileDragSession.start()` creates the auto-scroll helper only when `isAutoScrollEnabled()` is true. Since the simplified NTP sets it to false, a null `getOuterView()` is not dereferenced in the ordinary drag-session setup. Re-enabling auto-scroll without restoring a real `HorizontalScrollView` would be unsafe.
- However, Chromium's current `TileMovement` implementation records only each tile's X coordinate, chooses the nearest tile by X alone, and shifts tiles along a single horizontal sequence. That model assumes a one-row strip. In a multi-row grid, X coordinates repeat on each row, so drag targets can be ambiguous and the visual movement can cross rows incorrectly.
- Therefore `Restore-NTP-tile-data-lookup.patch` restores the final `TileView -> SiteSuggestion` data lookup, but full drag/reorder is **not yet restored or validated** for the multi-row grid. The next code change must make tile movement grid-aware (X and Y positions / target selection) or provide a deliberate, accessible alternative reorder interaction. Do not simply set auto-scroll back to true.

The source-level design above is supported by the grid class added in `Restore-Simplified-NTP-launch.patch` and Chromium's `TileMovement` / `TileDragSession` implementations. The external Chromium source references used for this investigation are not the exact pinned 153.0.8010.37 checkout, so final patch application and compilation against that pinned checkout remain mandatory.
 
## Grid-aware tile reordering patch (2026-11-18)

Added `build/patches/Make-NTP-tile-reordering-grid-aware.patch`, immediately after the tile-data lookup restoration patch in the patch list.

The patch adapts the original one-dimensional drag model to the simplified row-major grid:
- Capture each tile's original X and Y coordinates.
- Select the drop target by squared Euclidean distance in both axes.
- Animate shifted background tiles to both their original X and Y positions.
- Move the active tile in both axes and constrain it to the actual grid bounds. X bounds scan every tile, which is important when the final row is incomplete.
- Keep the existing `SiteSuggestion` callback and reorder acceptance flow; auto-scroll remains disabled because the grid has no horizontal scroll parent.

**Validation status:** This is a source patch authored against the Chromium implementation inspected from upstream source references, not yet applied with `git am` to a full Chromium 153.0.8010.37 checkout. Its unified-diff hunk counts and patch-list entry were checked, but exact-context application, Java compilation, UI drag tests (LTR/RTL, partial last row, 1–4 rows), and actual APK build remain pending. Do not describe drag sorting as verified until those checks pass.

Upstream source references used to establish the original one-axis assumptions: `TileMovement` stores X positions and moves via X only; `TileDragSession` clamps and selects the target using X. See Chromium source pages cited in the project discussion.
