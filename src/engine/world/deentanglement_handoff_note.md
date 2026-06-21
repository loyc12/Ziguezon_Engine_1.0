# World Rule / Query Deentanglement Handoff

This note preserves the useful context from the interrupted rule/query/world
deentanglement attempt. It is intended to be copied out before reverting the
repo to a clean pushed state, then copied back in later to guide a fresh
implementation.

## 1. Actual Work In The Current Dirty Tree

The current worktree is not a clean successful implementation. It contains a
mix of prior uncommitted work plus the failed deentanglement attempt.

Observed dirty areas include:

* `AGENTS.md`;
* `docs/code_style.md`;
* `src/engine/core/engine.zig`;
* `src/engine/core/engineState.zig`;
* `src/engine/core/engineStep.zig`;
* `src/engine/engineDef.zig`;
* `src/engine/world/queries/query.zig`;
* `src/engine/world/rules/rule.zig`;
* `src/engine/world/rules/ruleManager.zig`;
* `src/engine/world/worldManager.zig`;
* `src/engine/world/reference.md`;
* `src/engine/world/roadmap.md`;
* `src/engine/world/todo.md`;
* several game files under `src/games`;
* untracked `src/engine/world/core/`;
* untracked `src/engine/world/deentanglement_todo.md`.

The deentanglement attempt specifically did this:

* changed `queries/query.zig` toward a stateless `WorldQuery` helper namespace;
* changed query helpers to take `worldPtr : *World` explicitly;
* moved `Rule`, `RuleFn`, and `RuleContext` into `rules/rule.zig`;
* changed `RuleContext` to borrow:
  * `world : *World`;
  * `commands : *CommandManager`;
* moved `RuleManager` implementation into `rules/ruleManager.zig`;
* removed `RuleManager.runAll(...)` and made `World.runRules()` build the
  short-lived `RuleContext` directly;
* changed rule tests in `core/world.zig` from `context.query.get...` calls to
  `WorldQuery.get...( context.world, ... )` calls;
* changed `worldManager.zig` exports to route `WorldQuery`, `Rule`,
  `RuleContext`, `RuleFn`, and `RuleManager` through the focused files instead
  of `core/world.zig`.

This state is not suitable to keep as-is.

## 2. Validation Result

`zig build` passed.

`zig build test` failed with a compile-time dependency loop:

```text
src/engine/world/rules/rule.zig:26:5: error: dependency loop detected
pub const RuleFn = *const fn ( *RuleContext ) bool;
~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
referenced by:
    Rule: src/engine/world/rules/rule.zig:30:18
    Rule: src/engine/world/rules/ruleManager.zig:6:18
    11 reference(s) hidden; use '-freference-trace=13' to see all references
```

The practical loop is:

```text
World
  owns RuleManager
    stores Rule
      stores RuleFn
        takes *RuleContext
          stores *World
```

The attempted direct concrete split therefore proved a real Zig dependency
cycle.

## 3. Agent / Project Rules Added

The following rule was added to `AGENTS.md` as a project instruction:

```md
## Zig Imports And Compile-Time Cycles

Do not preemptively add factories, type-erased wrappers, dependency injection,
or other indirection just to avoid possible Zig import/dependency loops.

Prefer the direct, concrete import/alias first. Let the Zig compiler prove
whether there is a real dependency-loop problem.

If a real compile-time dependency loop appears:
- report the exact compiler error and involved files;
- only try minimal local fixes if they preserve the existing concrete API;
- ask before introducing broader indirection, factories, or module reshaping;
- do not add generic factories for types that are expected to have only one
  concrete instantiation.
```

The durable `docs/code_style.md` form was:

```md
- Do not introduce generic factories or dependency-injection layers solely to
  avoid hypothetical Zig import loops. Use direct concrete imports first, and
  only refactor module boundaries after an actual compiler error or clear
  ownership problem.
```

These rules are still good guidance even though the attempted implementation
hit a real loop.

## 4. Architecture Goals From The Deentanglement Plan

Keep the intended ownership directions:

* `World` owns core simulation data and rule registration state;
* query helpers borrow a world through function arguments;
* rule execution borrows the world only for the duration of one rule pass;
* `WorldManager` remains the outer manager facade and should not absorb rule or
  query implementation details.

Keep focused module boundaries:

* `core/world.zig` for the concrete `World` type and closely owned behavior;
* `queries/query.zig` for `WorldQuery`;
* `rules/rule.zig` for `Rule`, `RuleFn`, and `RuleContext`;
* `rules/ruleManager.zig` for `RuleManager`;
* `worldManager.zig` for top-level world ownership and public re-exports.

Target shape:

* `World` owns:
  * entities;
  * components;
  * relations;
  * traits;
  * events;
  * commands;
  * archetypes;
  * registered rules.
* `WorldQuery` should not store `world : *World`.
* Query helpers should take `world : *const World` or `world : *World`
  explicitly.
* `Rule` should store `name`, `order`, and `runFn`.
* `RuleFn` should receive a short-lived `*RuleContext`.
* `RuleManager` should stay focused on rule storage, duplicate-name checks,
  and deterministic ordering.
* `RuleManager` should not become a broad world orchestration layer.
* `World.runRules()` should own construction of the short-lived rule context
  and should invoke registered rules in order.

## 5. Important Issue Discovered

The desired focused split conflicts with a concrete `RuleContext` that stores
`*World`.

`RuleContext` wanted `*World` so rules could inspect current facts by calling
stateless query helpers:

```zig
WorldQuery.getComp( context.world, TestComp, entityId )
WorldQuery.getEventIterator( context.world, TestEvent )
```

That creates the direct type cycle shown above.

Avoid treating this as a compiler annoyance to paper over with factories,
type-erased wrappers, dependency injection, or generic ownership machinery. The
loop is a real signal that the ownership/type boundary needs a clearer design
before implementation resumes.

## 6. Options Considered But Not Accepted

These came up during discussion and felt unsuitable:

* Keep `RuleContext` inside `core/world.zig`.
  * Smallest compile fix, but undermines the focused file boundary.
* Make `RuleContext` store only narrow manager pointers.
  * Avoids `*World`, but risks turning context/query into an ad-hoc duplicate
    of world APIs.
* Split `World` into a lower-level fact/data type plus a wrapper that owns
  rules.
  * Architecturally coherent, but a broader refactor than the current slice.
* Use type erasure, factories, dependency injection, or generic indirection.
  * Possible, but conflicts with the project rule unless a concrete design need
    justifies it beyond avoiding the import cycle.

Do not resume by choosing one of these automatically. Re-evaluate the rule
execution boundary first.

## 7. Suggested Fresh-Start Sequence

After reverting to the last pushed clean state:

1. Recreate only the plan/guardrail docs first.
2. Reconfirm whether `RuleContext` should expose broad world querying at all.
3. Decide the rule inspection surface before moving code:
   * should rules receive `*World`;
   * should rules receive a query namespace plus explicit world argument;
   * should rules receive a smaller world-read surface;
   * or should rule execution live in the same module as `World` until a better
     boundary is obvious.
4. Move only one boundary at a time:
   * query first;
   * then rule declarations;
   * then rule manager;
   * then `World.runRules()`.
5. Run `zig build test` after each boundary move.
6. If a dependency loop appears, stop and report the exact compiler error before
   changing architecture.

## 8. Current Recommendation

Revert the failed code changes rather than trying to rescue the current partial
split.

Keep this note and the deentanglement goals as the useful output. The next
implementation pass should begin from a clean tree and solve the rule context
boundary deliberately before moving files again.
