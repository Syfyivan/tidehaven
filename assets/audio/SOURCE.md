# Tidehaven Original Audio Assets (0.19)

Generated deterministically by `tools/generate-audio.py` using Python's standard library (`math`, `wave`, `struct`, `random` with fixed seeds).
No external audio pack, commercial sample or third-party runtime dependency is used.
All files are 16-bit mono PCM WAV at 22,050 Hz, loaded directly by `scripts/game_audio.gd`.

| File | Duration | SHA256 | Purpose |
|---|---|---|---|
| `ui_click.wav` | 0.055s | `d3979afcb4d62258…` | Warm wooden tap for buttons, slots and panel toggles |
| `dialogue_open.wav` | 0.095s | `ee0555b076f0b821…` | Soft two-note reed chime when opening conversation |
| `hook_cast.wav` | 0.19s | `87aff5ae1f9c7cc4…` | Rope cast whoosh for salvage hook and fishing rod |
| `splash.wav` | 0.3s | `0fe6b8b277009540…` | Water splash on diving, surfacing and hook contact |
| `pickup.wav` | 0.17s | `dc05bd4fea50db6c…` | Rising wood marimba fifth on confirmed item gain |
| `build.wav` | 0.23s | `0837654e63ac9635…` | Double wooden mallet knock on confirmed deck/facility placement |
| `chop_hit.wav` | 0.115s | `0c735f402b0253f1…` | Crisp timber axe impact synchronized with blade contact |
| `tree_fall.wav` | 0.46s | `38a32c9a61269c58…` | Timber creak and soft fall on confirmed tree depletion |
| `mine_hit.wav` | 0.13s | `fd8f631e13afef88…` | Pickaxe stone/ore clink synchronized with mining swing |
| `spear.wav` | 0.16s | `654c9ed02c1bff03…` | Underwater harpoon thrust whoosh |
| `alert.wav` | 0.24s | `d7bec3ad63361683…` | Muted two-tone underwater warning for threat windup or low oxygen |
| `craft_ready.wav` | 0.32s | `398e82f917e139e1…` | Warm bell triad when processing finishes or new day begins |
| `sea_ambient.wav` | 4.0s | `4531e1157da879cd…` | Seamless 4s ocean wave swell ambient loop |
| `underwater_ambient.wav` | 4.0s | `268bc2f2f90a14c9…` | Seamless 4s deep underwater current loop |
| `island_ambient.wav` | 4.0s | `08bcc92fb8cc5172…` | Seamless 4s coastal island breeze loop |
