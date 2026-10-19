# Yabar

A native macOS menu bar companion for [yabai](https://github.com/asmvik/yabai): your spaces in the menu bar, and
indicators for yabai's window stacks (stackline style or i3-style tabs), without Hammerspoon.

## Moving between tiles and stacks: `yabar focus`

The cask puts a `yabar` command on your PATH that skhd can call. One set of direction keys moves through a stack's
windows and on to the neighbouring tile, the way i3 does with tabbed and stacked containers:

```sh
# ~/.skhdrc
lcmd - h : yabar focus west
lcmd - j : yabar focus south
lcmd - k : yabar focus north
lcmd - l : yabar focus east
```

- Along a stack's axis the keys step through its windows; past the first or last one they move to the neighbouring
  tile, and with no tile that way to the neighbouring display. Across the axis they go straight to the next tile.
- The axis follows Yabar's indicators: tabs along the top or bottom run west to east, indicators down a side north to
  south (also when indicators are off). `--axis horizontal|vertical` fixes it for every stack.
- Moving back into a stack lands on the window last focused there.
- `yabar focus next` / `prev` walk every window of the space in order instead, wrapping round.

It talks to yabai's socket directly: no Yabar.app needed, no permissions, a few milliseconds per key.
