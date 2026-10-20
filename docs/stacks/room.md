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
Room grows the moment a stack needs it, and shrinks only once a smaller room has been asked for a quarter of a second,
so a stack that comes apart for a moment while a window moves doesn't move every other window with it. A space whose
room still keeps changing, four times in two seconds, keeps the larger room until its stacks change, and Yabar logs
it (`log show --predicate 'subsystem == "io.github.mpdreamz.yabar"'`).

Your `.yabairc` values come back when the last stack on a space goes, when indicators are off, and when Yabar quits,
including a `kill` or a logout. After a crash, the next launch puts them back.
