---
description: Everything Yabar registers or changes in yabai, and how it is put back.
---

# What Yabar changes in yabai

Everything carries a `yabar-` label and is taken back out when Yabar quits:

- **Signals** `yabar-<event>` for window, application, space and display events. Each writes one line to Yabar's
  socket (`/tmp/yabar_$USER.socket`) with `nc`; it costs a few milliseconds and does nothing when Yabar isn't running.
- **A rule** `yabar-overlays` keeps yabai from managing Yabar's own indicator panels.
- **Rules** `yabar-scratchpad-<name>` for [scratchpads](../moving-around/scratchpads.md).

Per space, as [profiles](../layouts/profiles.md), [room for indicators](../stacks/room.md), [columns](../layouts/columns.md)
and [focus sizing](../layouts/focus-sizing.md) ask:

- `space --padding`, `space --gap`, `space --layout`
- `config --space N split_type`, `config --space N auto_balance`
- `window --resize`, `--stack`, `--insert`, `--warp` as you work.

Only what differs from your `.yabairc` is sent. On quit (including `kill` and logout) every space Yabar changed goes
back to your `.yabairc`'s padding, gap, split type and auto-balance; after a crash, the next launch does it. A space's
layout is only ever reset when a profile set it: yabai rebuilds a space on every `--layout`.

Every few seconds Yabar checks its signals are still there: a yabai that restarted has none, and gets them back.
