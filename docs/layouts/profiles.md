---
description: Yabar's profiles set layout, padding, gap, columns, focus sizing and more per display or space.
---

# Profiles

Settings → **Displays & Spaces**. Pick what a profile applies to, from broad to specific:

1. **Built-in display**: a laptop's screen.
2. **External displays**.
3. **One display**, by name.
4. **A labelled space** ([Labels](labels.md)).

Each can set:

| Setting | |
|---|---|
| Layout | yabai's bsp, stack or float. |
| Padding, Gap | yabai's, for the space. |
| Max tiles | [Auto-stack](auto-stack.md). |
| Columns, Beyond the columns | [Columns](columns.md). |
| Focus sizing | [Focus sizing](focus-sizing.md). |
| Stack indicators | The [style](../stacks/indicators.md) here. |

Anything left empty (inherit) comes from the broader one, and in the end from your `.yabairc`. Room for stack
indicators is added on top of the padding and gap.

Yabar applies a profile as per-space settings in yabai, and only what differs: a layout or padding you change by hand on
a space no profile covers is left alone. Everything goes back to your `.yabairc`'s values when Yabar quits, and after a
crash on its next launch. Changing a layout makes yabai rebuild that space, which dissolves its stacks: yabai has no
other way to switch.
