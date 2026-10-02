# Decisions and open questions

## Decided during setup (change any of these if you disagree)

| Decision | Why |
| --- | --- |
| Godot **4.7** stable, GDScript (no C#) | Latest stable; plain-text scripts Claude Code can write; no .NET export issues |
| Data in JSON, loaded at runtime | The blueprint plans a JSON conversion; easy to diff and tune |
| Grid cells are 6 m and floors are 4 m | Fits the 3x3 lobby and the 3x2 vault at a plausible scale |
| One corridor spine row and column per floor, shared by all floors | Guarantees the stairs and elevator line up and every floor is connected |
| Vault has exactly one door, into the antechamber, and never touches the outer wall | Realistic, and gives the siege a choke point |
| Hard vault means softer security: the tier's `security_budget` is spent on the vault first, and the rest buys cameras and guards | Implements the blueprint's "Budget (proposed)" item |
| A loud player raises the building alert, but hidden teammates stay hidden | Blueprint proposal, implemented in `HeistFlow` |
| Placeholder tuning numbers everywhere | Starting points only; tune them in `data/` after playtests |
| Gadget lists per role are filled in (`roles.json`) | The blueprint said they were still to be defined; review them |

## Open: needs your call

1. **Voice chat.** Options:
   - **Steam Voice via GodotSteam**: free, with good quality and echo handling, and it pairs with Steam lobbies and networking. It needs a Steam app ID; the dev app ID 480 works for testing. **Recommended** if you ship on Steam.
   - **TwoVoip** (Opus GDExtension, open source, requires Godot 4.6+), sending audio over your own game connection. No platform lock-in, but you handle noise and echo yourself.
   - **Godot-Opus** or **godot4-opus**: lower-level Opus encoder and decoder nodes.
   - A paid third-party service: least work, but monthly cost and a dependency.
2. **Release platform.** Steam (GodotSteam for lobbies, NAT traversal and voice) or self-hosted servers? This affects M2.
3. **Combat feel.** Hitscan for everything (simpler, standard for this genre at these ranges) or projectile ballistics for rifles and snipers only?
4. **Arrest flow in Realistic mode.** Is an arrested robber a spectator who can use cams and comms until broken out, or are they playable in a holding cell?
5. **Session length.** Public matches are 30 to 45 minutes. Is there a hard timer, or do police waves escalate until a resolution?
6. **Professor in PvE.** AI police need a "find the Professor" behaviour (signal tracer). Should that be on by default?
7. **Difficulty names.** They are still placeholders.
