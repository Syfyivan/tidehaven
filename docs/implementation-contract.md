# Prototype 0.3 interface contract

Current differences from the retained 0.2 contract below:

- data.version=3, deck_tiles=["gx,gy"] with 64 px tiles; new raft gx6..8/gy3..5. Initial structures has one bedroll, chests empty. Players initially empty, at (480,288)/(520,288).
- structures[id]={id,kind,x,y,remaining,output}. Output is the planned item while remaining>0; only remaining==0 AND output nonempty is collectable. Purifier 12 s; grill 10 s.
- drift[id]={kind,x,y,active,respawn}, renewable. hook action validates distance <=280 and completes after 1 s, preserving full-bag object and preventing double rewards. Player hook={id,remaining,x,y}; asynchronous feedback notice/notice_id.
- hunger/thirst 0..100; decay 0.05/0.08 per second. below15 slows movement/recovery. Inventory adds leaf/plastic/scrap/rope/cup/saltwater/freshwater/cooked_fish/rod; same 12/16 slots and stack20.
- recipes.gd ALL is canonical: fields id/name/description/category/costs/result/amount/structure. craft takes recipe and optional x/y; placement is grid center, distance<=220 and existing vacant tile, or adjacent foundation. Costs committed only after validation. Own bag then shared chests; never partner bag.
- New verbs hook,craft,fill_cup,purify,grill_fish,collect_output,drink,discard. discard requires exactly {index,amount,expected_item} and only affects sender bag after positive integer amount/current slot identity validation. UI asks confirmation for the shown quantity. Legacy crop/cook/sell/build retained for migrated facilities. Fishing requires own rod, works any edge tile, 5 s and original 45/45/10 distribution. At_edge and can_place are public read-only helpers.
- New default save world_v3.json. Only when primary+backup absent, read v2 if available, else v1. Validated migration retains quantities/progress/facilities; future writes only v3. No tests against original player files.
- WorldView position=(10,8), scale=(1.4,1.4), logical900×560. state/local_slot plus hovered_id and placement{x,y,kind,valid}; no mutations. ArtCatalog reads CC0 atlases.
- GameHUD replaces right sidebar. C opens CraftingPanel, B InventoryPanel; solo pauses for either, coop does not. 1/2 hook/rod; mouse uses tool, E selected option, Tab cycles, F next. interaction_options may carry args, forwarded unchanged to authoritative action.

## Retained 0.2 history (superseded where specified above)



This file is the shared implementation boundary, not a claim that features work.

## World state

`scripts/world_state.gd` extends RefCounted. Root uses `preload(...).new()`.

Public API: `data: Dictionary`, `join(slot: String, display_name: String)`, `leave(slot: String)`, `set_move(slot: String, direction: Vector2)`, `tick(delta: float)`, `action(slot: String, verb: String, args: Dictionary = {}) -> String`, `interaction_options(slot: String) -> Array`, `snapshot() -> Dictionary`, `restore(saved: Dictionary) -> bool`, `nearby_chest(slot) -> String`, `chest_totals() -> Dictionary`.

Slots are `host` and `guest`. Data uses only JSON-safe dictionaries/arrays/numbers/strings/bools, no Vector2 or Objects.

Required data fields: `version=2`, `day`, `minute` (starts 360), `elapsed`, `money`, `chests`, `expansion` (0..2), `crop` (stage 0 empty / 1 growing / 2 ripe, progress 0..1, watered), `players`, `entities`. Each chest maps an ID to `{id,name,x,y,slots}`. There is no unbounded authoritative storage counter.

Player: `name`, `online`, `area` (`deck` or `water`), `x`, `y`, `oxygen` 0..100, `stamina` 0..100, `resting`, `sleep_ready`, `bag` (12-slot Array), `caught` count, `fishing` (empty or `{remaining,result}`). Slots are `{}` or `{item,count}`, items fish/wood/veg/meal/seed/treasure, count 1..20. Each chest has 16 slots.

Entity: `kind` (`fish` or `wood`), `x`, `y`, `active`; IDs are stable dictionary keys. Fish may additionally have base_x/base_y/phase. Draw inactive entities nowhere. Pickup/catch only via authoritative proximity action, never accept client IDs to grant items without checking range.

World drawable area is 900 x 560 pixels. Deck floor rect is (140,90,600,390), expanded to the right by 60px per expansion. Deck spawn (475,390). Deck stations: beds (230,170) and (305,170); storage (420,175); garden (565,175); kitchen (420,290); orders (565,290); expansion (710,385); dive hatch (670,410). Water return buoy at (120,65); water movement bounds (40,35) to (860,520). Interaction distance ~64px. View draws at offset (24,132).

Interaction options return dictionaries with `action` and Chinese `label` keys, nearby only. Core verbs: dive, surface, catch, collect, deposit, take_meal, plant, water, harvest, cook, sell, build, rest, sleep, wake, eat. E invokes first available option; UI provides explicit buttons for other choices. Sleep must only be requested near a bed. Rest restores stamina while world time continues. Sleeping readiness ends the day only when all online players explicitly request it. Joining/leaving clears readiness. Day advances reset fish/materials and may mature a watered crop. World clock caps at 23:50 until sleep in this prototype, with no forced fainting. Oxygen depletion affects only that diver, returns them to deck, loses fish from their current bag, preserves other players/shared storage. Offline guest bag is preserved for the next guest slot; this is a trusted-friends two-slot prototype, not accounts.

Inventory operations share `scripts/inventory.gd`; UI never grants items. `inventory_move` arguments: `from_container/from_index/to_container/to_index/amount/expected_item`, container is `bag` (sender's own) or chest ID; zero amount means whole stack. Validate chest distance, indices, item identity and available space before atomic transfer/swap. `sort_inventory` takes `container`; `open_treasure` takes own-bag `index`. `deposit` fills the nearest finite chest and leaves overflow in the bag. Facilities consume own bag then deck chests, with rewards placed into own bag only if the complete exchange fits.

`craft_chest` costs 4 wood near expansion station, placing up to four additional chests at (350,420), (430,420), (510,420), (590,420). `cast/reel` work within 64px of (185,385): 2 stamina, 5 seconds, authoritative roll 10% treasure / 45% fish / 45% wood. Full bags preserve the rolled catch until space is available; leaving cancels it. Treasure consumes one item and atomically awards 3 wood, 2 seed, 1 fish.

Restore accepts validated v1 counters and converts them into finite slots, retaining all accepted quantities; overflow shared materials use additional migration chests. Main reads v1 only if v2 and its backup are absent, and writes only the separate v2 path. JSON floats must be validated before conversion, including the outer save wrapper.

`tick` moves players from stored input. Inputs expire after 0.4s, so root resubmits at 20Hz. Direction is clamped. Day clock and growth tick while either player is elsewhere. Root alone handles solo pause/room pause. Loading keeps progress but resets online flags, movement and sleep/rest flags; new sessions put joining players safely on deck. Numeric JSON fields must be safe under float decoding.

## View

`scripts/world_view.gd` extends Node2D. Public fields `state: Dictionary = {}`, `local_slot: String = "host"`. Root sets these every frame and calls queue_redraw. Draw only the local player's area, other players only when in same area. View origin is (0,0), parent sets position=(24,132). World view must not mutate state or process input. Font uses ThemeDB.fallback_font or SystemFont for Chinese. Optional helper `screen_label` is internal.

Aim: restrained original pixel-art ocean, warm wooden deck, visible beds/crates/planter/stove/order board/ladder, distinct two characters, side-view reef/corals/fish and a return buoy, no shake/rotation/automatic zoom. Root provides HUD, menus and interactions outside the world region.

## Root and network

`main.gd` owns state, controls, Godot ENet and UI. Canonical RPC node path /root/Main for all peers. Server maps sender peer ID to fixed slot guest; it never trusts supplied player slot. Reliable action RPCs; periodically replicated authoritative JSON-safe snapshots; movement input expires. Host can play while hosting. Single-player uses the same state class. Save files are versioned JSON, atomic replacement + backup, and are separate from demo/test saves. No default save overwritten by automation. Headless mode uses the same main scene for network integration validation.
