# Asset provenance

The animal, interface and cup PNGs in `assets/source/` are unchanged copies of the user-provided files. Their rendering uses atlas coordinates, original pixels and Godot clipping meshes, including transparent cup layering. They were not regenerated.

Only `assets/room.png` was generated, with the built-in image generation tool and the imagegen skill. The supplied full-screen interface image was the edit target. The resulting background was copied into the project so the game has no external asset dependency.

Final generation prompt:

> Use case: precise-object-edit. Asset type: portrait 9:16 mobile game background only. Input image 1 is the edit target. Remove ALL foreground game elements: the entire glass cup, all animals, all buttons, every score or coin panel, NEXT panel, dotted line, all text, bottom evolution strip. Reconstruct the empty background behind them. Preserve the original warm pastel cozy room: blurred soft curtains and window on left, subtle potted plants, small paw print picture on wall, peach room, warm light wooden tabletop at lower third. Strong dreamy depth-of-field blur, calm creamy peach tones. The tabletop surface should span the lower third and support a game cup that will be added by code later. No glass, no cup, no animal, no interface, no symbols except faint existing wall picture, no letters or numerals. Keep camera and lighting. Full-bleed portrait background.

Opaque background output was requested. The animal sprite sheet, button sheet, and cup image were never input to an image-generation call.
