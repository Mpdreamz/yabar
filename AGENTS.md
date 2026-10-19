# Agents working on Yabar

Yabar is a native menu bar app for yabai users: the spaces in the menu bar, and indicators for yabai's window stacks
(stackline-style pills or icons, or i3-style tabs). Read `PLAN.md` first.

## Principles

- **yabai is the source of truth.** Spaces, windows, stacks, titles and focus come from yabai's socket
  (`/tmp/yabai_$USER.socket`), never from scraping the window server ourselves. That keeps Yabar free of
  Accessibility and Screen Recording permissions; adding one needs the owner's say.
- **Domain in `YabarCore`, AppKit in `YabarApp`.** The socket client, the models and the diff between two snapshots
  live in the core with tests against recorded yabai JSON; the app layer only draws domain values and sends commands.
- **Differential updates.** A signal from yabai means "requery"; the new snapshot is diffed against the last one and
  only the status items and overlays that changed are touched. Stable identities (window id, space uuid) everywhere.
- **Never block the main actor.** Socket IO and `Process` run off it; no `waitUntilExit` on main.
- **Never steal focus.** Overlays are non-activating panels; Yabar never activates itself except for its own alert or
  Sparkle's window.
- **Clean up after yourself.** Signals Yabar registers with yabai carry a `yabar-` label and are removed on quit.

## Working

- `mise run test` and `mise run lint` before committing; `mise run fmt` fixes formatting.
- `mise run dev` builds and launches `build/Yabar.app`. `YABAR_DEPLOY_DIR` (in `mise.local.toml`) copies each build
  to a share the Mac running yabai can open.
- Branch names set the release-drafter label: `feature/`, `fix/`, `docs/`, `chore/`, `ci/`. Pull requests are
  squash-merged (the build number is main's commit count).

## Releasing

Merges to main keep a draft release up to date. `gh workflow run release` builds main, signs it with the Developer ID,
notarizes and staples it, writes a signed appcast for Sparkle, publishes the draft and bumps
`mpdreamz/homebrew-tap`. Secrets are stored with `scripts/release-secrets.sh` (run by the owner, never by an agent);
the Sparkle private key lives in the owner's keychain under the account `yabar` and is never handled here.
