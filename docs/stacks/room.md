---
description: How Yabar keeps stack indicators beside your windows by asking yabai for room.
---

# Room

Indicators are never drawn over a window: apps draw their own title bars and toolbars, and nothing could sit on them
safely. Instead Yabar asks yabai to leave room beside each stack, on spaces that hold stacks only:

- **Padding** on the side where a stack meets the screen.
- A wider **gap** where a stack has windows on every side.

yabai's padding is per side of a space, but its gap is one number for every split, so a stack whose chosen side faces
another window turns to one that faces the screen: the opposite side first, then the two across. Only a stack boxed in
on every side widens the gap.

The room is just enough for the indicators (icons 30 points, tabs 28, pills 11) and never less than your `.yabairc`'s.
Your `.yabairc` values come back when the last stack on a space goes, when indicators are off, and when Yabar quits,
including a `kill` or a logout. After a crash, the next launch puts them back.
