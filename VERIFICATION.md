# v2.9 verification — loading, layout and local Top 3

Godot 4.7.1 on macOS / Apple M2. Desktop-only update; no GitHub or Netlify changes.

**234 / 234 final automated checks passed**: gameplay/audio/cup 86, non-overlap 13, sleep/wake 15, sliding 6, slime 9, ten animals 24, round economy 48, NEXT capsule 9, loading/records 24. New checks cover empty ranks, descending order, tied scores, one record per completed cup, real outside-ground game-over recording, restart exclusion, legacy BEST migration, fresh-instance persistence, malformed entries, aligned cup boundaries, loading atlas bounds and actual threaded-load completion. Saves used isolated temporary fixtures, not the player's save.

Cup translation is now 67 total (+24 from v2.8.1): rim 425, interior floor 823, outside loss ground 875. The strip is y=894 to ~951. Original gameplay art, animal data, physics solver, soft-body parameters, sprite painter and audio scripts remain unchanged.

Test-fixture note: the first run left the crowded rest fixture at its previous absolute screen positions, increasing release heights relative to the lowered cup. That different arrangement failed two rest checks (0.254-pixel maximum contour step and 8.157-pixel four-second drift). The fixture now translates its seed positions with the cup to retain the same relative scenario; all 15 checks pass, with the crowded case asleep after 6.98 seconds and zero final contour movement. No solver adjustment or relaxed tolerance was used. These finite checks do not guarantee every possible pile settles equally quickly.

Actual loading, fresh-cup and Top 3 screenshots were captured and inspected. Startup transitions automatically into the game; the footer is absent and the strip remains fully visible. The loader's progress uses real resource status, not simulated percentages; only its minimum presentation hold and unicorn animation are time-based. Reference images are copied byte-for-byte and are startup-only.

The actual Compatibility-renderer regression also passed: resting cup pixels are byte-identical across 120 further physics frames, and stationary animals reuse the same GPU meshes.

The universal Mac v2.9.0 export, ZIP integrity check, and strict deep ad-hoc code-signature verification passed. App: `builds/Mac-v2.9/Mochi Animals v2.9.app`; archive: `builds/MochiAnimals-v2.9-Mac.zip`. Previous builds are retained, with source backup at `builds/backups/source-before-v2.9.zip` (integrity checked). This is not Apple-notarized.

The packaged app independently launched through the loader, reached the fresh game, captured `builds/Mac-v2.9/preview-game.png`, and exited successfully. Its screenshot was visually inspected. No script/runtime errors occurred; the shutdown ObjectDB warning below remains. Loading and leaderboard previews are saved alongside it.

The unthreaded Web export contains a 38 MB WASM, 16 MB PCK, the custom startup shell and supplied 2.3 MB cover. A local Chromium run at 390×844 loaded the cover, removed it after engine startup, entered the game and reported no console/page errors. Production deploy `6ac651478687559948a7ffdb` was published atomically to `https://mochianimals.netlify.app`; the live URL and deploy state were rechecked after publication. This is a browser-size simulation on the Mac, not a physical-phone test.

Some sandboxed headless runs report an unrelated macOS system certificate lookup error; checks still complete. Automated shutdown currently reports ObjectDB resource warnings (2 in the render regression, 9–11 in threaded-loader checks/previews). No sustained performance claim is made.

## Historical v2.8.1 verification — NEXT artwork only

**57 / 57 focused checks passed**: nine new capsule checks and the existing 48 round-economy/UI checks. The approved PNG is byte-identical to the generated original, retains transparent background/window, and is uniformly scaled. The live animal preview fits within the circular opening. NEXT keeps its top/right anchors and height; only its width/input footprint follows the narrower capsule. The existing aiming formula itself is unchanged and now clears NEXT at the normal right release bound for all four droppable animals.

Source comparison against `builds/backups/source-before-v2.8.1.zip` confirms `main.gd` changed only NEXT's rectangle, NEXT drawing and the version title. Animal data, physics, sprite rendering, cup layout, audio and project settings are byte-identical. No economy, probabilities, tool limits, other UI geometry or persistence behaviour changed.

The exported app was independently launched and its screenshot visually inspected. For an exact visual regression, a second capture disabled mouse input and fixed aim at the previous screenshot's x=265: 8,105 pixels changed inside the old NEXT area; **zero pixels changed outside it** compared with v2.8's opening screenshot. The first interactive capture used a different live pointer position, so it was not used for that pixel assertion.

The v2.8.1 universal Mac export, ZIP integrity and strict deep local code-signature checks passed. App: `builds/Mac-v2.8.1/Mochi Animals v2.8.1.app`. Archive: `builds/MochiAnimals-v2.8.1-Mac.zip`. Preview: `builds/Mac-v2.8.1/preview-v2.8.1.png`. The app exited successfully without script/runtime errors; the known automated-shutdown ObjectDB warning remains. No sustained-performance, notarization or mobile verification is claimed. No GitHub upload; previous builds are retained.

## Historical v2.8 verification

Environment: macOS / Apple M2 / Godot 4.7.1 stable. Changes remain in the desktop project; no GitHub upload.

**201 / 201 automated checks passed**: gameplay/audio/cup 86, non-overlap 13, sleep/wake 15, sliding/face mapping 6, slime 9, ten-animal integration 24, and new round-economy/UI integration 48.

- Every new cup opens with Chick; subsequent weighted rolls include only Hamster, Chick, Bunny and Capybara. In 100,000 deterministic rolls the counts were 29,933 / 30,033 / 30,068 / 9,966, consistent with 30% / 30% / 30% / 10%. Five hundred resets retained the first Chick, while NEXT could contain Capybara.
- Every cup begins with zero coins, zero hammers, zero bombs and three available exchanges of each type. Merge rewards remain 1 / 3 / 6 / 10 / 15 / 25 / 35 / 50 / 80 coins across the nine upgrades.
- Shop inputs charge exactly 100 coins per hammer and 180 per bomb. Insufficient funds and a fourth purchase never charge coins or consume an allowance. Using all three tools does not reopen purchases. Independent 3+3 exchanges cost exactly 840 coins.
- Restart/game-over confirmation via buttons and keyboard resets the round economy and first animal while preserving BEST. HOME/PLAY resumes the same cup without resetting coins. An isolated legacy-save fixture confirmed old coin balances are ignored, BEST persists through save and relaunch, and no round balance or inventory is saved. Automated tests and previews never touch the player's real save.
- NEXT is above the right settings column; every droppable animal clears it at both aim extremes. The new original PNG is byte-for-byte identical to the supplied attachment. The full-width bottom strip uses the artwork region's aspect ratio and clears the instructions. Clicking or releasing over NEXT/the strip never drops a ball.
- Actual Compatibility-renderer screenshots of the fresh cup, zero-inventory shop and sold-out shop were captured and visually inspected. They show the relocated NEXT, full-width ten-animal strip, opening Chick, zero coins/tools, correct prices, live inventory badges and remaining/SOLD OUT labels.
- Original animal/cup/buttons/music and the physical solver are unchanged. Existing hard-wall, non-overlap, sleeping, sliding, late shrink/grow merges, grounded overflow and MP3 regressions pass. No sustained FPS or mobile-device claim is made.

Before-update source: `builds/backups/source-before-v2.8.zip` (ZIP integrity checked). Previous Mac apps are retained.

The universal v2.8.0 Mac export, ZIP integrity and strict deep local code-signature checks passed. The delivered app is `builds/Mac-v2.8/Mochi Animals v2.8.app`; its archive is `builds/MochiAnimals-v2.8-Mac.zip`. The packaged app independently rendered the new opening screen, saved `builds/Mac-v2.8/preview-v2.8.png` (visually inspected), and exited with code 0 without GDScript/runtime errors. The automated shutdown reports two ObjectDB instances, as in the previous release. Brief screenshot FPS samples varied widely and are not a sustained performance measurement. No Apple notarization or mobile export was performed.

## Historical v2.7 verification

Environment: macOS / Apple M2 / Godot 4.7.1 stable. All updates are in the desktop project; no GitHub upload.

**152 / 152 automated checks passed**: gameplay/audio/cup 85, non-overlap 13, sleep/wake 15, sliding/face mapping 6, slime 9, and ten-animal integration 24.

- Exact order: Hamster → Chick → Bunny → Capybara → Cat → Dog → Fox → Sheep → Penguin → Unicorn. Every pair-to-next-level transition, score and terminal Unicorn was exercised.
- Approved nominal diameters: 78, 96, 118, 144, 172, 204, 240, 190, 166, 276. Both shrinking merges and the final growing merge create the correct target radius and area, fall into available space, and start without overlap.
- The late-game crowded fixture includes Fox, Sheep, Penguin and the enlarged Unicorn together. Across 480 simulation frames, maximum rendered polygon intersection was zero; cup boundary error was below 0.00004 logical pixels. Individual late-stage merges were also checked over 420 frames each.
- All thirty expression mappings are distinct and use the correct source texture, including original Unicorn artwork at index 9. The real expression-gallery window was captured and visually inspected.
- The original cup art, translucent fill, rim, solid walls/floor and outside ground all move down by 43 units. New rim y=401, interior floor y=799, loss ground y=851. The new evolution strip retains its original aspect ratio and clears both the cup and NEXT.
- Every first-discovery greeting, including the final Unicorn greeting, is removed. Score, best, highest species, merge sounds, point popups and particles remain connected. Tool and purchase messages use a separate position above the cup.
- The real game window was captured with all four late animals together; the lower cup, new artwork and complete ten-animal strip were visually inspected. Source PNGs are copied unchanged; mipmaps improve downscaled rendering.
- Existing hard-wall, open-rim overflow, top-drop controls, no-bounce sliding, stable face mapping, rest/wake, inventory, MP3 loop, 30% initial music volume and saved preference checks continue to pass.
- The actual Compatibility renderer also passed both final visual regressions: the translated cup's resting pixels are identical over 120 additional physics frames, and every resting animal reuses its GPU mesh.

The v2.7.0 Mac export, ZIP integrity and strict deep local code-signature checks passed. The exported app is `builds/Mac-v2.7/Mochi Animals v2.7.app`; the archive is `builds/MochiAnimals-v2.7-Mac.zip`. The packaged app independently rendered the late-game fixture and saved `builds/Mac-v2.7/preview-v2.7.png`, which was visually inspected. A repeat launch also captured successfully and exited with code 0, with no script/runtime errors. Startup capture samples varied from 2 to 76 FPS and are not a sustained performance benchmark. The release template reports two ObjectDB instances at automated shutdown, as in the previous release. No Apple notarization or mobile export was performed.

Previous source: `builds/backups/source-before-v2.7.zip`. Previous Mac builds are retained. Finite deterministic fixtures and local visual checks do not cover every future arrangement or mobile device.

## Historical v2.6 verification

Environment: macOS, Apple M2, Godot 4.7.1 stable, Compatibility/OpenGL renderer. Reference: the supplied 35.407-second `ScreenRecording_10-05-2026 18-59-16_1.MP4`; sampled frames show soft shapes spreading into the stack and resting against rigid barriers.

## Measured changes

- A hamster sliding against either sloped wall from y=430 reaches y=700 in **0.65 s**, versus **2.12 s / 2.03 s** in v2.5. Wall penetration remains below 0.00004 logical pixels. Both wall projection paths preserve tangential velocity; repeated contact smoothing does not reduce bulk velocity.
- The same unicorn-on-cat load now produces strain **0.2671**, with **99.69%** target area retained and the unchanged radius of 86. Shape/edge stiffness changed from 0.0075/0.10 to 0.005/0.075. There is no merge launch impulse or restitution.
- Single, loaded, crowded and corner fixtures settle in approximately **1.58 / 3.18 / 4.73 / 1.97 s**. Their final four-second contour measurements show zero movement. Supported sleeping, impact wake-up and support removal remain covered.
- The off-centre hamster slides **62.47 logical pixels** past a unicorn, with zero measured upward step and zero polygon intersection. The anchored face mesh has zero centre-UV error during live deformation.
- The actual game renderer's resting cup pixels are identical across 120 further simulation frames. All resting bodies retain the same mesh objects during that interval, verifying that the rendering cache is exercised.

Deterministic stress benchmark (`tests/benchmark_slime.gd`), 240 fixed 60 Hz physics steps per scenario, same machine, before/after runs without competing benchmark processes:

| Animals | v2.5 mean ms | v2.6 mean ms | v2.5 p95 ms | v2.6 p95 ms |
| --- | ---: | ---: | ---: | ---: |
| 10 | 29.79 | 9.67 | 30.91 | 10.84 |
| 20 | 54.88 | 23.67 | 71.46 | 24.07 |
| 30 | 109.33 | 36.99 | 116.13 | 38.02 |

This measures CPU physics, not end-to-end FPS. The fixture intentionally disables merges and continues simulating overfull stacks after a normal game would end. Mean work is reduced by approximately 57–68%; very dense active piles still exceed a 16.7 ms frame budget in the debug engine. No mobile-device or universal 60 FPS claim is made.

## Regression coverage

**122 / 122 headless checks passed** in the final source run: gameplay/audio/cup (79 checks), non-overlap (13), sleep/wake (15), face mapping/sliding (6), and new slime/wall/cache regressions (9). The no-overlap suite checks actual physical and rendered polygon intersections in a crowded pile, edge-only crossings, concave contacts, stretched bounds, newborn merges, maximum-speed mixed-size drops and 1,500 frames of merging. The separate real-window render regression also passed its stationary-pixel and mesh-reuse checks on the final source.

The isolated opposing-wall squeeze fixture now extends its walls to y=3000 rather than y=1000, because removing friction lets the falling test body leave the old short walls before the assertion. Its deformation requirement is unchanged.

Original animal/UI/cup artwork, radii, English UI, top release point, bottom-right NEXT, MP3 settings and overflow rules are retained. The animal, button, cup and MP3 files compare byte-for-byte identical to the before-update archive. Changes are local only; no GitHub operation. The before-update source is saved as `builds/backups/source-before-v2.6-2026-10-05.zip`; older app builds are retained.

The universal v2.6.0 Mac export, ZIP integrity and strict deep local code-signature checks passed. The exported app is `builds/Mac-v2.6/Mochi Animals v2.6.app`; the archive is `builds/MochiAnimals-v2.6-Mac.zip`. Sandbox-only system certificate access and editor-preference-save messages occurred during headless verification/export, but no GDScript errors. No Apple notarization or mobile export was performed.

The exported app was independently launched with the six-animal sliding fixture. It rendered successfully, saved `builds/Mac-v2.6/preview-v2.6.png` (visually inspected), and exited with code 0 without script/runtime errors. Its early screenshot sample reported 42 FPS; this short startup sample is not a sustained frame-rate benchmark. The release template reported two ObjectDB instances at automated shutdown, as a shutdown warning rather than a failure to run. Preview/test runs do not write saved game records.

## Historical v2.5 verification

Environment: macOS, Apple M2, Godot 4.7.1 stable, actual Compatibility/OpenGL renderer.

**113 / 113 headless checks passed**, plus the actual-renderer pixel-stability check:

- 79 gameplay/audio/cup checks, 13 non-overlap checks, 15 rest/wake checks, 6 sliding/render-mapping checks.
- Inspected consecutive frames of the supplied 7.397-second recording. The cat, chicks and hamsters showed changing facial texture placement despite small outline changes. Reconstructed that six-animal arrangement in a deterministic fixture.
- On the same simulated contours, v2.4 ear-clipping produced a maximum 37.79-atlas-pixel jump in the face-centre UV. The new anchored mesh has zero face-centre UV error throughout 360 moving/settling frames; every contour in this fixture passes the fan visibility check.
- A small animal landing off-centre on a unicorn slides 83.59 logical pixels to the side in the glide regression. Maximum upward step and polygon intersection area are both zero.
- Cup contact has zero reflected normal velocity while retaining tangential velocity. Contact damping leaves zero oscillating local particle velocity, while retaining bulk sliding.
- Merge upward impulse is now zero, as requested for the no-bounce version. The old 20% impulse expectation was replaced with zero-impulse/no-hop assertions; target radii and areas are unchanged.
- Single, loaded, six-tier crowded and corner fixtures settle after approximately 1.58, 2.98, 5.62 and 2.35 seconds; all have zero contour motion over the final four-second measurement window.
- Maximum-speed impacts, repeated merging, finite-wall overflow, exact original assets, top launch/NEXT controls, music loop and support-removal wake-up regressions continue to pass.
- Ran the actual game window, captured and inspected frames 30, 90, 180, 359 and 479. The resting cup's rendered pixel data at frames 359 and 479 is identical across 120 intervening simulation frames. This verifies displayed artwork, not only hidden physics points. Test runs do not change saved records.
- Removed a 2D-MSAA option unsupported by the Compatibility renderer. The stable mesh stays inside the same collision envelope and adds no outward fringe.

The universal v2.5.0 Mac export, ZIP integrity check and strict local code-signature verification passed. The delivered `builds/Mac-v2.5/Mochi Animals v2.5.app` was independently launched with the recorded arrangement, rendered successfully, saved `preview-v2.5.png` alongside the app and exited with code 0. There were no GDScript/runtime errors; the release template emitted an ObjectDB shutdown warning after the automated screenshot exit. Window titles include v2.5 so the new app can be distinguished from retained old copies.

This update is saved only to the desktop project; no GitHub upload. Existing builds and a before-v2.5 source backup are retained. Limits: the supplied recording, deterministic fixtures and finite-duration sessions are covered, not a proof of every possible future arrangement or device. Mobile exports and Apple notarization remain unverified.

## Historical v2.4 verification

Environment: macOS, Apple M2, Godot 4.7.1 stable.

Automated checks: **107 / 107 passed** (79 gameplay/audio/cup checks, 13 non-overlap checks, 15 rest/wake checks).

- Before the fix, the six-tier crowded fixture produced up to 2,864 square logical pixels of physical overlap and 3,021 of visible outline overlap. Crossing-edge, concave-contact, stretched-bound and newborn tests also failed.
- The updated collision and rendering envelopes produce zero measured intersection area in the same fixture, in maximum-speed mixed-size overflow drops, and during 1,500 frames of repeated drops and merges.
- The four stationary fixtures (single, loaded, six-tier crowded and cup corner) all have exactly zero contour movement over the final four-second measurement window. They settled after approximately 1.58, 2.90, 5.52 and 2.28 seconds, respectively.
- Before stabilization, the crowded fixture could move a contour vertex more than eight logical pixels in one frame even after twelve seconds. Mass-balanced contacts, small normal hysteresis, contact damping and supported-island sleeping eliminate this in the tested fixtures.
- A distant drop leaves the supported pile asleep. Its impact wakes and deforms the pile. Removing the bottom support immediately wakes the remaining animal, which falls into the space. Sleeping animals can still merge, and unsupported animals do not freeze in mid-air.
- The rigid cup, actual rim overflow and outside-ground loss tests still pass. Nominal sizes, 20% merge impulse, original artwork, top release position, bottom-right NEXT and looping MP3 at 30% remain unchanged.

GUI visual verification for v2.4 was not completed: the tool's automatic approval review for launching the game window failed because of an account usage limit. Physics, outline triangulation, polygon intersections, gameplay and audio were tested headlessly; this is not a claim of interactive visual QA. Prior version screenshots are retained but are not v2.4 previews.

The universal macOS v2.4.0 export completed successfully. Its ZIP integrity and strict local code-signature verification passed. The extracted app is `builds/Mac-v2.4/Mochi Animals.app`; the archive is `builds/MochiAnimals-v2.4-Mac.zip`.

The packaged executable also completed a 180-frame headless launch of the crowded regression scene and exited with code 0, with no GDScript errors. This sandboxed release-template run reported a macOS system-certificate access error and an ObjectDB shutdown warning; therefore it is not recorded as a warning-free interactive launch. The game itself uses no network services.

This update is local to the desktop project. No GitHub push or upload was made. Previous desktop builds are retained. Long play sessions, mobile hardware and other operating systems have not been verified.

## Historical v2.3 verification (before this update)

Environment: macOS, Apple M2, Godot 4.7.1 stable.

**Automated checks: 79 / 79 passed.**

- Fixed English evolution order, larger sizes and weighted drop pool.
- All six merges, exact points, terminal unicorn, contact deduplication and chain reactions.
- Circular rest state, elastic recovery, area preservation and all three pressure states.
- Actual opposing-wall deformation; stacking without interior wall/floor penetration.
- Deep penetration recovery even when both Verlet positions are already outside.
- Immediate containment of a larger newborn against a bottom corner and a real side-wall merge.
- Sustained pressure against both sides and the floor; maximum-speed impacts in all three directions.
- The reported cat-and-chicks arrangement remains inside through 600 simulation frames, including every smoothed artwork vertex.
- No rim timeout, no invisible wall above the opening, no loss during an outside fall.
- Loss only at outside ground contact; cup-floor contact stays safe.
- A real overfilled stack naturally spills over finite walls.
- Original 21-expression atlas and original UI/cup textures loaded.
- Input bounds, drop cooldown, pause, restart, scoring and retained best.
- Hammer, bomb and local coin purchases.
- Merge velocity is 13 units/second (20% of the previous 65); negligible free-flight hop and no floor-radius snap.
- More deformation under the same load with unchanged nominal size, at least 98% area retention, and under 2 pixels of settled vertical motion.
- Supplied MP3, automatic start, 30% amplitude, music toggle, saved preference, and migration from the old default-off synthesized track.
- Actual playback near the MP3 end crosses the boundary and resumes at the start while remaining active.
- Aiming and clicking in the new top launch area create the actual animal above an overflowing stack.
- Clicking NEXT or releasing a drag over its upper edge does not drop an animal.

Enlarged-animal stacking benchmark: approximately 8.41 ms per physics frame on this machine during parallel visual QA; minimum area retention was approximately 99%. This is a physics benchmark, not a guaranteed frame rate for every device.

Under an identical unicorn-on-cat load, measured cat deformation increased from 0.1031 to 0.1401 while its nominal radius stayed 86 and its area stayed at 99.49% of the target. The additional squash comes from shape deformation, not smaller animals. Because softer bodies can settle differently, the overflow regression fills the cup until a real rim spill instead of requiring a fixed six-drop quota.

The animal, button and cup source files were checked against the uploaded originals with SHA-256. All three match byte for byte. The rendered interface has live English labels and original atlas artwork. Preview images use seeded test stacks; normal launches start empty.

The Godot project was launched with the wall-regression test arrangement and its screenshot inspected. Both chicks remain against the rigid inner walls, with no side-wall protrusion. The normal artwork and soft-body deformation are retained.

The v2.3 desktop project was launched with the overflow-layout arrangement and captured successfully, with no runtime errors. The waiting chick is fully visible near the top, clearly separated from the bunny and chick above the rim. NEXT is at the bottom right, beside all seven evolution icons. The top status cards do not overlap the waiting animal. Music playback and looping were verified through the audio player; subjective loudness depends on the device volume and source mastering.

The app, ZIP and preview are in `builds/`. The prior v2.2 build is retained. This update was saved only to the desktop project; no GitHub upload was made.

The exported universal Mac app was independently launched and captured with the overflow-layout fixture. It reports version 2.3.0 and starts without runtime errors. The archive integrity and strict local code-signature checks passed. `builds/preview-v2.3.png` shows the layout rendered by this exported app.

Not verified: real mobile hardware, mobile export/signing, other operating systems, or very long sessions. No Apple notarization or store publishing was performed.
