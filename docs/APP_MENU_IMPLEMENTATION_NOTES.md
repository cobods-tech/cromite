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
