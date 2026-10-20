---
description: Install Yabar with Homebrew or the install script.
---

# Installation

```sh
brew install --cask mpdreamz/tap/yabar
```

or

```sh
curl -fsSL https://raw.githubusercontent.com/mpdreamz/yabar/main/install.sh | sh
```

Yabar is for Apple Silicon Macs on macOS 15 or later. The cask also puts the `yabar` command on your `PATH`, for
[skhd](keys.md).

## What it needs

- **yabai, running.** Yabar talks to yabai over its socket (`/tmp/yabai_$USER.socket`). Without yabai, the menu bar
  still shows your spaces, read from macOS, and Yabar picks yabai up again as soon as it starts.
- **No permissions of its own.** Window titles, frames and focus all come from yabai, so Yabar asks for neither
  Accessibility nor Screen Recording.
- **yabai's scripting addition, optionally.** Without it, clicking a space focuses one of its windows instead (macOS
  then switches there), and [scratchpads](../moving-around/scratchpads.md) are off.

## First launch

Yabar opens at login from its first launch on; turn that off under Settings → General. It updates itself
([Updates](../reference/updates.md)). Only one Yabar runs at a time: a second copy says so and quits.
