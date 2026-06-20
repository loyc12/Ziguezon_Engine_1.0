# Headless Engine Mode Idea

## Verdict

Headless mode is feasible, but the first version should be scoped as a practical
runtime mode, not as a full raylib-free build.

A useful MVP can keep raylib linked and compile with a headless option that
bypasses window creation, audio setup, input polling, and rendering. That would
let the engine run ticks and write runtime logs without requiring a window or
manual supervision.

A true no-graphics build is much larger. Raylib types are currently exposed
through `utils`, resource storage, drawing helpers, sprites, screen helpers, UI
mouse sampling, and game hook code. Removing raylib from compilation would need
a broader platform/render/audio abstraction pass.

## Current Choke Points

* `build.zig` links raylib unconditionally in `addGameExecutable()`.
* `src/main.zig` always transitions to `.OPENED`, then optionally `.PLAYING`,
  then enters `stepEngineLoop()`.
* `src/engine/core/engineState.zig` owns audio initialization, window creation,
  default font setup, audio shutdown, and window shutdown.
* `src/engine/core/engineStep.zig` owns the loop condition, input update, tick
  update, and render pass.
* `src/engine/gameAdapter/hooks.zig` already separates input, tick, and render
  hooks, which makes a headless tick-only mode practical.

## Main Risks

* The loop currently exits through `utl.ray.windowShouldClose()`. Headless mode
  needs an explicit stop condition such as max ticks, max seconds, or an engine
  quit flag.
* `OnInputUpdate` hooks in games often call `utl.ray` directly. Headless should
  skip input hooks by default unless synthetic input is added later.
* Render hooks can be skipped centrally, but game code and components still
  contain direct `utl.sDraw`, `eng.wDraw`, and sprite draw calls. Those are safe
  only if render hooks are not called in headless mode.
* `ResourceManager` stores raylib `Sound`, `Music`, `Font`, and sprite/texture
  types directly. Headless should either no-op resource loading/playback or
  avoid resource-heavy hooks until a resource policy exists.
* `utilsDef.zig` exposes `utl.ray` and raylib aliases globally. This is fine for
  a practical linked headless mode, but blocks a clean no-raylib build.

## Recommended MVP

1. Add a build option such as `-Dheadless=true`.
2. Expose that option to the engine through build options.
3. In headless mode, skip audio device setup, window config, window creation,
   default font setup, window close, and audio close.
4. Replace the loop condition with a headless runtime condition:
   max ticks, max elapsed time, or explicit quit flag.
5. Skip `tryUpdateInputs()` and `tryRenderFrame()` in headless mode by default.
6. Keep running `OnLoopStart`, `OnLoopUpdate`, `OnTickUpdate`,
   `OffTickUpdate`, `OnLoopEnd`, and `world.tick()`.
7. Log startup mode, tick count, elapsed time, and shutdown reason.

## Later Work

* Add synthetic input if headless game automation needs controllable actions.
* Add a resource policy for headless builds: no-op, metadata-only, or fail-fast.
* Add explicit engine quit/runtime control APIs instead of relying on window
  close state.
* Consider a platform facade only if raylib-free compilation becomes a real
  target.

