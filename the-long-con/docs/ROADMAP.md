# Roadmap

Vertical slice first, then multiplayer, then everything else. Each milestone must be playable on its own. Gates are proposed checks before moving on.

## M0: Foundation (done)

- [x] Data files for every blueprint table
- [x] Seeded bank generator with validation and vault solver
- [x] Rule systems with unit tests
- [x] Planning table, greybox walkable bank
- [x] Lobby networking foundation
- [x] CI
- [x] Realistic rigged character models with outfits, skin shader and IK poses (docs/CHARACTERS.md)

## M1: Single-player vertical slice (PvE, one robber, AI police)

- [ ] Real stairs (replace interact panels), elevators that move
- [ ] Weapons in 3D: hitscan through `DamageModel`, recoil, reload, ammo
- [ ] Character animation: retarget Mixamo walk, run, idle and cower clips to the MakeHuman rig
- [ ] Civilians as `NavigationAgent3D` actors driven by `CivilianBrain` (flee to exits, comply, freeze, hero)
- [ ] Guards and cameras with sight cones feeding `Detectability.suspicion_rate`
- [ ] `HeistFlow` phases: infiltrate, go loud, takeover, vault, extraction; HUD phase banner
- [ ] Vault lock and lockdown hazard as interactive objects using the solver's solutions
- [ ] Crafting UI; parts spawned in rooms per `parts.found_in`
- [ ] One escape route (getaway cars) and the payout screen via `Economy.payout`
- [ ] Basic AI police assault waves

**Gate:** one full solo heist from entry to payout on 3 random seeds without a soft-lock.

## M2: Co-op (2 to 6 players, PvE)

- [ ] Player state sync, client prediction, server hit validation
- [ ] Roles and gadgets (one gadget per role first)
- [ ] Hostage control (zip ties, trades UI)
- [ ] Downed, revive, arrest, breakout (Realistic rules)
- [ ] Voice chat (see DECISIONS.md)
- [ ] Scout and Plan phases with the planning table in-match

**Gate:** 4 players finish a heist over the internet with stable performance.

## M3: PvPvE

- [ ] Police player roles, staging area, timed respawns
- [ ] AI fill for missing police
- [ ] Police budget tickets, excessive-force and surrender rules
- [ ] Commander drone map, Professor camera wall

**Gate:** 4v4 match plays to a result; 8v8 holds 60 fps on a mid-range PC.

## M4: Content and polish

- [ ] Art pass (modular room kits, lighting), audio, all hazards and escape routes
- [ ] City blocks around the bank, sewer, subway, river
- [ ] Progression (cash and reputation), cosmetics
- [ ] Six difficulty tiers balanced from playtests
