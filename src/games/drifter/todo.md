# Drifter Todo

This file is the active task loop for the next `drifter` slice. [goals.md](goals.md)
defines the testbed purpose. [design.md](design.md) defines the station-scale
simulation. [roadmap.md](roadmap.md) defines the broader implementation order.

## 1. Current Slice

Build the first visual shell and debug controls without adding permanent
simulation substitutes for engine-world surfaces that already exist.

The current scaffold compiles and exposes engine hooks, but it only renders a
placeholder overlay. This slice should create a visible station-scale shell
that future world-fact slices can attach to.

## 2. Scope

In scope:

* keep the station visually centered as a grey world-space circle;
* add a small deterministic set of darker grey asteroid circles drifting in the
  background;
* keep zoom in/out and camera reset controls;
* remove or disable temporary WASD/arrow panning so the first shell matches the
  no-panning design;
* replace the placeholder `DRIFTER` overlay with compact debug text for pause
  state, zoom, asteroid count, and available controls;
* keep overlay toggling;
* keep all state game-owned under `src/games/drifter`;
* leave comments where shell state is intentionally temporary.

Out of scope:

* station resource stockpiles;
* persistent station, system, drone, asteroid, or chunk entities;
* component/relation/trait/event/command/rule registration;
* archetype declarations;
* scheduler cadence or timed jobs;
* retained UI widgets;
* market, construction, upkeep, population, damage, repair, save/load, replay,
  particles, or effects.

## 3. Tasks

1. Inventory the current scaffold.
   * Confirm `stateInjects.zig` remains lifecycle-only.
   * Confirm shell state belongs in `stepInjects.zig` or a small local file if
     the render/input code becomes hard to scan.

2. Add shell state.
   * Define station world position, station radius, asteroid positions, sizes,
     and drift speeds.
   * Keep the asteroid list fixed-size for this slice.
   * Reset shell state from a clear helper used by startup or reset input.

3. Update input behavior.
   * Preserve pause toggle.
   * Preserve mouse-wheel zoom and camera reset.
   * Preserve overlay toggle.
   * Remove or disable WASD/arrow panning for this slice.

4. Draw the shell.
   * Draw the station in `OnRenderWorld`.
   * Draw asteroid circles in `OnRenderWorld`.
   * Keep colors simple and readable against the current background.
   * Avoid relying on world simulation facts that do not exist yet.

5. Replace the placeholder overlay.
   * Show pause state.
   * Show zoom or camera scale if available through the current camera API.
   * Show asteroid count.
   * Show concise controls.
   * Ensure the paused-screen cover does not hide the useful debug text.

6. Validate.
   * Run `zig build drifter`.
   * Manually run `drifter` if a graphics session is available.
   * Confirm zoom works, reset recenters the shell, overlay toggle works, and
     no panning controls move the camera.

## 4. Next Slice Candidate

After this shell is stable, the next roadmap slice should start the first
world-owned station facts: register the game-owned station components, create
the persistent station entity, add starter reserve state, and expose those
facts through the overlay.
