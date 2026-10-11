# Asset provenance

## v3.0 present-box button

`assets/ui/gift.png` is a 160×160 transparent runtime resize of a new PNG generated using the built-in image-generation tool and imagegen skill. Source: `/Users/mac/.codex/generated_images/01a0eda9-96fd-71b3-9061-54546655b502/exec-e77920d1-c70b-450b-b980-70af5c11a1b6.png`. The existing user-supplied button sheet was a style reference only. No animal, cup, loading or other button artwork was regenerated. PNG resize/optimization preserved alpha. REVIVE uses native Godot panel/text styling, not edited atlas pixels.

Final prompt:

> Use case: stylized-concept. Asset type: one transparent PNG game UI button. Use the supplied Mochi Animals button sheet as STYLE REFERENCE ONLY. Generate ONLY ONE circular cream/ivory button matching the reference's small circular settings button: caramel brown fine outer rim, soft peach raised bevel, warm cream surface, soft tiny bottom shadow. Replace the gear emblem with a large cute rounded pink PRESENT BOX with an apricot orange bow and ribbon. Centered straight front view, readable silhouette at 45px, kawaii soft candy shading, tasteful highlights. Button fills 90% of a square canvas, evenly centered. No text, no numbers, no extra buttons, no characters, no decorative particles, no outer background. Genuine transparent pixels outside the round button.

Latest static cover: `assets/loading/static-cover.png` is an unchanged copy of `codex-clipboard-ac6af6f6-02d6-4ead-b9e3-6a593991274d.png` (1672×941), supplied by the user. Web CSS and Godot texture layout scale it proportionally to cover the loading viewport, with centered cropping for portrait screens. No image generation or pixel editing was performed.

## v2.9 loading artwork

`assets/loading/reference.png` and `assets/loading/sheet.png` are unchanged copies of the two user attachments dated 2026-10-07 (`codex-clipboard-5160dd30-d154-4a02-8921-28c1e4350974.png` and `codex-clipboard-f935b4c7-7d42-4dcf-bfb6-8e71091a88e9.png`). Godot samples the combined sheet through texture regions for the background, logo, bridge group, loading-bar layers and four unicorn frames. No bitmap editing or image generation was performed. These textures are not used by the gameplay scene; original gameplay artwork is unchanged.

The animal, interface and cup PNGs in `assets/source/` are unchanged copies of the user-provided files. Their rendering uses atlas coordinates, original pixels and Godot clipping meshes, including transparent cup layering. They were not regenerated.

The original background `assets/room.png` was generated with the built-in image generation tool and the imagegen skill. The supplied full-screen interface image was the edit target. The resulting background was copied into the project so the game has no external asset dependency. The later approved three-species sheet is described below.

Final generation prompt:

> Use case: precise-object-edit. Asset type: portrait 9:16 mobile game background only. Input image 1 is the edit target. Remove ALL foreground game elements: the entire glass cup, all animals, all buttons, every score or coin panel, NEXT panel, dotted line, all text, bottom evolution strip. Reconstruct the empty background behind them. Preserve the original warm pastel cozy room: blurred soft curtains and window on left, subtle potted plants, small paw print picture on wall, peach room, warm light wooden tabletop at lower third. Strong dreamy depth-of-field blur, calm creamy peach tones. The tabletop surface should span the lower third and support a game cup that will be added by code later. No glass, no cup, no animal, no interface, no symbols except faint existing wall picture, no letters or numerals. Keep camera and lighting. Full-bleed portrait background.

Opaque background output was requested. Original animal, button and cup pixels are preserved; this update does not regenerate them.

## Approved three-species atlas and ten-animal strip (v2.7)

`assets/source/new_animals.png` is a byte-for-byte copy of the approved `Desktop/MochiAnimals-New-Assets/fox-sheep-penguin-3x3.png`. It was generated earlier in this conversation using the built-in image generator, with the existing animal atlas and the user's ten-animal concept as style references. The user approved it before integration. Columns are Fox, Sheep, Penguin; rows are happy, squeezed, spiral eyes with tears. Fox has no flower. Internal ears, horns and wool details remain within each round sprite. No pixel edits or new image generation were performed during v2.7 integration.

The earlier generation prompt requested a transparent 3×3 game sprite sheet matching the original kawaii mochi atlas, perfect circular silhouettes, all features contained inside the circle, no fox flower, no labels or background. A follow-up corrected the sheep contour, transparent gutters and extreme-expression penguin beak. Godot samples the approved pixels through the existing soft-body mesh.

`assets/source/evolution-ten.png` is an unchanged copy of the user's `codex-clipboard-f3357a0e-066f-4802-9563-9ae11573d5c8.png` (2232×190). It is displayed as supplied, at its original aspect ratio, including the reference strip's own animal styling.

## Latest full-width evolution strip (v2.8)

`assets/source/evolution-ten-v28.png` is a byte-for-byte copy of `codex-clipboard-6711e879-49f6-4ff8-9a06-e95694bf6e58.png` (2172×724). The file contains substantial transparent outer padding with a few isolated low-alpha pixels. Godot samples its visible illustrated strip through `CHAIN_REGION` (8, 244, 2156, 238) and preserves that region's aspect ratio across the bottom of the game. No source pixels were edited and no artwork was regenerated. NEXT reuses the original supplied UI atlas, relocated above settings, with its live next-animal image.

## Approved vertical NEXT capsule (v2.8.1)

`assets/source/next-capsule.png` is a byte-for-byte copy of the user-approved image generated in this conversation at `/Users/mac/.codex/generated_images/01a0eda9-96fd-71b3-9061-54546655b502/exec-21dd59f0-0f04-4f6c-8b14-83a91ee412a3.png` (977×1610). The earlier built-in image-generation request specified a narrow upright cream/apricot pill, rounded cocoa NEXT text, an empty transparent circular preview window, and no animal, ears, paws or background. Integration does not regenerate or edit its pixels. Godot samples (70, 70, 836, 1470) to exclude transparent margins, scales uniformly, and inserts the next animal at source position (484, 960), radius 306.

## User-provided music (v2.2)

`assets/audio/puzzle_song.mp3` is a byte-for-byte copy of the user's `パズルのうた.mp3` (52.2 seconds, stereo, 48 kHz). No conversion, trimming or audio generation was applied. Playback uses the complete track, looping from the start at 30% amplitude.

SHA-256: `5ff7a6a8ab28565b7cdba75867482eeafaacf2c30699585b68f3988cb61d49a8`.
