# Back at the computer: checklist

Everything that could be done without a PC is done. These are the steps that need you.

## 1. Get it running (about 15 minutes)

- [ ] Install **Godot 4.7** (standard build, not .NET) from https://godotengine.org/download
- [ ] Clone the repo and switch to the game branch: `git clone https://github.com/aspy2bizy/locksystem-server.git`, then `cd locksystem-server` and `git checkout the-long-con`
- [ ] Open Godot, click **Import**, select `the-long-con/project.godot`, then **Import & Edit**. The first import takes a minute.
- [ ] Press **F5**. You should see the main menu.
- [ ] Try **Planning Table**: flip floors and toggle "View". Then **Walk the Bank**: walk in, open doors (E), take the stairs (green panel), press M for the map and F5 for a new bank.

If something errors, open the **Output** and **Debugger** panels at the bottom of the editor, and paste the red lines to Claude Code.

## 2. Things only you can judge

- [ ] **Feel of movement.** Speeds, jump and mouse sensitivity are in `scripts/player/player_controller.gd` (`@export` values you can tweak in the Inspector).
- [ ] **Scale.** Do 6 m rooms and 4 m floors feel right? Change `cell_size_m` and `floor_height_m` in `data/seed_config.json`.
- [ ] **Generated layouts.** Walk 5 to 10 seeds. Note anything odd (a room in a silly place, a dead-end you hate), with the seed number, and give it to Claude Code.
- [ ] **Review the decisions** in `docs/DECISIONS.md` and answer the open questions, especially voice chat and the release platform.
- [ ] **Review the gadget lists** in `data/roles.json`.

## 3. Optional setup

- [ ] Optional: move the game into its own GitHub repo (copy the `the-long-con/` folder into a new repo, and move `.github/workflows/the-long-con-ci.yml` with it).
- [ ] Install Claude Code on the PC and run it in the `the-long-con/` folder; `CLAUDE.md` tells it how the project works.
- [ ] If you choose Steam: create a Steamworks account and install the GodotSteam GDExtension from the Asset Library (use app ID 480 for testing).
- [ ] Install `xvfb` (Linux) if you want Claude Code to take screenshots automatically.

## 4. Next milestone

Start **M1** in `docs/ROADMAP.md`. Suggested first task for Claude Code:
"Replace the stair panels with real stair geometry, then add a pistol that shoots using DamageModel."
