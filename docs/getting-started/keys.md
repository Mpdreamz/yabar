---
description: Binding Yabar's commands in skhd.
---

# Keys

Yabar binds no keys itself: the `yabar` command does the work, and skhd (or any hotkey tool) calls it. For example, in
`~/.skhdrc`:

```sh
# through stacks and tiles, one set of keys
lcmd - h : yabar focus west
lcmd - j : yabar focus south
lcmd - k : yabar focus north
lcmd - l : yabar focus east

# the launcher (⌘Space stays Spotlight's), and the next window that wants attention
lcmd + shift - space : yabar launcher
lcmd - 0 : yabar focus attention

# a scratchpad (needs yabai's scripting addition)
lcmd - t : yabar scratchpad term
```

`yabar` talks to yabai's socket directly: it needs neither Yabar.app running (except for the launcher) nor any
permission, and takes a few milliseconds. See [the yabar command](../reference/cli.md).
