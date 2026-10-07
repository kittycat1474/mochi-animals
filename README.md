# Mochi Animals — Asset Edition (v2.9)

A complete, local Godot 4.7 portrait merging game, with English UI and the supplied animal, button, and cup artwork. Tested with Godot 4.7.1 on Apple Silicon.

## Play

Import `project.godot` in Godot 4.7 and press **F5**, or open the Mac app in `builds/Mac-v2.9/Mochi Animals v2.9.app`. Quit a previously running version before opening the updated app. The window title explicitly says **v2.9**.

- Mouse: move to aim; click the play area to drop.
- Touch: drag and release to drop.
- Keyboard: **Left/Right** or **A/D** to aim, **Space** to drop, **P/Esc** to pause, **R** for restart confirmation, **M** for sound effects.
- Home keeps the current cup available through PLAY. RESTART starts a new cup after confirmation.
- Sound and music have separate switches. The supplied MP3 starts automatically, loops, and plays at 30% amplitude. The music button remembers your choice for subsequent launches.

### v2.9 loading page, lower cup and local Top 3

Startup now uses the supplied village/logo/bridge/loading-bar/unicorn sheet. The bar reads Godot's threaded resource-loading progress, with a short presentation hold (minimum 1.2 seconds, at least 0.25 seconds at completion), then opens the game automatically. The four supplied unicorn frames animate above the bar. New artwork is exclusive to startup: gameplay animals, room, NEXT, cup and buttons keep their existing assets.

The bottom instruction sentence is removed. The cup artwork, rim, solid floor and outside spill ground move down another 24 logical pixels; the evolution strip moves down 20 pixels, keeping its proportions and a 9-pixel bottom margin. Animal sizes, physical parameters, aiming height, music, drop probabilities and economy are unchanged. Extra headroom reduces crowding near the waiting animal; it is not an unlimited guarantee against a sufficiently tall overflowing pile.

The stats button opens YOUR TOP 3, stored only on this device. A completed cup records once, sorted highest first; tied scores from separate cups count. Empty ranks display --. Restarting/abandoning a cup does not add a completed score. Existing BEST remains live and is preserved; an older save with only BEST contributes one historical record, without inventing the missing two. All previews/tests use disabled persistence or isolated save files.

The same v2.9 source is exported for unthreaded Godot Web and published at https://mochianimals.netlify.app. The browser shell uses the supplied loading illustration while the engine downloads, then the in-game loading scene takes over. `netlify.toml` publishes `builds/Web`, sets immutable caching for versioned engine/package files, and keeps `index.html` revalidated. `.netlify/` is ignored so local site-link state is never committed. GitHub uses a separate `v2.9` branch; `main` and `v2.8.1` remain unchanged. Previous Mac builds and `builds/backups/source-before-v2.9.zip` are retained.

### v2.8.1 approved NEXT capsule (history)

Only NEXT is visually replaced with the approved cream/apricot vertical capsule. Its top/right anchors and height are unchanged; the width follows the asset's aspect ratio. The transparent window contains the existing live next-animal sprite. The input rectangle now matches the narrow capsule, so the existing aim formula no longer reserves the old wide card's space. No aiming algorithm, other UI geometry, animal sizes, drop probabilities, coins, tools, physics, cup, music or save rules were changed. The approved PNG is copied unchanged to `assets/source/next-capsule.png`.

### v2.8 top-right NEXT and per-cup economy

NEXT now sits above the settings column at the top right. The waiting animal clears it across the aiming range, including Capybara. The latest supplied evolution strip spans the bottom width, using its original artwork proportions and excluding only transparent outer padding.

Every cup starts with a Chick, zero coins, zero hammers and zero bombs. Subsequent drops are Hamster 30%, Chick 30%, Bunny 30%, Capybara 10%. Merge coin rewards remain unchanged: merge points divided by ten. A hammer costs 100 coins and a bomb costs 180; each type can be purchased at most three times per cup. The shop shows remaining exchanges and SOLD OUT. Using a tool never restores a purchase allowance. A fresh cup clears the balance, inventory and counters; resuming the same cup does not. BEST and audio preferences are preserved, including when upgrading an old save.

This update stays local to the desktop project. Previous apps and `builds/backups/source-before-v2.8.zip` are retained; no GitHub upload.

### v2.7 ten animals and lower cup (history)

Progression is now Hamster → Chick → Bunny → Capybara → Cat → Dog → Fox → Sheep → Penguin → Unicorn. Nominal diameters are **78 → 96 → 118 → 144 → 172 → 204 → 240 → 190 → 166 → 276**. Fox matches the v2.5 unicorn size. Fox merges into a smaller Sheep, Sheep into a smaller Penguin, and Penguin into the largest Unicorn. The three new species use the approved transparent nine-expression sheet; the final unicorn retains its original artwork.

First-discovery greeting banners (including the final Unicorn banner) are removed. Points, particles, sounds and highest-species tracking still work. The original cup artwork and every physical boundary move down by 43 logical units together, bringing the base to the bottom of the old greeting area. Tool/purchase messages appear above the cup. The supplied ten-animal evolution strip is displayed at its original aspect ratio beside NEXT.

The first three animals remain the drop pool. Old saves still keep their best score, coins and sound preferences. This update is local to the desktop project; earlier builds and `builds/backups/source-before-v2.7.zip` are retained.

### v2.6 slime sliding and performance (history)

Shape recovery and edge stiffness are lower, allowing animals to spread under a load like slime while retaining their original radii and target areas. Contact removes local vibration without repeatedly braking bulk movement. Cup walls are frictionless, zero-bounce barriers: they block penetration but preserve sliding velocity. Open-rim overflow and the existing game-over rule are unchanged.

The solver reuses validated contact planes for small corrections, caches separating axes and conservative broad-phase bounds, skips unnecessary interior wall sweeps, and stops contact relaxation once corrections are visually negligible. Large impacts, new contacts and deep penetration still receive full collision checks. Bounds caches invalidate when particles change; retired pair caches are removed after merges/tools.

Unchanged animal meshes and the 21 circular UI variants are cached. Sleeping animals no longer rebuild their GPU meshes on every draw. Moving faces retain the stable centre anchor and safe collision-contained outline.

On this Apple M2, the deterministic 10/20/30-animal stress benchmark's average physics time fell from 29.79/54.88/109.33 ms to 9.67/23.67/36.99 ms per step (57–68% less). These deliberately crowded, non-merging tests are not a promise of 60 FPS on every device. See `VERIFICATION.md` for tests and limits. Updates remain local to this desktop project; no GitHub upload.

### v2.5 stable artwork and zero-bounce sliding (history)

The recorded jitter had a rendering cause as well as contact motion: changing triangulation diagonals moved the sampled eyes and mouth even when a contour barely moved. Animal faces now use a stable, centre-anchored deformation mesh, preserving contour order. A visibility check prevents a fan from painting across a deep fold; non-star-shaped outlines retain safe polygon triangulation.

Contact keeps bulk sliding but removes oscillating local particle velocity. Cup-wall restitution is zero, the merge's upward impulse is now zero (superseding v2.2's 20%), and the waiting animal no longer has an idle bob. Nominal sizes, soft deformation, area targets, original artwork, hard cup, overflow rule, top launch point, bottom-right NEXT and MP3 remain unchanged. Supported sleep and wake-up behaviour from v2.4 is retained.

The user's cat/chick/hamster arrangement is covered by both physics and actual-renderer regressions, including the moving phase before sleep. See `VERIFICATION.md` for measurements and limits.

### v2.4 non-overlapping, stable soft animals (history)

Animals remain soft, with unchanged nominal radii, target areas, artwork and merge impulse. Collision candidates use their deformed bounds. Shared separating contact planes handle deeply squashed shapes, concave contours and edge-only crossings; a final separation pass also runs immediately when a new animal is born. Rounded artwork stays inside the collision envelope, with ordered polygon triangulation instead of a polar-sorted fan.

Contacts balance the mass-weighted corrections of all touching particles and retain their direction through tiny numerical changes. Additional damping removes local contour vibration. A floor-supported connected pile sleeps after 0.8 seconds of quiet motion, keeping its squashed shape without continued jitter. An incoming impact, merge, hammer or bomb wakes the pile; unsupported and spilled animals never sleep in mid-air. A distant new drop does not shake an already resting pile.

### v2.3 top drop and bottom-right NEXT

The waiting animal and actual release point are at the top of the playfield, just below the compact coins/score/best row. All three droppable species are fully visible across the aiming range. The NEXT card sits at the bottom right, beside the complete seven-animal evolution strip. Mouse and touch aiming work in the new top area, and interacting with NEXT never drops an animal. The aim line stops at the first stacked animal, including animals already above the rim.

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
| Fox | Pink lilac | 120 | 250 |
| Sheep | Pearl/lavender white | 95 | 350 |
| Penguin | Charcoal and cream | 83 | 500 |
| Unicorn | Pale lavender | 138 | 800 |

The new hamster is exactly the size of the previous version's bunny. The first drop is always Chick. All subsequent drops use Hamster / Chick / Bunny / Capybara (30% / 30% / 30% / 10%). Unicorn is the final level; two unicorns do not merge further.

**Overflow rule:** there is no height countdown and no wall above the cup rim. Animals can pile up above the opening and physically tumble over either edge. The game ends only when an animal outside the cup reaches the table at the visible cup-bottom height. Landing on the floor *inside* the cup is safe. The rim is y=401, interior floor y=799, and outside table y=851 in the 540 × 960 logical canvas.

The hammer removes one tapped animal. The bomb clears animals within 115 units of the tapped animal. Every new cup starts with zero of each and zero coins. Merges earn coins equal to merge points divided by ten; tap the coin bar or an empty tool button to buy one hammer (100 coins) or bomb (180 coins). Each type is limited to three successful purchases per cup, independent of remaining inventory. Insufficient funds or a sold-out allowance never deducts coins. There are no payments, ads, accounts, or network services.

Best score, lifetime merges, music and sound settings persist locally. Coins, cup progress, inventory and purchase counts reset on restart or app launch. Legacy saved coin balances are ignored; BEST is retained. The app reads a previous v1 save if a v2 save does not yet exist.

## Exact supplied artwork

- `assets/source/animals.png`: the original 7-column × 3-row sheet, unchanged.
- `assets/source/new_animals.png`: approved Fox/Sheep/Penguin 3 × 3 transparent sheet, unchanged.
- `assets/source/evolution-ten-v28.png`: the latest ten-animal evolution-strip attachment, unchanged; sampled without the surrounding transparent padding.
- `assets/source/evolution-ten.png`: the previous v2.7 strip, retained.
- `assets/source/buttons.png`: original interface sheet, unchanged.
- `assets/source/cup.png`: original cup image, unchanged.
- `assets/source/layout-reference.png`: original interface reference, unchanged.
- `assets/room.png`: a clean room background generated from the layout reference.
- `assets/audio/puzzle_song.mp3`: unchanged user-provided music, originally named `パズルのうた.mp3`.

Gameplay animals sample both approved expression sheets through deforming meshes. Happy, squeezed, and spiral-eyes-with-tears states use rows 1, 2, and 3, respectively. Separate atlas mappings preserve each species, including the original unicorn moved to level ten. Original white-background art uses its ink boundary; transparent sprites use their opaque silhouette. Both stay inside the circular/deformed physics outline.

Buttons use clipped atlas regions from the supplied sheet, with live numbers replacing example numbers. The cup's original rim, ears, side borders and paw-print base are drawn in separate back/front layers; its interior remains transparent. There are no baked glass reflections covering animals. The new ten-animal evolution strip remains visible along the bottom.

## Soft bodies

Each animal has 20 movable contour particles, edge constraints, area preservation and elastic shape recovery. The textured mesh stays within the collision envelope. Two physics substeps and five shape/contact iterations per frame are followed by adaptive contact-only relaxation, up to 32 passes. Floor-supported sleeping islands avoid perpetual contour vibration once settled. Cup walls have finite, two-sided swept collisions and hard interior/exterior constraints; the top is open. Pressure drives the three original expression rows.

### v2.2 music and softer animals

The new background track loops from the beginning at 30% amplitude (about -10.46 dB), with sound effects controlled independently. Upgrading from the old synthesized track enables the new MP3 once; later music-switch choices are saved normally.

The merge's initial upward velocity is reduced from 65 to 13 logical units per second (20%). A newborn keeps the parents' midpoint and flattens against the floor instead of snapping upward to fit a rigid circle. Shape recovery and edge stiffness are lower, with more damping of contour motion while in contact. Animal sizes and target areas are unchanged: bodies deform more easily while preserving their volume. The rigid cup and grounded-overflow rule remain in effect.

### v2.1 rigid-cup fix

Animals cannot squeeze through either side or the floor, including immediately after a larger animal is created by a merge. Hard boundary projection recovers deep penetration even when both Verlet positions have already crossed a wall. Inside/outside ownership only changes when the animal crosses above the open rim. Smoothed artwork uses the same boundary constraint so interpolation cannot visually protrude through the cup. The animals remain soft and elastic; only the cup is rigid. Existing assets, sizes, controls and overflow game-over rules are unchanged.

## Development

- `scripts/main.gd`: English interface, input, game state, local tools and records.
- `scripts/animal_data.gd`: evolution order, sizes, palette and points.
- `scripts/sprite_painter.gd`: 30 atlas regions across both approved sheets and textured soft-body rendering.
- `scripts/cup_layout.gd`: shared artwork/physics cup translation.
- `scripts/asset_art.gd`: original UI artwork and layered cup.
- `scripts/soft_body.gd`: elastic particle ring and pressure.
- `scripts/soft_world.gd`: finite cup walls, merges and grounded overflow.
- `scripts/sound.gd`: supplied looping MP3 and synthesized sound effects.
- `tests/test_suite.gd`: gameplay, collision, overflow, assets and inventory checks.
- `tests/test_no_overlap.gd`: polygon intersection checks, deep squash, crossing edges, newborns and maximum-speed drops.
- `tests/test_rest.gd`: stationary contour jitter, settling time, supported sleep and impact/removal/merge wake-up checks.
- `tests/test_sliding.gd`: live face-UV stability, side gliding, zero rebound and removal of local contact vibration.
- `tests/test_render_stability.gd`: actual-renderer frame sequence and exact resting-pixel comparison.
- `tests/test_ten_animals.gd`: late shrink/grow merges, crowded final species, all expression mappings, lower cup alignment and removed greetings.
- `tests/test_round_economy.gd`: opening Chick, four-species probabilities, top-right NEXT, full-width strip, per-cup balances, tool prices/limits, restart controls and isolated legacy-save migration.

```sh
godot --path .
godot --headless --path . --script res://tests/test_suite.gd
godot --headless --path . --script res://tests/test_no_overlap.gd
godot --headless --path . --script res://tests/test_rest.gd
godot --headless --path . --script res://tests/test_sliding.gd
godot --path . --script res://tests/test_render_stability.gd -- --showcase --render-output=/absolute/existing/directory
godot --headless --path . --script res://tests/test_round_economy.gd
godot --headless --path . --script res://tests/test_loading_records.gd
godot --headless --path . --export-release macOS builds/MochiAnimals-v2.9-Mac.zip
```

Visual QA options after `--`: `--showcase`, `--capture=/absolute/path.png`, `--capture-mode=expressions`, `--capture-mode=home`, `--capture-mode=wall-regression`, `--capture-mode=overflow-layout`, `--capture-mode=overlap-regression`, `--capture-mode=sliding-regression`. The wall regression stages the reported cat-and-chicks arrangement without merging. The overflow layout stages a unicorn/dog/cat pile with animals above the rim. The overlap regression stages a six-tier pile with small animals compressed underneath; sliding-regression reconstructs the cat/chick/hamster arrangement from the user's recording. Use `--showcase` with capture modes when no capture path is supplied to disable persistence. A normal launch starts with an empty cup.

Additional visual QA modes: `--capture-mode=fresh-cup`, `--capture-mode=shop`, `--capture-mode=shop-limit`, and `--capture-mode=ten-animals`. These should be combined with `--showcase` or a capture output so previews never touch player records.

v2.9 adds `--capture-mode=loading`, `--capture-mode=top-three`, and `--capture-mode=top-three-empty`, paired with `--capture=/absolute/path.png`. Normal startup now routes through `scenes/loading.tscn`; `scenes/main.tscn` remains the gameplay scene.

Desktop output is a universal Apple Silicon / Intel build. Mobile touch handling is implemented, but iOS/Android device builds and store packaging have not been verified. The Mac app is locally ad-hoc signed, not Apple-notarized.
