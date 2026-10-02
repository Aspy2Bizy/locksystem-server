# CLAUDE.md

Guidance for Claude Code working in this repo.

## Project

The Long Con: a tactical heist FPS in Godot 4.7, written in GDScript. One developer plus Claude Code. The design source of truth is `docs/BLUEPRINT.md`. Architecture is in `docs/ARCHITECTURE.md`, and open design questions are in `docs/DECISIONS.md`.

## Rules

- **Data first.** Gameplay numbers live in `data/*.json`, never hard-coded in scripts. When you add an id that cross-references another file, add a check to `tests/test_data.gd`.
- **Pure logic is separate from nodes.** Rules go in `scripts/systems/` or `scripts/gen/` as `RefCounted` classes with static functions or plain state, and they take a `GameData`. That keeps them unit-testable headless and usable on a dedicated server.
- **Determinism.** The bank generator must be identical for the same seed on every machine. Use the generator's `rng` (never `randi()` or `Array.shuffle()`) inside generation code. `test_deterministic` and `tools/net_smoke.sh` guard this.
- **Server-authoritative.** Clients send requests; the host decides. Only seed and stars are sent for the bank.
- **Type hints.** GDScript cannot infer types from Dictionary or Variant values, so write `var x: float = d.value`, not `var x := d.value`. `tools/check_all.sh` catches this.

## Commands (godot must be on PATH)

```bash
godot --headless --import                      # after adding scripts with class_name
tools/check_all.sh                             # parse-check all scripts
godot --headless -s res://tests/run_tests.gd   # unit tests; script errors count as failures
tools/net_smoke.sh                             # 2-process network test
godot --headless -s res://tools/dump_bank.gd -- <seed> <stars>
# Screenshot any scene without a screen (needs xvfb):
xvfb-run -a godot --rendering-driver opengl3 -- --scene=res://scenes/bank_sandbox.tscn --frames=120 --shot=/tmp/s.png --seed=1 --stars=3 [--map] [--pose=x,y,z,yaw,pitch]
```

A SceneTree script that fails to compile hangs instead of exiting, so always wrap headless runs in `timeout`.
