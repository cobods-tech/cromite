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
