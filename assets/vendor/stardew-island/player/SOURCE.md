# Native matched player appearances

0.16: Appearance now exposes 2 bodies, 8 hairstyles, 6 hair colors, 8 shirts, 4 trouser colors and 6 skin tones. Defaults below are preserved for migrated saves. All selections use the same native layer composition and fixed foot across walking and tool frames. Each player owns their saved profile. Diving uses a separate matched hooded swim kit; it does not paste these heads onto a different body. See `assets/characters/swimming/SOURCE.md`.

Original PNGs from the user-authorized `ffffhx/stardew-valley-assets`, pinned at
`0c31854d40fcc1f6b60b35ac07b7c9686b82b226`. Authorization basis is the user's
explicit confirmation; this is not a claim that the upstream files have a public
open-source license. `manifest.json` records original Git blobs and SHA-256.
Restore with `python tools/import-player-art.py` (standard library only).

`scripts/player_art.gd` assembles matching native base, pants, shirt, hair and arm
layers on an unchanged 16x32 canvas. Host: male base, brown hair 0, green shirt 11,
blue pants; guest: female base, long warm brown hair 26, green shirt 17, brown pants.
Skin palette row 3 and shoes row 12 use the native palette tables. NPC artwork stays separate.
Idle, walking and tool poses use the same appearance and fixed (8,31) pixel foot.
This is the original matched layer system, not an NPC head pasted onto a new body.

References in the same pinned source archive:
- `FarmerSprite.cs:1185-1211`: walking frames; `1267-1364`: five-stage tool frames.
- `FarmerSprite.cs:832-835`: six-column 16x32 frame addressing.
- `FarmerRenderer.cs:68-100,492-558,609-781,849-901`: feature offsets, sleeves,
  clothing/hair placement, native arm layers and their depth order.
- `Game1.cs:15183-15563`: native four-direction axe positions and rotations.
- `Tool.cs:442-515` and `Data/Tools.json`: axe atlas indices 189 through 193.

The tool metadata retains native asymmetry and rear-tool occlusion. Its source
crop and angle follow the original; final position is anchored to the matching
native arm's grip pixels, avoiding the original renderer's bounding-box/origin
offsets leaking into Tidehaven's fixed foot grid. The tool
callback starts during stage 2 in the original logic; the visibly lowered axe is
stage 3. This project can synchronize its visual contact to that actual pose
without importing the original game's rewards or network model. World contact
placement and animation timing are separately validated by Tidehaven.

Front/side tool grips are aligned to the corresponding visible native arm pixels.
Rear-facing hands are occluded by the original body/hair layers: the original
Game1 up-facing tool transforms are retained instead of inventing visible hand
coordinates. The last visible rear blade is body (7.5,7), or world (-1,-48)
relative to the fixed foot; stage 3/4 use the original tool occlusion.

No generated artwork or image resizing is used. PNG originals remain byte-for-byte
unchanged. Runtime recoloring follows the native clothing/palette system only.
The gallery is an inspection aid; passing composition checks does not establish
human visual acceptance or gameplay contact correctness.
