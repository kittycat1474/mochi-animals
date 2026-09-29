# v2.1 verification

Environment: macOS, Apple M2, Godot 4.7.1 stable.

**Automated checks: 60 / 60 passed.**

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

Enlarged-animal stacking benchmark: approximately 6.78 ms per physics frame on this machine; minimum area retention was approximately 99%. This is a physics benchmark, not a guaranteed frame rate for every device.

The animal, button and cup source files were checked against the uploaded originals with SHA-256. All three match byte for byte. The rendered interface has live English labels and original atlas artwork. Preview images use seeded test stacks; normal launches start empty.

The Godot project was launched with the wall-regression test arrangement and its screenshot inspected. Both chicks remain against the rigid inner walls, with no side-wall protrusion. The normal artwork and soft-body deformation are retained.

The exported universal macOS v2.1 app was launched independently and captured with the same regression arrangement, with no runtime errors. The Mac ZIP passed archive-integrity checks and the extracted app passed strict local code-signature verification. Its bundle reports version 2.1.0. The captured image is supplied separately as `cup-wall-fix.png`.

Not verified: real mobile hardware, mobile export/signing, other operating systems, or very long sessions. No Apple notarization or store publishing was performed.
