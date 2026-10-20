---
description: The yabar command line tool.
---

# The yabar command

The cask links it onto your `PATH`; it lives in `Yabar.app/Contents/Helpers/yabar`. It talks to yabai's socket directly
and needs no permission.

| Command | |
|---|---|
| `yabar focus west\|east\|north\|south [--axis horizontal\|vertical]` | Through a stack's windows along its axis, then the next tile, then the next display ([Focus](../moving-around/focus.md)). |
| `yabar focus next\|prev` | Every window of the space in order, wrapping round. |
| `yabar focus attention` | The next window that [wants attention](../stacks/attention.md), on any space. Exits 1 when there is none. |
| `yabar scratchpad <name>` | Show or hide a [scratchpad](../moving-around/scratchpads.md); launch its app when it isn't running. |
| `yabar launcher` | Open the [launcher](../moving-around/launcher.md), starting Yabar when it isn't running. |
| `yabar --version` | The version and build. |
| `yabar --help` | All of the above. |
