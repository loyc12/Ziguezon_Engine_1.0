# Legacy Tilemap Migration Todo

This file is the active task loop for the legacy tilemap migration.
[goals.md](goals.md) defines the target state and hard boundaries.
[roadmap.md](roadmap.md) defines the implementation order.

## 1. Current Scope

Complete the compatibility migration from engine-owned tilemaps to a utility
legacy module owned directly by games.

This todo may cover the full roadmap because the migration is intentionally
narrow: quarantine the existing tilemap behavior, detach it from `engine`, move
active games to direct ownership, and remove the old engine manager surface.

## 2. Guardrails

* Keep `legacy_tilemap` free of `engine` imports.
* Do not add engine-side compatibility aliases or exports.
* Do not preserve the id-based tilemap manager model.
* Keep ticking, deletion, and rendering game-driven.
* Keep game sidecar data such as `TILEMAP_DATA` as the simulation data source.
* Preserve current tilemap behavior where practical.
* Remove `.RANDOM` tile behavior and engine-global random fill.
* Keep `Tile.colour` and cached relative positions for compatibility.
* Comment cache invalidation risks where they matter, but do not redesign the
  cache in this migration.
* Do not introduce a new `World` grid model, ECS tile entities, chunking,
  batching, serialization, or a broader tile data redesign.
* Do not run formatting passes such as `zig fmt`.

## 3. Implementation Tasks

1. Establish the utility module.
   * Move `tile.zig`, `tilemap.zig`, `tilemapShape.zig`, and
     `tilemapFlood.zig` from the engine world tilemap area into
     `src/utils/legacy_tilemap`.
   * Add the local module entrypoint needed by `src/utils/utilsDef.zig`.
   * Export the module from a clearly marked legacy section in `utilsDef.zig`.
   * Leave `engineDef.zig` without tilemap aliases.

2. Detach tilemap code from engine ownership.
   * Replace engine tilemap imports with local legacy tilemap imports.
   * Remove `eng.G_ENG.rng` usage and delete `.RANDOM` tile behavior.
   * Make render functions receive required engine-owned state from callers.
   * Keep picking, shape, neighbour, coordinate, and flood-fill helpers
     engine-agnostic.
   * If render culling needs camera data, pass the camera or view box
     explicitly instead of reaching through engine globals.

3. Remove the engine tilemap manager surface.
   * Remove `tilemapManager` from `Engine`.
   * Remove tilemap manager init/deinit from engine state transitions.
   * Remove tilemap tick and deletion calls from engine stepping.
   * Remove tilemap render and debug draw calls from engine rendering.
   * Remove tilemap exports from `src/engine/engineDef.zig`.
   * Remove `DebugDraw_Tilemap` from engine configs and game adapters.
   * Move only genuinely reused helper behavior into the legacy utility; do not
     keep the old id ownership model.

4. Migrate active tilemap games to direct ownership.
   * For `dehexer`, `granulater`, `isofloor`, `labyrinther`, and `politator`,
     add a module-global `legacy_tilemap.Tilemap`.
   * Initialize each tilemap from the current game lifecycle hook that creates
     or requests the manager tilemap.
   * Deinitialize each tilemap from the matching shutdown hook.
   * Replace manager id lookups with direct access to the game-owned tilemap.
   * Preserve each game's tile sidecar arrays and tile-specific simulation data.
   * Render tilemaps manually from each game's render hook, before other world
     rendering when practical.
   * Pass camera and render dependencies explicitly to tilemap render calls.

5. Strip stale tilemap usage from non-target games.
   * Remove tilemap logic from `src/games/debug`.
   * Remove tilemap logic from `src/games/_template`.
   * Do not carefully migrate the stale template.

6. Remove the old source surface.
   * Delete the old `src/engine/world/tilemap` implementation after games build
     without engine tilemap exports.
   * Delete `src/engine/world/tilemap/tilemapManager.zig`.
   * Remove stale active-code comments that still describe engine-owned
     tilemaps.
   * Update `src/engine/world/todo.md` only for remaining tilemap documentation
     cleanup references.
   * Do not rewrite broader engine world docs as part of this migration.

7. Preserve and focus tests.
   * Move useful tilemap tests with the legacy utility.
   * Cover init/deinit storage ownership.
   * Cover coordinate/index conversion.
   * Cover neighbour lookup for at least one non-rectangular shape.
   * Cover flood-fill generation marks.
   * Cover that `.RANDOM` is no longer part of the API.
   * Avoid tests that only restate constant values.

8. Close the migration docs.
   * Trim `roadmap.md` as work completes.
   * Refresh or add `reference.md` only if the migrated utility needs a stable
     baseline description after implementation.
   * Remove or replace this todo when the migration is complete.

## 4. Validation

Run after code changes:

* `zig build test`;
* `zig build check_games`;
* targeted builds for migrated tilemap games if `check_games` does not cover
  them sufficiently.

If unrelated `World` test failures still block `zig build test`, record the
specific failure and use the narrower passing checks to validate the migration.

## 5. Explicit Non-Goals

* no new `World` grid model;
* no ECS entity-per-tile migration;
* no chunked renderer, mesh renderer, or batching rewrite;
* no broad tile data redesign;
* no full tilemap cache invalidation redesign;
* no new serialization or loading work;
* no engine-side tilemap compatibility aliases.
