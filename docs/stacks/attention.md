---
description: How Yabar marks windows that want your attention, from their titles.
---

# Attention

macOS has no way to ask how many notifications a window has, but titles carry it often enough, and yabai reports them
without any permission:

- **Ghostty** puts 🔔 in front of a terminal's title when it rings the bell, until you focus it. Agents and long
  commands that ring it when they finish or need input show up this way.
- **Mail, chat and web apps** put a count in front: `(3) Inbox`, `[12] Slack`.

Such a window gets a red badge on its icon or tab (the count, or a dot); a pill turns red. Its space gets a bar under it
in the menu bar, so you see it from any space. `yabar focus attention` goes to the next one, and the
[launcher](../moving-around/launcher.md) shows them with a badge.

Turn it off under Settings → Stacks.
