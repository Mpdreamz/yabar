<p align="center">
  <img src="docs/images/png/yabar-180.png" width="112" alt="Yabar">
</p>

<h1 align="center">Yabar</h1>

<p align="center"><b>Spaces, stacks and tabs for <a href="https://github.com/asmvik/yabai">yabai</a>, in the menu bar.</b></p>

<p align="center">
  <a href="https://github.com/mpdreamz/yabar/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/mpdreamz/yabar?color=2EE6C5&label=release"></a>
  <img alt="macOS 15+, Apple Silicon" src="https://img.shields.io/badge/macOS-15%2B%20·%20Apple%20Silicon-4C7DFF">
  <img alt="For yabai" src="https://img.shields.io/badge/for-yabai-2EE6C5">
  <a href="LICENSE"><img alt="MIT licensed" src="https://img.shields.io/github/license/mpdreamz/yabar?color=4C7DFF"></a>
</p>

<p align="center">
  <a href="https://mpdreamz.github.io/yabar/"><b>Website & docs</b></a> ·
  <a href="https://github.com/mpdreamz/yabar/releases/latest/download/Yabar-arm64.zip">Download</a> ·
  <a href="https://mpdreamz.github.io/yabar/reference/cli/">The yabar command</a>
</p>

![Yabar's tabs over a stack of terminals beside a browser, notes and music, the spaces in the menu bar](docs/images/shots/landing/hero.jpg)

## What it does

- **Spaces in the menu bar**: focused, on another display, occupied or empty, with a dot for a stack and a bar for a
  window that wants you. Labels that survive yabai restarts. Click to go there.
- **Stack indicators**: app icons, slim pills or **i3-style tabs** beside every stack, never over a window. Yabar asks
  yabai for just enough room and gives it back. Click to focus, middle-click to close.
- **One set of keys through stacks and tiles**: `yabar focus west|east|north|south` steps through a stack's windows,
  then on to the next tile and display, the way i3 does.
- **A launcher**: every window on every space, stacks, scratchpads, apps, and Yabar's and yabai's commands.
- **Attention**: a 🔔 from Ghostty or a `(3)` in a title badges the window and its space; `yabar focus attention` goes there.
- **Layouts per display or space**: columns instead of yabai's spiral, focus sizing (the golden share for the focused
  window), auto-stack, padding, gap and layout.
- **Scratchpads**: yabai's own, set up in Yabar, on one key.
- **Well behaved**: no Accessibility or Screen Recording permission, everything labelled `yabar-` and put back when it
  quits, one instance at a time, signed, notarized, and it updates itself.

| Stacks as tabs, icons or pills | The launcher |
|---|---|
| ![Tabs across the top of a stack](docs/images/shots/indicators/tabs.jpg) | ![The launcher over the desktop](docs/images/shots/launcher/launcher.jpg) |
| **Four columns instead of the spiral** | **Focus sizing, golden ratio** |
| ![Four columns](docs/images/shots/layouts/columns.jpg) | ![The focused column with the golden share](docs/images/shots/layouts/focus-sizing.jpg) |

## Install

```sh
brew install --cask mpdreamz/tap/yabar
```

or `curl -fsSL https://raw.githubusercontent.com/mpdreamz/yabar/main/install.sh | sh`. Apple Silicon, macOS 15+, and
yabai running. yabai's scripting addition is optional (clicking an empty space, scratchpads).

Then bind it in skhd:

```sh
lcmd - h : yabar focus west
lcmd - j : yabar focus south
lcmd - k : yabar focus north
lcmd - l : yabar focus east
lcmd + shift - space : yabar launcher
lcmd - 0 : yabar focus attention
```

Everything else is in the **[docs](https://mpdreamz.github.io/yabar/)**.

## Build

```sh
mise run dev     # debug build, then open build/Yabar.app
mise run test
mise run shots   # redraw every image in docs/images, and the app icon
mise run docs    # build the docs and landing page as CI does, served on :4000
```

MIT licensed.
