# Legacy Tilemap Reference

## Purpose

`legacy_tilemap` is a compatibility utility for games that still use a simple
self-owned tile grid. It is intentionally separate from `engine/world` and is
not a model for future fact-oriented World grid work.

## Public Surface

The module entrypoint is exported from `src/utils/utilsDef.zig` as:

```zig
utl.legacy_tilemap
```

It exposes:

* `Tile`;
* `TileFlags`;
* `TileType`;
* `Tilemap`;
* `TilemapFlags`;
* `TilemapShape`;
* `FloodRule`.

## Ownership And Lifecycle

Games own tilemap values directly, usually as module globals in their
`stateInjects.zig` files.

Games initialize tilemaps by calling `Tilemap.createTilemapFromParams(...)` or
`Tilemap.init(...)` with a game-chosen allocator. Games deinitialize them from
their matching close/shutdown hook by calling `Tilemap.deinit(...)`.

There is no engine-owned tilemap manager, id lookup, automatic tick pass,
automatic delete pass, automatic render pass, or engine-side tilemap export.

## Rendering Contract

Tilemap rendering is caller-driven:

```zig
grid.drawSelf( eng.G_ENG.camera.toViewBox(), eng.wDraw );
```

The caller passes the camera-derived view box and the drawer namespace
explicitly. This keeps `legacy_tilemap` free of `engine` imports while preserving
the old world-drawer visuals.

Games that need tilemaps behind sprites or overlays should render them from the
appropriate game render hook before drawing those later objects.

## Data Model

`Tilemap` stores:

* world-space map position;
* grid dimensions;
* tile scale;
* tile shape;
* allocated tile array;
* flood-fill generation marker.

`Tile` stores:

* generic tile type;
* tile-local flags;
* map coordinates;
* flood-fill generation marker;
* compatibility render colour;
* cached tilemap-relative position.

Game simulation data belongs beside the game, not inside the tilemap. Existing
sidecar arrays such as `TILEMAP_DATA` remain the source of game-specific tile
state.

## Behaviour Notes

`TileType.PARITY` remains for parity-colour fills. The old `.RANDOM` type and
engine-global random fill behavior are removed. Games that need random terrain
choose random tile values during their own initialization.

Cached `Tile.relPos` is kept for compatibility. Shape changes call
`resetCachedTilePos()`. Games that directly change `tileScale`, `mapSize`, or
other geometry-defining fields after initialization must reset cached positions
themselves.

Flood fill uses generation marks instead of clearing every tile before each
fill. `resetFloodMarks()` remains available when a caller needs an explicit
reset.

## Current Game Users

The migrated active users are:

* `src/games/dehexer`;
* `src/games/granulater`;
* `src/games/isofloor`;
* `src/games/labyrinther`;
* `src/games/politator`.

`src/games/debug` and `src/games/_template` no longer include tilemap examples.

## Non-Goals

`legacy_tilemap` is not:

* a new `World` grid model;
* an ECS entity-per-tile system;
* a chunked or batched renderer;
* a serialization/loading system;
* a cache-invalidation redesign;
* an engine-managed object.

Future reusable grid, topology, flood-fill, shape-projection, or picking helpers
should be extracted as clean engine-agnostic primitives rather than inheriting
legacy tilemap behavior by default.
