---
description: yabar focus moves through stacks and tiles with one set of keys, the way i3 does.
---

# Focus

yabai has `stack.next` (only inside a stack) and directions (only from tile to tile, landing on a stack's top window),
but nothing that does both. `yabar focus` does, the way i3 moves through tabbed and stacked containers:

```sh
yabar focus west|east|north|south
```

- **Along a stack's axis** the keys step through its windows. Past the first or last one they move to the neighbouring
  tile, and with no tile that way, to the neighbouring display.
- **Across the axis** they go straight to the neighbouring tile.
- **The axis follows the indicators**: tabs along the top or bottom run west to east; indicators down a side (or none)
  run north to south. `--axis horizontal|vertical` fixes it for every stack.
- **Moving back into a stack** lands on the window you left, remembered between key presses.

```sh
yabar focus next|prev
```

walks every window of the space instead, in yabai's order, each stack's windows in turn, wrapping round.

```sh
yabar focus attention
```

goes to the next window, on any space, that [wants attention](../stacks/attention.md).
