---
description: Where Yabar keeps its settings and state.
---

# Files

| Where | What |
|---|---|
| `defaults read io.github.mpdreamz.yabar` | Every setting, the profiles, labels, scratchpads, and how often launcher rows are picked. |
| `~/Library/Application Support/Yabar/yabar.lock` | Held while Yabar runs, so only one does. |
| `~/Library/Caches/io.github.mpdreamz.yabar/stack-focus.json` | The window last focused in each stack, for `yabar focus`. |
| `/tmp/yabar_$USER.socket` | Where yabai's signals and `yabar launcher` reach Yabar. |
