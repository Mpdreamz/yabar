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
- `yabar focus attention` goes to the next window, on any space, that wants attention (see below).

## Who wants attention

A window whose title starts with 🔔 or a count like `(3)` gets a red badge on its icon or tab (pills turn red), and its
space a bar under it in the menu bar. Ghostty puts 🔔 in a terminal's title when it rings the bell, until you focus it,
so an agent or a long command that rings it when done shows up wherever it is. Turn it off in Settings.

It talks to yabai's socket directly: no Yabar.app needed, no permissions, a few milliseconds per key.

## Displays, spaces and auto-stack

Settings → Displays & Spaces sets a layout, padding, gap, stack indicator style, a maximum number of tiles, a number of
columns and focus sizing for
built-in displays, external displays, one display, or one labelled space (Label This Space… in the menu). With a
maximum, a new window that would make one tile too many goes into a stack on the tile that had focus. Yabar keeps all
of this as per-space settings in yabai and puts .yabairc's values back when it quits.

## Scratchpads

yabai's own scratchpads, which need its scripting addition (without it the feature is off). In Settings → Scratchpads,
name one and give its app (and, for an app with many windows, a title to match) and a place on yabai's grid; a new
window of that app becomes the scratchpad as it opens, or choose Make This Window a Scratchpad… in the menu. Then:

```sh
lcmd - t : yabar scratchpad term   # show or hide it; launches the app when it is not running
```

## Launcher

```sh
lcmd - space : yabar launcher
```

One search over the windows on every space, stacks, scratchpads, installed apps, and Yabar's and yabai's commands.
Each row has its app's icon and badges for its space, its place in a stack, a scratchpad, or attention.

- Enter goes to the window (and its space), shows a scratchpad, runs a command, or opens the app (its last window when
  it is running). With nothing matching, Enter opens the best matching app.
- Cmd+Enter opens a new copy of the app (`open -n`).
- `>` runs the rest as a yabai command: `> window --toggle float`.
- Picks you make often rank higher. Esc closes it and gives focus back.

`yabar launcher` starts Yabar.app first when it is not running.

### Columns and focus sizing

**Columns** lay new windows out side by side instead of yabai's spiral; beyond them a new window becomes a row under the
focused tile (or joins its stack). **Re-arrange this space as columns** in the launcher lays out the windows already
there. **Focus sizing** gives the focused tile's column a share of the width (golden ratio, 0.62, by default) and the
tile that share of its column's height, the rest shared equally; it follows focus from tile to tile. Apps with a
minimum size bigger than their share keep it, and focus sizing then leaves that space as it is.
