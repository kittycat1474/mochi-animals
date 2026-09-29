# Mochi Animals — Asset Edition (v2.1)

A complete, local Godot 4.7 portrait merging game, with English UI and the supplied animal, button, and cup artwork. Tested with Godot 4.7.1 on Apple Silicon.

## Play

Open the Mac app from `MochiAnimals-v2.1-Mac.zip`, or import `project.godot` in Godot 4.7 and press **F5**.

- Mouse: move to aim; click the play area to drop.
- Touch: drag and release to drop.
- Keyboard: **Left/Right** or **A/D** to aim, **Space** to drop, **P/Esc** to pause, **R** for restart confirmation, **M** for sound effects.
- Home keeps the current cup available through PLAY. RESTART starts a new cup after confirmation.
- Sound and music have separate switches. Music starts off.

## Rules

Two animals of the same level merge into the next. The order is fixed:

| Animal | Color | Radius | Merge points |
| --- | --- | --- | --- |
| Hamster | Apricot orange | 39 | — |
| Chick | Pale yellow | 48 | 10 |
| Bunny | Pale pink | 59 | 30 |
| Capybara | Caramel brown | 72 | 60 |
| Cat | Pale blue | 86 | 100 |
| Dog | Mint green | 102 | 150 |
| Unicorn | Pale lavender | 120 | 250 |

The new hamster is exactly the size of the previous version's bunny. The drop pool remains Hamster / Chick / Bunny (48% / 32% / 20%). Unicorn is the final level; two unicorns do not merge further.

**Overflow rule:** there is no height countdown and no wall above the cup rim. Animals can pile up above the opening and physically tumble over either edge. The game ends only when an animal outside the cup reaches the table at the visible cup-bottom height. Landing on the floor *inside* the cup is safe. The interior floor is y=756; the outside table is y=808 in the 540 × 960 logical canvas.

The hammer removes one tapped animal. The bomb clears animals within 115 units of the tapped animal. Each new cup starts with three of each. Merges earn local coins; tap the coin bar to buy one extra hammer (50) or bomb (80) for the current cup. There are no payments, ads, accounts, or network services.

Best score, coins, lifetime merges, music and sound settings persist locally. Current cup progress and tool inventory do not persist between app launches. The app reads a previous v1 save if a v2 save does not yet exist.

## Exact supplied artwork

- `assets/source/animals.png`: the original 7-column × 3-row sheet, unchanged.
- `assets/source/buttons.png`: original interface sheet, unchanged.
- `assets/source/cup.png`: original cup image, unchanged.
- `assets/source/layout-reference.png`: original interface reference, unchanged.
- `assets/room.png`: a clean room background generated from the layout reference.

Gameplay animals sample the original expression sheet through a deforming mesh. Happy, squeezed, and spiral-eyes-with-tears states use rows 1, 2, and 3, respectively. Hand-drawn silhouette boundaries are sampled from the source to avoid white-sheet halos. Nothing redraws the animal faces.

Buttons use clipped atlas regions from the supplied sheet, with live numbers replacing example numbers. The cup's original rim, ears, side borders and paw-print base are drawn in separate back/front layers; its interior remains transparent. There are no baked glass reflections covering animals. The original evolution strip remains visible along the bottom.

## Soft bodies

Each animal has 20 movable contour particles, edge constraints, area preservation and elastic shape recovery. The same contour is used for collisions and the textured mesh. Two physics substeps and five solver iterations per frame stabilize stacking. Cup walls have finite, two-sided swept collisions and hard interior/exterior constraints; the top is open. Pressure drives the three original expression rows.

### v2.1 rigid-cup fix

Animals cannot squeeze through either side or the floor, including immediately after a larger animal is created by a merge. Hard boundary projection recovers deep penetration even when both Verlet positions have already crossed a wall. Inside/outside ownership only changes when the animal crosses above the open rim. Smoothed artwork uses the same boundary constraint so interpolation cannot visually protrude through the cup. The animals remain soft and elastic; only the cup is rigid. Existing assets, sizes, controls and overflow game-over rules are unchanged.

## Development

- `scripts/main.gd`: English interface, input, game state, local tools and records.
- `scripts/animal_data.gd`: evolution order, sizes, palette and points.
- `scripts/sprite_painter.gd`: 21 atlas regions and textured soft-body rendering.
- `scripts/asset_art.gd`: original UI artwork and layered cup.
- `scripts/soft_body.gd`: elastic particle ring and pressure.
- `scripts/soft_world.gd`: finite cup walls, merges and grounded overflow.
- `scripts/sound.gd`: synthesized plucks and optional soft looping music.
- `tests/test_suite.gd`: gameplay, collision, overflow, assets and inventory checks.

```sh
godot --path .
godot --headless --path . --script res://tests/test_suite.gd
godot --headless --path . --export-release macOS ../MochiAnimals-v2.1-Mac.zip
```

Visual QA options after `--`: `--showcase`, `--capture=/absolute/path.png`, `--capture-mode=expressions`, `--capture-mode=home`, `--capture-mode=wall-regression`. The wall regression stages the reported cat-and-chicks arrangement without merging. Capture runs never modify saved records. A normal launch starts with an empty cup.

Desktop output is a universal Apple Silicon / Intel build. Mobile touch handling is implemented, but iOS/Android device builds and store packaging have not been verified. The Mac app is locally ad-hoc signed, not Apple-notarized.
