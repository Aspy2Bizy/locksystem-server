# The Long Con - Game Blueprint

Oct 2, 2026 · @Alexander N

## Pitch and pillars

The Long Con is a realistic 3D tactical FPS heist game: Payday's heists, Rainbow Six's gadget roles and La Casa de Papel's long, planned operations. It is built in Godot 4 by one developer working with Claude Code, in a fictional city.

- **Planning is the game.** Scout, plan, then infiltrate, long before anyone has to shoot.
- **Every run is unique.** A seed varies the bank layout, vault, locks, cameras, staff and civilians.
- **Civilians are leverage, not scenery.** Killing one costs both teams, so nobody can simply rush in or shoot freely.
- **Realism over arcade.** An unprotected headshot kills, wounds matter, and noise draws a reaction.
- **Teamwork runs on voice chat.** There is no scripted negotiator role: players talk, and the systems enforce the rules.

## Modes and rule sets

There are two game modes, PvE co-op and PvPvE, and each can run under Arcade or Realistic rules.

| Mode | Players | How it starts |
| --- | --- | --- |
| PvE co-op | 2 to 6 robbers against AI police and civilians | Scout, plan, infiltrate, then the team chooses when to go loud |
| PvPvE | 4v4 up to 8v8, chosen in the lobby; robbers against police, with AI civilians | Starts loud: robbers take the bank, police join at takeover |

Session length is tiered: friends lobbies run 60 to 90 minutes, public matches 30 to 45.

|  | Arcade | Realistic |
| --- | --- | --- |
| Death | Respawn allowed for a small money loss | Final once the downed window runs out; dead players keep working on cams, comms and support |
| Robber killed | Counts the same as arrested | Final; revival is possible only while downed |
| Arrest | A physical arrest pays a big bonus | The robber is held until a teammate breaks them out |
| Police respawn | Timed | Timed |

## PvE heist flow

A PvE heist has seven phases, and the first three are quiet. Full stealth is not an option, because every plan ends in a loud takeover, but the team chooses when.

1. **Scout.** Learn this seed's bank: civilian layout, cameras, lock types, staff routines. Scouting gives partial information, and how much depends on difficulty.
2. **Plan.** Choose roles, gadgets, weapons and entry routes. Every item adds to your detectability.
3. **Infiltrate.** Get as deep as possible in cover. Players are exposed one at a time: some can reach key positions hidden while another starts shooting in the lobby.
4. **Takeover.** The team goes loud, secures hostages and locks the bank down.
5. **Siege.** Hostage trades, vault work and holding off police assaults.
6. **Extraction.** Move the money out through a chosen route that police can intercept.
7. **Payout.** Money is deducted in proportion to the severity of mistakes.

**Detectability.** Loadout sets how visible each player is, from a concealed pistol to a bulky drill bag. Cover is blown per player, not per team. Proposed: a loud player raises the building alert for everyone, while hidden teammates stay hidden.

## PvPvE flow

PvPvE skips the quiet phases: the robbers take the bank loud, and police players join at takeover. Scouting, planning and infiltration are PvE-only.

- **Pre-round (proposed):** a short loadout and entry-point pick, so the round still feels planned.
- **Robbers:** start inside the bank with the seeded layout, hostages and vault.
- **Police:** deploy from a staging area outside, with timed respawns.
- **AI:** civilians fill the building, and AI patrol and reinforcement units fill any gaps in the police team.
- **Information:** police see the floor plans but not the vault's lock type or hazard (proposed), so robbers keep an edge.
- **Difficulty:** the lobby picks 1 to 5 stars. The 6-star Max tier is PvE only.
- **Police budget (proposed):** civilian casualties and failed assaults drain police reinforcements, so reckless play costs them too.

## Roles

Each role has its own gadget or ability, Rainbow Six style. There is no dedicated negotiator on either side: any player can talk to the other team over voice, and trades go through a structured trade UI.

| Robber role | Job |
| --- | --- |
| Professor | Plays from outside the bank with the cameras and tech. Sabotages power, traffic lights and comms, decodes police radio and arranges breakouts. Must stay undercover; if police find him, he is arrested. |
| Breacher | Charges, drills and door entry. |
| Enforcer | Heavy weapons, suppression and hostage control. |
| Tech | Jammers, hacking and remote traps. |
| Medic and forger | Revives teammates and fakes IDs and uniforms. |

| Police role | Job |
| --- | --- |
| Commander | Runs the drone and camera feeds and directs units. Has no authorization gate over breaches. |
| Assault | Breaching and entry. |
| Sniper and overwatch | Long-range pressure from outside. |
| Tech and drone operator | Scouting, jamming and counter-hacking the robbers' Tech. |
| Medic and hostage rescue | Treats the wounded and extracts hostages. |

Gadget lists per role are still to be defined before the JSON conversion.

## Hostages, civilians and penalties

Whoever kills a civilian pays the full penalty, and everyone else pays a small one. Police can breach whenever they like, so this penalty alone has to stop both reckless rushing and hostage executions.

- **Penalty split:** the shooter pays in full; the shooter's own team and the enemy team each pay a small share.
- **Repeat offences (proposed):** the penalty grows with each civilian killed by the same player in a round, so teammates have a reason to restrain each other.
- **Hazards (proposed):** a hazard death is charged to whoever triggered the hazard.
- **Hostage value:** robbers lose money when hostages die, and police gain from hostages saved. Hostages can be traded for demands picked from a list, such as a vehicle, a cleared route or jammers switched off.
- **Civilians:** each has simulated fear, compliance, panic and heroics. The seeded mix can include armed civilians and an off-duty cop (proposed).

**Why surrender is worth it in PvPvE (proposed):**

- An arrested robber keeps a guaranteed cut of their personal take, like a plea deal; a killed robber gets nothing.
- A downed robber can surrender or bleed out.
- Police who kill a surrendering robber take an excessive-force penalty.
- Tasers and less-lethals let police disarm and arrest robbers who refuse to give up.

**Griefing (proposed):** deliberate hostage killing and team-killing carry an extra personal penalty, with a report or vote option in public matches.

## Difficulty tiers

Difficulty is a six-star rating picked when you start the search, and payout rises with each star. The names below are placeholders in a Wolfenstein-style joking tone.

| Stars | Name (placeholder) | Notes |
| --- | --- | --- |
| 1 | Wake Me When It's Over | Mildest hazards, most scouting info, lowest pay |
| 2 | Don't Hurt Me, Officer |  |
| 3 | Bring On the Cops |  |
| 4 | I Am the Professor |  |
| 5 | Death Wish | Highest tier available in PvPvE |
| 6 | Dead Is Dead | Max difficulty, PvE only, highest pay |

What the stars change:

- **Hazard danger:** vault lockdown hazards get deadlier with each star.
- **Scouting:** higher tiers reveal less about the seed.
- **Margin for error:** minor slip-ups matter more, and at 6 stars one can fail the mission.
- **Budget (proposed):** hard hazards are paired with softer security elsewhere, so a seed never feels unfair by bad luck.

**At 6 stars:** no breakouts, so dead is dead, but a knocked-down player can still be revived. Hazards can kill outright. Scouting reveals very little.

**No checkpoints at any tier.** At 5 stars and below, breakouts are the way back for a lost teammate.

## Bank generation

Each seed builds a large, multi-story bank from pre-made rooms and hallways, placed only where they make sense and filled so that no cell of the grid is left empty.

1. **Shell:** the seed picks the floor count and footprint, and each floor is a grid, for example 8x8. Suggested floors: parking and basement, lobby, mezzanine, offices, staff floors, vault level and roof.
2. **Anchors:** lobby, vault, and stairwells and elevators aligned vertically.
3. **Routes:** main halls and corridors.
4. **Required rooms:** placed by tag rules. A vault only fits the vault level, a bathroom never sits beside a vault, and a server room needs a power and cooling route.
5. **Filler rooms:** storage, small offices and utility closets fill every remaining cell.
6. **Validation:** every cell is filled, every room is reachable, there are at least two entry routes, and the vault has at least two valid solutions. A failed check re-rolls the seed.

Each room prefab declares an id, allowed floors, size in cells, door sockets, adjacency rules and tags. The seed also varies cameras, lock types, staff schedules, civilian mix and the vault.

## Vaults and lockdowns

Each vault is assembled from four interchangeable modules, and every vault has its own lockdown mode that fires automatically when the break-in alarm is triggered.

| Module | Options |
| --- | --- |
| Layout | Single deep vault, nested vaults, a maze of safe-deposit corridors, or a split vault with cash and valuables apart |
| Lock | Mechanical (combination tumblers, timed bolts, two keys), electronic (keypad and network hacking), or hybrid |
| Lockdown hazard | Flooding, oxygen-depleting gas, laser grid, collapsing floor, pressure-plate sequence, or a sealed airlock |
| Staff dependency | Manager biometrics, or a second person at another door, which makes hostages useful beyond trading |

**Lockdown rules**

- Lockdowns cannot normally be avoided, but they can be switched off or bypassed once triggered.
- Hazards hurt everyone, including police, and their danger scales with the difficulty stars.
- A warning window (alarm, lights, countdown) comes before any lethal effect (proposed), so deaths feel earned.

**Every hazard has several solutions, each with a cost.** A flooded vault can be handled with a crafted scuba valve or rebreather, by draining it from the pump room, or by hacking the flood controller. A hacked lock is traceable and police Tech can counter-hack it. A mechanical lock is slower and quieter and needs parts. Thermite or a drill is fast but loud and raises the building alert.

**Fairness:** the generator confirms at least two valid solutions before a round starts. Scouting reveals the vault's type but only part of its details, such as the hazard without the location of the drain.

## Combat, crafting and traps

Combat is realistic: an unprotected headshot is an instant kill.

- **Ballistics:** armor tiers, penetration and ricochets.
- **Wounds:** bleeding, a downed state, revives and medical treatment.
- **Perception:** police and civilians react to gunfire and noise, and AI uses sight and sound.
- **Crafting and MacGyvering:** combine items on site during the heist. Examples: thermite from parts, improvised smoke, door wedges, wire-trip alarms, a jammer built from electronics.
- **Traps and sabotage:** tripwires, claymore-style charges, locked doors, and cut power or camera feeds.
- **Hostages as a factor:** every shootout has to account for civilians in the line of fire.

## Escape routes and breakouts

Robbers have several ways out, and police can scout, block or ambush every one of them. A lost teammate can be recovered in Realistic mode, but only at a cost.

**Escape routes:** sewer tunnels, a rooftop helicopter, getaway cars, a hijacked police van, a subway or underground route, and a boat on the river.

**Breakouts (Realistic mode, 5 stars and below):**

- A breakout costs in-round currency that exists only during that round and is never saved.
- It is chance-dependent and AI-driven. AI motorcyclists or other units stop a convoy, or blow up a prison wall.
- The freed player is handed a weapon and has to reach a safe extraction point while hundreds of AI police respond, and teammates defend the extraction.
- The Professor can plan and arrange breakouts.
- **Proposed:** the in-round currency, called leverage, is earned from hostages held, sabotage and intel, and the whole set piece lasts 3 to 5 minutes.

**Police respawn** on a timer, with the delay growing as the fight goes on (proposed). At 6 stars there are no breakouts.

## Progression and economy

There are two currencies: cash buys gear, and reputation unlocks roles and contracts.

- **Cash** buys weapons, gadgets and role upgrades.
- **Reputation** unlocks roles and contracts.
- **End-of-round deductions:** you lose part of the money you extracted, in proportion to the severity of your mistakes, such as civilian deaths, damage and failures.
- **Payout:** it rises with the chosen difficulty, and in PvE with the chosen budget. A harder budget pays more, an easier one pays less.
- **Arcade:** a respawn costs a small amount of money.
- **Upgrades (proposed):** horizontal, giving options rather than raw power, so veterans do not dominate random lobbies.
- **Monetization (proposed):** cosmetics and role-skill unlocks only, with nothing sold that adds power.

## World

The world is a small, GTA 5-style city grid in a fictional setting, with one very large multi-story bank in the middle.

- **Surroundings:** streets, rooftops and an alley network around the bank.
- **Escape infrastructure:** a sewer or subway connection and a river or harbor edge, which feed the escape routes.
- **Police staging area** outside the bank.
- **Enterable buildings (proposed):** only those that affect the heist, to keep scope realistic for one developer.
- **Fictional city** means police tactics, gear and law can be designed freely.

## Art, audio and UI

The look is grounded and gritty, and realism comes mainly from systems and lighting rather than hand-sculpted assets.

- **Art:** cold bank lighting and realistic materials. Stylized or low-poly assets are acceptable early on, since one developer cannot hand-model a whole city.
- **Audio:** tense ambience and radio chatter, with minimal music that builds during the siege.
- **HUD:** minimal, showing ammo, health and the role gadget.
- **Planning:** a planning table and map for the scout and plan phases.
- **Communication:** team voice chat, an in-game radio, and a structured trade UI for hostage demands.
- **Role interfaces:** the Professor's camera wall and the Commander's drone map.

## Tech spec

The game is built in Godot 4, whose scenes, resources and scripts are plain text that Claude Code can write directly. Everything gameplay-related is defined as data, which is what will be converted to JSON next.

- **Networking:** server-authoritative, with 2 to 6 players in co-op and 4v4 up to 8v8 in PvPvE. AI runs on the server.
- **Voice chat:** needed for team play. Godot has no built-in solution, so a plugin or service is still to be chosen.
- **Performance:** a civilian cap, AI level of detail, per-floor streaming and occlusion culling.
- **Core systems:** player controller, ballistics and damage, police and civilian AI, hostage system, objectives and money, role gadgets, crafting, and a stat tracker.

| Data file (planned) | What it defines |
| --- | --- |
| roles | Robber and police roles, abilities and gadgets |
| weapons and gadgets | Stats, detectability cost, crafting recipes |
| difficulty tiers | The six stars, hazard danger, scouting info, payout scale |
| room prefabs | Id, allowed floors, size, door sockets, adjacency rules, tags |
| vault modules | Layouts, locks, lockdown hazards, staff dependencies, solutions |
| civilians | Behaviour types and the seeded mix |
| escape routes | Route data and interception options |
| penalties | Civilian-death penalty split and surrender payouts |
| seed config | Variables a seed may roll and the validation rules |

## Milestones, scope and risks

This is a studio-scale game for one developer, so the plan is a vertical slice first, then multiplayer, then everything else.

&#91;embedded content: milestone roadmap · 4 phases, 3 gates (gate criteria proposed)\]

Each gate is a proposed check that a milestone works before the next one starts.

**Main risks**

- **Scope:** the full design is far larger than one person can finish, so every milestone must be playable on its own.
- **Performance:** 8v8 with dozens of AI civilians in Godot needs the civilian cap and AI level of detail.
- **Professor balance (proposed):** limited camera coverage, feed delay, hackable feeds and a police Tech counter keep the camera wall from dominating.
- **Dead-player downtime:** Realistic mode needs real support jobs for dead players.
- **Procedural bank:** the validator must catch unsolvable or broken seeds before a round starts.
- **Griefing with randoms:** personal penalties and a report option.
