# Legacy Tilemap Migration Roadmap

## 1. Establish Utility Module

Move the existing tilemap source files into `src/utils/legacy_tilemap`:

* `tile.zig`;
* `tilemap.zig`;
* `tilemapShape.zig`;
* `tilemapFlood.zig`.

Create a module entrypoint for `utilsDef.zig` to export from a legacy section.
Do not add engine-side aliases.

## 2. Remove Engine Dependencies

Make the moved tilemap code independent from `engine`:

* replace engine tile imports with local legacy tilemap imports;
* remove `eng.G_ENG.rng` usage and delete `.RANDOM` behavior;
* make rendering functions take required engine-owned state as arguments;
* keep picking and geometry helpers engine-agnostic;
* preserve `Tile.colour` and cached `relPos` for compatibility.

If rendering needs a camera-derived view box, pass the camera or view box
explicitly. If the current camera API cannot provide the needed data cleanly,
add that ability to the camera rather than reintroducing engine globals into
`legacy_tilemap`.

## 3. Remove Tilemap Manager Ownership

Delete the engine-owned tilemap manager path from active engine code:

* remove `tilemapManager` from `Engine`;
* remove manager init/deinit from engine state transitions;
* remove tilemap tick/delete calls from engine stepping;
* remove tilemap render/debug calls from engine rendering;
* remove tilemap exports from `engineDef.zig`;
* remove `DebugDraw_Tilemap` from engine configs and game adapters.

Useful manager helper behavior may be moved into a legacy utility file only if a
game still needs it. The id system should not be preserved.

## 4. Migrate Games To Direct Ownership

For each active tilemap game:

* add a module-global `legacy_tilemap.Tilemap`;
* initialize it from the same hook where the game currently asks the manager to
  create a tilemap;
* deinitialize it from the matching game lifecycle hook;
* replace manager id lookups with direct access to the module-global tilemap;
* keep existing `TILEMAP_DATA` sidecar arrays;
* call tilemap rendering manually from the game's render hook, before other
  world rendering when practical;
* pass camera/render dependencies explicitly to tilemap render functions.

Migrate these games:

* `dehexer`;
* `granulater`;
* `isofloor`;
* `labyrinther`;
* `politator`.

Strip tilemap logic from:

* `debug`;
* `_template`.

## 5. Remove Old Source Surface

After games compile without engine tilemap exports:

* delete `src/engine/world/tilemap`;
* delete `src/engine/world/tilemap/tilemapManager.zig`;
* remove stale tilemap comments from active engine code;
* update `src/engine/world/todo.md` to track remaining doc cleanup references.

Do not rewrite broader engine world docs in this migration unless explicitly
requested.

## 6. Tests And Validation

Move useful tilemap tests with the legacy utility. Keep or add tests for
non-trivial behavior:

* init/deinit storage ownership;
* coordinate/index conversion;
* neighbour lookup for at least one non-rect shape;
* flood fill generation marks;
* removed `.RANDOM` behavior not being part of the API.

Avoid trivial tests that only restate constant values.

Expected validation:

* `zig build test`;
* `zig build check_games`;
* targeted builds for migrated tilemap games if `check_games` does not cover
  them sufficiently.

Current unrelated `World` test failures may need to be fixed before
`zig build test` can serve as full migration validation.
