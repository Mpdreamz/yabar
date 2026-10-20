---
description: What Yabar's spaces item in the menu bar shows, and what its menu offers.
---

# The menu bar

![Yabar's spaces in the menu bar: "code" focused, "web" and "chat" occupied, an empty space 4](../images/shots/menubar/spaces.png)

Every space is a cell, in the order yabai numbers them:

| Looks like | Means |
|---|---|
| A filled box with the name cut out | The focused space. |
| An outlined box | The space shown on another display. |
| Plain text | A space with windows. |
| Faint text | An empty space. |
| A dot at the top right | The space holds a stack (or uses yabai's stack layout). |
| A bar underneath | A window on the space [wants attention](../stacks/attention.md). |
| A dashed box | A native fullscreen app. |

A space shows its [label](../layouts/labels.md) when it has one, its number otherwise. With more than one display, the
displays are separated by a wider gap, or get an item each (**One item per display** in Settings).

**Click** a space to go there. That needs yabai's scripting addition; without it Yabar focuses one of the space's
windows, which makes macOS switch to it (an empty space then can't be reached this way).

## The menu

Right-click (or Control-click) the item:

- **Label Space N…**: name the focused space.
- **Scratchpads**: when yabai's scripting addition is loaded.
- **Stack Indicators**: the style and placement, at a glance.
- **Settings…** (⌘,), the version, **Check for Updates…**, **Quit**.
- Last, every space with its windows: pick one to go there. Stacked windows carry their place in the stack.
