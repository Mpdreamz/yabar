---
description: Space labels in Yabar, kept across yabai restarts.
---

# Labels

**Label Space N…** in the menu names the focused space: the menu bar shows the name instead of the number, profiles can
apply to it, and yabai accepts it as a space selector (`yabai -m space --focus code`). An empty name clears it.

A label can't be a number, one of yabai's selector words (`next`, `prev`, `first`, `last`, `recent`, `mouse`), contain
spaces, or be another space's.

yabai forgets labels when it restarts; Yabar keeps them by the space's identity (not its number, which changes when
spaces are reordered) and puts them back. Labels set another way, in `.yabairc` or with `yabai -m space --label`, are
adopted as they are.
