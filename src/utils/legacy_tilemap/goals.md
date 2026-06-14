# Legacy Tilemap Goals

## Purpose

`legacy_tilemap` is a compatibility layer for games that still want a simple,
self-managed world grid without adopting the newer `engine/world` fact model.

The migration should move the existing tilemap code out of `engine/world` with
as few behavior changes as practical. The goal is quarantine and engine
detachment, not a full tile-grid redesign.

## Target State

* Tilemap code lives under `src/utils/legacy_tilemap`.
* `src/utils/utilsDef.zig` exports the module from a clearly marked legacy
  section.
* Engine code has no tilemap references, exports, configs, managers, lifecycle
  hooks, tick hooks, render hooks, or debug draw settings.
* Games own their tilemap values directly as module globals.
* Games manually initialize, deinitialize, tick, and render tilemaps from their
  own hooks.
* The old id-based tilemap manager model is removed.
* Existing game-local sidecar arrays such as `TILEMAP_DATA` remain the game data
  source for tile-specific simulation state.
* The feature is documented and named as legacy so future `World` grid work does
  not inherit its structure by default.

## Hard Boundaries

* `legacy_tilemap` must not import `engine`.
* `engine` must not import or mention `legacy_tilemap`.
* Rendering convenience functions may remain, but callers must pass all
  engine-owned objects they need, such as the camera.
* Tilemap rendering is game-driven. There is no automatic engine render pass for
  tilemaps.
* Tilemap ticking and deletion are game-driven. There is no automatic engine tick
  pass for tilemaps.
* The old `.RANDOM` tile type and engine-global random fill behavior are removed.
  If current games need randomization, provide a small explicit helper that takes
  a randomizer argument.
* `Tile.colour` and cached relative positions stay for compatibility, even
  though they are legacy rendering/cache state.
* Cache invalidation risks should be commented where relevant, but broad cache
  redesign is deferred.

## Game Scope

Migrate active tilemap games that still depend on the engine manager:

* `src/games/dehexer`;
* `src/games/granulater`;
* `src/games/isofloor`;
* `src/games/labyrinther`;
* `src/games/politator`.

Strip tilemap usage from:

* `src/games/debug`;
* `src/games/_template`.

The template is stale and should not receive a careful tilemap migration.

## Compatibility Policy

Keep current behavior as close as practical for migrated games:

* preserve existing tile sidecar arrays;
* preserve existing shape, picking, neighbour, flood fill, and colour behavior;
* preserve render order where easy, with tilemaps rendering before the rest of
  each game's world rendering;
* fix obvious correctness or ownership bugs when they block safe migration;
* avoid large design improvements that can wait for later extraction into
  smaller reusable utilities.

## Non-Goals

* no new `World` grid model in this migration;
* no ECS entity-per-tile migration;
* no chunked renderer, mesh renderer, or batching rewrite;
* no broad tile data redesign;
* no full tilemap cache invalidation redesign;
* no new serialization/loading work;
* no compatibility aliases from `engineDef.zig`.

## Future Direction

After this migration, smaller reusable utilities may be extracted from
`legacy_tilemap`, such as dense grid indexing, topology, flood fill, shape
projection, or picking helpers.

Those future utilities should be designed as clean, engine-agnostic primitives.
They should not preserve legacy tilemap behavior unless that behavior is still
useful on its own.
