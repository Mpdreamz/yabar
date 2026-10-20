---
description: When Yabar doesn't look right.
---

# Troubleshooting

**The menu bar shows faint numbers and nothing else.** yabai isn't running, or isn't answering on
`/tmp/yabai_$USER.socket`; the spaces come from macOS until it is back. Yabar finds it again by itself.

**Space numbers keep changing.** macOS is rearranging spaces by recent use: turn off *Automatically rearrange Spaces
based on most recent use* in System Settings → Desktop & Dock. Labels and profiles follow the space, not its number.

**Padding or a gap was left behind.** A Yabar that was killed with `kill -9` or crashed puts it back on its next launch.
Quitting, `kill` and logging out put it back at once.

**A window overlaps its neighbour.** The app has a minimum size bigger than its column or share; yabai can't make it
smaller, and [focus sizing](layouts/focus-sizing.md) leaves that space alone.

**Clicking a space doesn't switch to an empty one.** That needs yabai's scripting addition.

**Scratchpads are greyed out.** They are yabai's and need its scripting addition loaded (`sudo yabai --load-sa`).

**Yabar is already running.** Only one runs at a time; a second copy says so and quits.
