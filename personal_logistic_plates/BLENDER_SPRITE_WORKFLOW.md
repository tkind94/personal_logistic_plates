# Blender to Factorio Animated Sprite Workflow

This guide gets your plate model from Blender into a Factorio-ready sprite sheet.

## 1) Model and animation setup in Blender

- Create the plate mesh centered at world origin.
- Keep the model low profile (flat on Z axis) so it reads as a floor object in-game.
- Add your animation (for example: emissive pulse, ring rotation, or panel movement).
- Set animation length to a fixed frame range, e.g. 1-32.

## 2) Camera and render setup (orthographic)

- Add a camera and set type to **Orthographic**.
- Point camera straight down (top-down look).
- Adjust orthographic scale until the plate fills most of frame with small margin.
- Set output resolution to a square power-of-two size (recommended: `256x256` per frame).
- Use transparent background (Film > Transparent).
- Use Eevee or Cycles with consistent lighting.

## 3) Export PNG frame sequence

- Output format: `PNG`.
- Color: `RGBA`.
- File output path: a temporary folder (one file per frame).
- Render the animation (`Render > Render Animation`).

You should now have files like:

- `plate_0001.png`
- `plate_0002.png`
- ...

## 4) Pack frames into one sprite sheet

Use ImageMagick (install with Homebrew if needed: `brew install imagemagick`).

Example for 32 frames in 8 columns x 4 rows:

```bash
magick montage plate_*.png -tile 8x4 -geometry 256x256+0+0 -background none plate_sheet.png
```

## 5) Put assets in mod folder

Recommended structure:

- `personal_logistic_plates/graphics/plates/tier1/plate_sheet.png`
- `personal_logistic_plates/graphics/plates/tier2/plate_sheet.png`
- `personal_logistic_plates/graphics/plates/tier3/plate_sheet.png`

## 6) Sprite sheet metadata you need in prototype

When wiring the animation in `prototypes/plate.lua`, you need:

- `filename`: sprite sheet path
- `width` and `height`: frame size (e.g. 256x256)
- `frame_count`: total frames (e.g. 32)
- `line_length`: columns per row (e.g. 8)
- `animation_speed`: playback speed (e.g. `0.4`)
- `scale`: world scale per tier
- `render_layer = "floor"`

Example animation block:

```lua
picture = {
    filename = "__personal_logistic_plates__/graphics/plates/tier1/plate_sheet.png",
    width = 256,
    height = 256,
    frame_count = 32,
    line_length = 8,
    animation_speed = 0.4,
    scale = 0.5,
    shift = {0, 0}
}
```

## 7) Alignment tips

- Keep the model centered on the same origin in every frame.
- Avoid changing camera position between renders.
- Keep transparent padding consistent.
- If the plate appears offset in Factorio, tweak `shift` in small increments (`0.01` to `0.05`).

## 8) Performance tips

- Prefer 128 or 256 frame size unless you really need higher detail.
- Keep frame count modest (16-32) for smooth but efficient animation.
- Use one sheet per tier only if needed; reusing one sheet for all tiers is cheaper.

## 9) Quick iteration loop

1. Render frame sequence from Blender.
2. Repack sprite sheet.
3. Replace PNG in mod folder.
4. Reload mod in Factorio.
5. Check scale, alignment, and readability while walking over the plate.

If you want, I can next wire `prototypes/plate.lua` to load animated sprite sheets with fallback to placeholder art until your real assets are present.
