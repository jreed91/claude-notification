# README previews

The images in this folder are **rendered UI previews** of AgentBar's popover — not
photos of a running app. They reproduce the app's live-feed design (the exact palette,
layout, and components from `app/Sources/AgentBar/Views/`) so the README can show what
AgentBar looks like without a signed macOS build.

## Regenerate

Requires Node and a Chromium build. From the repo root:

```sh
node docs/images/generate.js docs/images            # writes dashboard/permission/activity .html
# then render each with headless Chromium at 2x, e.g.:
chromium --headless=new --hide-scrollbars \
  --force-device-scale-factor=2 --default-background-color=00000000 \
  --window-size=420,1000 --screenshot=docs/images/dashboard.png \
  file://$PWD/docs/images/dashboard.html
```

Crop the transparent margins to the content bounding box after rendering. Swap these for
real screenshots of the built app whenever a signed build is available.
