# Plan

## Milestones

1. **Skeleton and release.** SwiftPM package, `build/Yabar.app`, the release pipeline (Developer ID, notarization,
   Sparkle appcast, Homebrew cask), a placeholder status item. Shipped as v0.1.0 to prove the pipeline.
2. **Core.** The yabai socket client, typed models for displays, spaces and windows, a snapshot diff, and signal
   registration; tests on recorded JSON.
3. **Spaces in the menu bar.** One item per display or one for all; label or index, empty / occupied / focused,
   native fullscreen, stack-layout marker. Click a space to focus it (needs yabai's scripting addition); a menu of
   each space's windows. Falls back to `CGSCopyManagedDisplaySpaces` when yabai is not running.
4. **Stack indicators, stackline style.** Pills or app icons on the outer edge of each stack, unfocused dimmed,
   click to focus.
5. **Stack indicators, i3 tabbed.** A tab strip (icon and title) along the top of each stack. Two placements: over the
   stacked window's title bar, or in reserved room by raising the space's top padding while it holds a stack.
6. **Settings and polish.** A settings window (menu bar, stack indicators, login and updates), launch at login
   (`SMAppService`).

## What yabai offers (v7.1)

- **Socket.** `/tmp/yabai_$USER.socket`, one stream connection per command. Request: an `int32` length (native byte
  order), each argument after `-m` NUL-terminated, then one more NUL; `shutdown(SHUT_WR)`, read to EOF. A reply
  starting with `0x07` is an error. Queries take a property list: `query --windows id,frame,stack-index --space`.
- **Stacks.** `stack-index` is 0 outside a stack, 1… inside; a stack's windows share one frame. Every window of a
  stack reports `is-visible`, so which one is on top is not in the query: Yabar takes the focused one, then the last
  one focused, then the window server's front-to-back order (`StackTops`). Windows yabai has no AX reference for
  (spaces not visited since it started) always report 0, and a yabai restart forgets every stack.
- **Signals** run a shell command; there is no push to an app and no "stack changed" event. Yabar registers labelled
  signals for `window_created/destroyed/focused/moved/resized/minimized/deminimized/title_changed`,
  `space_changed/created/destroyed`, `display_*`, `application_front_switched/hidden/visible` and `dock_did_restart`,
  whose command pokes Yabar's own socket; each poke means "requery", coalesced to one query per frame.
- **Commands** used: `window --focus <id>`, `window <id> --close`, `space --focus <sel>` (scripting addition),
  `space --padding` (the i3 reserved-room placement).

## Overlays

Non-activating borderless panels, one per stack, that handle their own clicks (no global event tap). Each is moved
onto its stack's space with SkyLight's `SLSMoveWindowsToManagedSpace` so it travels with the space instead of being
re-shown on every switch. The move only holds once the window server has ordered the panel in (a move before that is
undone), and an existing panel is never ordered in again, which would pull it to the space on screen. Titles come from yabai and icons from `NSRunningApplication`, so no permission is needed.
