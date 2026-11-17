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
