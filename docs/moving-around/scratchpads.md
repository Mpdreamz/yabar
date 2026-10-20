---
description: yabai's scratchpads, set up in Yabar and shown or hidden with one key.
---

# Scratchpads

A scratchpad is an app's window that floats at a fixed place and is shown and hidden with one key, on whatever space
you are on. They are yabai's own and need its **scripting addition**; without it, Yabar leaves them off.

Set them up under Settings → Scratchpads: a name, an app, a title to match (for an app with many windows), and a place
on yabai's grid (`rows:cols:x:y:width:height`; `6:6:1:1:4:4` is centred, two thirds each way). A new window of that app
becomes the scratchpad as it opens; or pick **Make This Window a Scratchpad…** in the menu.

```sh
yabar scratchpad term
```

shows or hides it. When the app isn't running, it launches it, and its first window becomes the scratchpad. A running
app is never launched again.

**Bring Back All Scratchpads** in the menu runs yabai's `recover`, for windows lost after a crash.
