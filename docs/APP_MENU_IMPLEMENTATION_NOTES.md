# Android App Menu Implementation Notes

## Scope

This note records the verified architecture findings for the V1 two-page, five-column menu. It is an implementation aid, not a claim that the menu has already been changed.

## Existing Chromium menu building blocks

- The Android app menu is model-driven. Menu entries are represented as `ModelList` / `ListItem` objects and rendered through `ModelListAdapter` view binders.
- Chromium already has button-row menu item types for three, four, and five icon buttons. They share `icon_row_menu_item.xml` and `AppMenuItemViewBinder.bindIconRowItem`.
- A button row is a single row of icon actions. It is not, by itself, a labelled five-column grid, and it does not provide two-page horizontal paging.
- The menu handler attaches the click handler to menu models; child icon actions must retain their own menu item IDs and dispatch through the existing menu click path. A visual-only replacement of the row would risk dead buttons.
- Existing menu items are also context-dependent (page menu, overview menu, empty-tablet menu, custom tab, etc.). A replacement must preserve visibility rules and all existing actions rather than hard-code one static list.

## Relevant source paths

Pinned Chromium baseline: `153.0.8010.37`.

- `chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenu.java`
- `chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuHandlerImpl.java`
- `chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuItemViewBinder.java`
- `chrome/browser/ui/android/appmenu/internal/java/res/layout/icon_row_menu_item.xml`
- `chrome/browser/ui/android/appmenu/internal/java/res/layout/menu_item.xml`
- `chrome/android/java/src/org/chromium/chrome/browser/appmenu/AppMenuPropertiesDelegateImpl.java`
- `chrome/android/java/res/menu/main_menu.xml`

## Cromite bottom-toolbar interaction

`Move-navigation-bar-to-bottom.patch` already changes the app menu when the bottom-toolbar feature is enabled:

- `AppMenu.java` uses `TRANSCRIPT_MODE_ALWAYS_SCROLL` and `setStackFromBottom(true)`.
- The popup height and vertical anchor position are adjusted for the bottom-toolbar placement.
- `AppMenuHandlerImpl.java` reverses the menu model order before displaying it.

The two-page implementation must preserve these behaviors. In particular, do not reverse or reorder the model a second time without accounting for the existing reversal, or the visible page order and click/action mapping may become inconsistent.
## Concrete button binding behavior in Chromium 153

The pinned 153.0.8010.37 `AppMenuItemViewBinder.java` was inspected directly:

- `bindIconRowItem()` reads the `ADDITIONAL_ICONS` model list and binds up to five `MaterialButton` views.
- Each child model is passed to `setupMenuButton()`, which sets enabled/focusable state, uses `TITLE_CONDENSED` as the accessibility content description, and dispatches click and long-click through the existing `AppMenuClickHandler`.
- `AppMenuHandlerImpl.setupModelForHighlightAndClick()` assigns the click handler to the parent row and recursively assigns it to the row's `ADDITIONAL_ICONS` child models.
- The existing `icon_row_menu_item.xml` layout is registered for the three-, four-, and five-button row view types in the app-menu adapter.
- `AppMenuItemProperties.ADDITIONAL_ICONS` is therefore the existing child-model mechanism for action buttons; the standard row binder's five-view limit is the specific reason a new paged view type/binder is needed for ten visible actions.

Implementation consequence: the new two-page cell view should consume the existing child `PropertyModel` objects (not create unrelated click callbacks), display `TITLE` beneath each icon, preserve `TITLE_CONDENSED` for accessibility, and call the same `AppMenuClickHandler` for taps/long presses. It must also hide unused cells and respect each child's `ENABLED`, `CHECKED`, and `HIGHLIGHTED` values.

Source files checked against the pinned 153.0.8010.37 GitHub raw tree: `AppMenuItemViewBinder.java` and `chrome/browser/ui/android/appmenu/internal/BUILD.gn`. The latter explicitly lists the Java sources and XML resources that must be extended when adding a new binder/layout.
## Dynamic action-state updates

The pinned 153.0.8010.37 `AppMenuPropertiesDelegateImpl.java` was also inspected. Its `loadingStateChanged()` locates the reload action inside the icon-row `ADDITIONAL_ICONS` list, updates the icon/title/accessibility label, then replaces the parent model's entire `ADDITIONAL_ICONS` list because the child list itself is not observed.

The paged menu must therefore rebind when the parent `ADDITIONAL_ICONS` property changes. It must not copy the child models once at menu construction and then keep stale labels/icons. The reload/stop action is an important test case because its icon and accessible label change while the menu can be open.
## Exact menu-model construction path (Chromium 153.0.8010.37)

The pinned `AppMenuPropertiesDelegateImpl.java` source was fetched from the Chromium 153.0.8010.37 tag. It establishes an important boundary:

- `AppMenuPropertiesDelegateImpl` is **abstract** in this baseline. Its final `getMenuItems()` method resets reader-mode bookkeeping, calls the abstract `buildMenuModelList()`, stores the returned `ModelList`, and returns it.
- Therefore the real page/overview/empty-state menu composition is owned by a concrete subclass implementing `buildMenuModelList()`. Editing only the base class or only the row XML cannot reliably reorganize the full menu.
- The base class already exposes `buildModelForIcon(...)` and `buildModelForIconRow(...)`. The former builds a child action model with its original menu item ID, visible title, condensed accessibility title, enabled state, and icon; the latter wraps those child models in `ADDITIONAL_ICONS`.
- This confirms a safe implementation route is possible without inventing action callbacks: reuse the original child `PropertyModel` objects and preserve their menu IDs, then let the existing handler assign the click handler recursively.
- The `AppMenuHandler.AppMenuItemType` enum in this baseline contains `STANDARD`, `TITLE_BUTTON`, `THREE_BUTTON_ROW`, `FOUR_BUTTON_ROW`, and `FIVE_BUTTON_ROW`; adding a paged grid type requires incrementing `NUM_ENTRIES` and registering a matching binder/layout in `AppMenuHandlerImpl`.
- The concrete subclass that owns `buildMenuModelList()` has not yet been positively identified in the Cromite patch checkout. It must be located before changing menu grouping; do not guess its path or create a patch against an assumed subclass.

This also corrects a potential implementation shortcut: the five-button `icon_row_menu_id` is only one action group, not the full menu. A full menu redesign must deliberately select which original action models are promoted into the two-page grid and which are retained as secondary rows, while preserving the page/overview/empty-state branches and dynamic state.

## Concrete tabbed-browser menu owner located

The concrete menu class is chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedAppMenuPropertiesDelegate.java (TabbedAppMenuPropertiesDelegate). It extends AppMenuPropertiesDelegateImpl and implements buildMenuModelList(). This is the relevant owner for the normal tabbed-browser menu; the earlier uncertainty about the subclass path is resolved.

Its menu construction has three separate context branches:

- populatePageModeMenu() for an active page.
- populateOverviewModeMenu() for the tab overview.
- populateTabletEmptyModeMenu() for the tablet with no tabs.

The page menu starts with an existing five-action row (forward, bookmark, download, page info, reload), then constructs the remaining menu actions as individual model-backed entries. Examples include new tab, incognito tab, history, downloads, bookmarks, recent tabs, extensions, page zoom, share, print, find in page, translate, reader mode, settings, help, and conditional actions. The overview and empty-tablet menus have their own smaller action sets.

**Implementation consequence:** the cleanest place to classify common and infrequent actions is the concrete TabbedAppMenuPropertiesDelegate page/overview/empty-state builders, while the generic app-menu handler/binder owns the reusable two-page grid presentation. Keep context-dependent conditions and existing model builders intact; move/repackage the resulting ListItem models only after they have been built. Preserve divider and custom view items (such as update and incognito entries) unless a deliberate compatible grid representation is added.

The currently existing five-action row is not sufficient to satisfy the full two-page design. The first page should prioritize frequent actions and the second page should hold infrequent tools/settings; all original actions must remain reachable. A precise action-to-page mapping is still pending review against the full pinned TabbedAppMenuPropertiesDelegate.java and Cromite-specific additions before implementation.

## Cromite patch audit: actions that must not disappear

A focused scan of the active patch list found existing Cromite customizations that affect the user's "hide infrequent items, do not delete features" requirement:

- Add-exit-menu-item.patch adds an Exit action to both page and overview menu construction. It must remain available in the redesigned menu.
- Remove-help-menu-item.patch comments out the Help item in TabbedAppMenuPropertiesDelegate and also suppresses several Help entries in settings/autofill-related screens. It additionally changes the Help WebUI route to the Cromite GitHub issue tracker and short-circuits the normal help flow. This is a real feature/UI removal, not merely moving Help to a secondary page.
- The redesigned menu must not silently inherit this removal as if Help never existed. A follow-up compatibility patch restores a visible Help entry in the main app menu; settings-page Help entries remain a separate audit item.

This audit is based on the actual patch files in this repository's active patch list. The restoration patch is listed separately below.

## Help entry restoration patch added

A follow-up patch, build/patches/Restore-help-entry-in-android-app-menu.patch, now reverses the one-line menu removal introduced by Remove-help-menu-item.patch. It is appended after the existing extension and GRIT integration patches in build/cromite_patches_list.txt, so it is applied after the original removal.

The patch restores buildHelpItem() in the normal page-mode app menu. The existing Cromite chrome_pages.cc behavior routes the Help action to the Cromite issue tracker; this patch does not re-enable Google's help destination. It also does not restore the separate Help controls hidden in individual settings screens. Those remain a separate scope decision.

Repository verification performed: the new patch file exists, its target context matches the removal hunk, and the patch list ends with the GRIT integration patch followed by the Help restoration patch. A full git am against the downloaded Chromium 153.0.8010.37 source and Android build have not yet been run.

## V1 implementation requirements

1. Keep the existing model IDs and click-handler route for every original menu action.
2. Introduce a labelled icon-cell presentation; do not assume the current icon-only button row already satisfies this.
3. Group menu actions into two explicit pages, with at most five columns per page. The page grouping must account for the current menu context and hidden/disabled items.
4. Add horizontal paging and a low-noise page indicator without breaking the existing popup anchor, bottom-toolbar positioning, drag-to-dismiss behavior, accessibility focus, or keyboard navigation.
5. Verify all actions, including Cromite-added actions, in regular and incognito contexts and in overview mode.
6. Keep infrequent actions on page two; do not delete them.

## Verification status

- Confirmed from the pinned-source investigation: the existing layout has five button slots and the menu has an icon-row binding path.
- Confirmed from Chromium app-menu architecture references: menu rows are model-backed and icon-row actions are wired through menu item models and the handler.
- Not yet verified against a full Chromium source checkout: exact file contents for every listed path, a patch applying cleanly with `git am`, compilation, runtime paging, accessibility, and action dispatch.
- No menu implementation patch is included by this note. Do not mark the two-page menu complete until the checks above pass.

## Research references

- Chromium `AppMenuHandlerImpl.java` (view-binder registration and click-handler wiring): https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuHandlerImpl.java
- Chromium `AppMenuHandler.java` (menu item types, including multi-button rows): https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/appmenu/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuHandler.java
- Chromium `AppMenuItemProperties.java` (menu item ID, title, icon, click-handler properties): https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/appmenu/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuItemProperties.java

The research links are architectural cross-checks; the implementation target remains the repository's pinned Chromium 153.0.8010.37 source, not Chromium main.


## Additional click-handler safety check (must be resolved before coding)

A current Chromium upstream cross-check exposed a subtle risk in the generic handler path: in the inspected `AppMenuHandlerImpl.updateModelForHighlightAndClick()` implementation, child models in `ADDITIONAL_ICONS` receive their `CLICK_HANDLER` inside the `highlightedId != null` branch. The parent model receives its handler unconditionally. This means it is unsafe to assume that simply nesting five child models under a new grid parent guarantees working taps in every menu-open path.

This cross-check is from a newer upstream source revision and is **not proof** of the exact 153.0.8010.37 behavior. Before implementing the grid against the pinned source, re-open the exact pinned `AppMenuHandlerImpl.java` and verify:
- whether child action models always receive `CLICK_HANDLER`, including when no item is highlighted;
- whether child `POSITION` values are needed by the click dispatcher;
- whether the existing five-button row relies on a separate binding/click path that the new view must preserve.

If the pinned implementation has the same conditional assignment, the new binder must not work around it by inventing direct menu callbacks. Instead, make the smallest generic handler change that assigns the existing `AppMenuClickHandler` and any required position/highlight state to every child action model, then test normal, incognito, overview, and bottom-toolbar menu opening. This is a potential dead-button failure and is a release blocker until tested.


## Exact pinned-source menu inventory (Chromium 153.0.8010.37)

The concrete menu owner was fetched from the exact Chromium tag `153.0.8010.37` during this review (source blob `e4548b2f1ae1f16bec004f318d62852bb724f0fe`). This confirms the menu composition and the context branches rather than relying on current Chromium main.

### Active page, without Chromium submenus

The page menu is built in `populatePageModeMenuWithoutSubmenus()`. Its model list can contain:

- Existing action row: Back (feature-dependent), Forward, Bookmark, Download, Page info (when the back-button experiment is off), Reload/Stop.
- Update custom row (conditional).
- New tab, New incognito tab, Add to group, New window, New incognito window, Move to other window, Manage windows.
- History, Quick delete, Page info, Homepage, Downloads, Bookmarks, Recent tabs, Extensions.
- Page zoom, Share, Download page, Print, Price tracking, Glic, Find in page, Lens, Translate, Read aloud, Reader mode, Open with, Add to Home screen, Open in app, Request desktop site, Auto Dark, Paint preview, Image descriptions, Listen to Feed.
- Settings, NTP customizations, Help, Managed by, supervised-content help, and default-browser promotion.

Many entries are conditional on the current URL, tab, incognito state, device form factor, feature flags, or installed capabilities. The redesigned menu must rearrange existing `ListItem` models after these conditions have been evaluated; it must not recreate a simplified static list.

### Active page, with Chromium submenus

When `isSubmenusEnabled()` is true, the page menu instead groups several actions under parents:

- Tab groups; History and autofill; Bookmarks; Extensions; Passwords and autofill; Save and share; More tools; Help.
- Standalone actions still include new tab/incognito, window management, quick delete, homepage, downloads, page zoom, Glic, print, price tracking, find, Lens, translate, open with, open in app, Request desktop site, Auto Dark, image descriptions, Listen to Feed, Settings, managed-by/help-for-supervised-content, and default-browser promotion.

Do not flatten or discard these submenu children. The V1 two-page menu must either preserve the existing submenu rows or keep their parent models reachable on the secondary page.

### Overview and empty-tablet contexts

- Tab overview: New tab, New incognito tab, optional new windows, new tab group, Close all tabs, optional Select tabs, Quick delete, Settings.
- Empty tablet: New tab, optional new window/incognito window (or new incognito tab), Settings, and conditional Quick delete.

The grid implementation must preserve these smaller context-specific model lists. It must not show page-only actions when the current menu is in overview or empty-tablet mode.

### First-pass V1 grouping proposal (not yet implemented)

For the ordinary active-page menu, the initial high-frequency page can prioritize:

1. New tab
2. New incognito tab
3. Bookmarks
4. History
5. Downloads
6. Share
7. Find in page
8. Translate
9. Reload/Stop
10. Settings

The secondary page retains every other original action, including Back/Forward if they are not kept in a persistent top row, Page info, Quick delete, Recent tabs, Extensions, Page zoom, Print, Reader mode, Download page, Open with, Add to Home screen, Request desktop site, Auto Dark, NTP customizations, Help, Exit (Cromite addition), window/group actions, update/custom rows, and all conditional or supervised-user entries.

This is a grouping proposal, not a code-level commitment: before implementation, reconcile it with the actual Cromite patch series (especially the added Exit action, Help restoration, bottom-toolbar menu reversal, and any custom menu IDs). The existing Back/Forward/Bookmark/Download/Page-info/Reload icon row cannot simply be dropped; every action in it must remain reachable. The first page may use a persistent row for navigation actions only if the final layout still matches the agreed two-page five-column design and does not create duplicate actions.

### Implementation boundary

The new paged grid should be a reusable menu view type that consumes original menu item models and retains their menu IDs, enabled/checked/managed state, icons, visible titles, and accessibility descriptions. The context-specific delegate should classify models only after its existing builders have applied all visibility rules. Update and other custom rows must remain live and must not be copied into stale one-time grid state.

Exact pinned-source inventory is now documented. The generic handler/binder and its child-click dispatch path still require exact-tag reinspection before a code patch is written. No two-page menu implementation patch or runtime test is claimed at this stage.
