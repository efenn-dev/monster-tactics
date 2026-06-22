# Monster Tactics

A turn-based, hex-grid conquest game: lead a team of monsters that move and fight
across a Civilization V–style hex map, capture territory, evolve your units, and
conquer the board (Risk-style win condition). Single-player vs AI.

Built in **Godot 4.x / GDScript 2.0**. This is a first game, built in small, tested
slices. Long-term goal: graduate to an Unreal FPS/RPG — this project exists to learn
the build-iterate loop and the RPG systems layer (stats, progression, evolution).

## Design (v1 scope)

- **One merged board (Civ-style):** combat resolves on the map; no separate battle screen.
- **Hex grid** with axial coordinates — see `src/core/hex.gd`.
- **Conquer to win (Risk-style):** eliminate the enemy / hold the map.
- Deliberately **not** Civ: no tech tree, cities, economy, or diplomacy. Board + conquest only.

## Architecture

- `src/core/`  — headless rules engine (pure logic, no nodes). Unit-tested.
- `src/board/` — presentation (draws hexes, handles input).
- `test/`      — zero-dependency headless test runner.

The core/presentation split keeps the game logic testable by an AI coding agent and
mirrors the combat-logic separation we'll reuse in the Unreal RPG later.

## Run the game

1. Install **Godot 4.3+** (Standard / GDScript build): https://godotengine.org/download
2. Open the editor → **Import** → select `project.godot` in this folder → press **F5**.

## Run the tests (headless)

```
godot --headless --script test/run_tests.gd
```

Exit code is non-zero if any test fails. Tip: add the Godot executable to your PATH
(or alias it) so it can be run from the terminal as part of the edit/test loop.

## Milestones

- [x] **M1** — hex grid renders; hover + click to select a hex
- [x] **M2** — place units; show + execute movement range
- [ ] **M3** — turn system (player ↔ AI phases)
- [ ] **M4** — combat: attack adjacent, damage, death, win/lose
- [ ] **M5** — basic AI (approach + attack) ← first fully winnable build
- [ ] **M6** — data-driven monsters (Godot `Resource`s), 3–5 types
- [ ] **M7** — evolution
- [ ] later — territory ownership/coloring, type chart, bigger maps

## 3D visuals (parallel track)

- [x] **V1** — low-poly 3D hex terrain, tilted Civ-style camera, lighting, placeholder units
- [x] **V2** — mouse picking via raycast (port selection + movement into 3D)
- [x] **V3** — fog of war (visibility computed in core + 3-state dim/dark overlay)
- [ ] later — CC0 unit/terrain models, terrain features (trees, mountains), water polish

### Dev loop: screenshot review

`<console-exe> --path . --quit-after 600 -- --screenshot` renders one frame to
`user://shot.png` and quits, so the look can be reviewed without a manual screenshot.
