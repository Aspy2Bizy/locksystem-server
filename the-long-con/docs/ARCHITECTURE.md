# Architecture

## Layers

```
data/*.json  ->  GameData (scripts/core)  ->  pure logic (scripts/gen, scripts/systems)
                                                 |
                       nodes and scenes (scripts/world, player, ui)  <-  Net (server-authoritative)
```

1. **Data** (`data/`): every tunable number and id. The blueprint's data tables map onto these files:

   | Blueprint table | File |
   | --- | --- |
   | roles | `roles.json` |
   | weapons and gadgets | `weapons_gadgets.json` (also armor, crafting parts and recipes) |
   | difficulty tiers | `difficulty_tiers.json` |
   | room prefabs | `room_prefabs.json` |
   | vault modules | `vault_modules.json` |
   | civilians | `civilians.json` |
   | escape routes | `escape_routes.json` (also breakouts and leverage) |
   | penalties | `penalties.json` |
   | seed config | `seed_config.json` |
   | (new) modes and rule sets | `modes.json` |

2. **GameData** loads all JSON once and indexes it by id. The `DataDB` autoload holds the shared instance. Tests and tools create their own with `GameData.load_default()`.

3. **Pure logic**: `RefCounted` classes with no scene dependencies.
   - `BankGenerator` builds the shell, spine corridors, aligned stairs and elevator, then required, optional and filler rooms, doors and vertical links, then `BankContents` (vault, security, civilians, routes). It ends with `BankValidator`, and a failed check re-rolls `mix_seed(seed, attempt)`.
   - `VaultSolver` treats a solution as feasible when its required rooms exist and its crafting parts spawn in existing rooms.
   - `Scouting.reveal` returns the partial intel shown at a given star tier.
   - Systems: `DamageModel` (+ `Health`), `Economy`, `Detectability`, `CivilianBrain`, `Crafting`, `Breakout`, `HeistFlow`.

4. **Nodes**: `BankBuilder` turns a bank Dictionary into greybox geometry. `PlayerController` is the FPS body, and `FloorMap` draws plans for the planning table and the HUD map.

5. **Net**: ENet lobby. The host owns `Session` (seed, stars, mode). Clients regenerate the bank locally from the seed.

## Bank data shape (summary)

```
bank = {
  seed, stars, attempt, w, h, cell_size_m, floor_height_m,
  floors: [{level, type, cells: PackedInt32Array(w*h -> room idx), rooms: [idx]}],
  rooms:  [{idx, id, name, kind, floor, cells: [Vector2i], rect, tags, doors: [door idx], ...}],
  doors:  [{idx, a, b (-1 = outside), floor, cell, side, lock}],
  vertical_links: [[lower room, upper room]],   # stairs and elevator
  entries: [{room, kind}],
  vault: {room, layout, lock, lock_family, hazard, staff_dependency, lock_solutions, hazard_solutions},
  security: {cameras: [{room, floor, cell, yaw_deg}], guards},
  civilians: [{id, type, room, floor, cell, armed}],
  escape_routes: [route ids],
}
```

On each floor, rooms[0] is the corridor, rooms[1] the stairwell and rooms[2] the elevator.

## Planned: multiplayer model

- **Host-authoritative** with the host as a listen server first; a dedicated headless server later (the pure-logic layer already runs headless).
- **Bank**: send the seed only.
- **Players**: clients send input; the server simulates and replicates state with `MultiplayerSynchronizer` at about 20 Hz; client-side prediction for the local player.
- **AI** (civilians, police) runs only on the server, with replicated position and animation state, and LOD per `civilians.json` `cap`.
- **Hits**: server-side raycasts with lag compensation (keep about 200 ms of position history).
- **Transport**: ENet for development; Steam networking through GodotSteam for release (see DECISIONS.md).
