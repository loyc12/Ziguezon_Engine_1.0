# Project Code Style

This project favors compact, explicit, performance-aware Zig code organized for
visual scanning. Formatting is intentionally maintained by hand and forms part
of the code's readability.

This guide describes the dominant style to preserve when writing or refactoring
code. Existing inconsistencies are not necessarily conventions to copy.

## Formatting And Visual Alignment

- Never run automatic formatting passes such as `zig fmt`.
- Use 2-space indentation.
- Place spaces inside parentheses and around type separators.
- Place opening braces on the following line for multi-line blocks.
- Keep trivial functions, guards, and branches on one line when they remain
  immediately readable.
- Preserve deliberate blank lines between conceptual groups.

Group related declarations and statements into visually aligned columns. Add
extra spaces where needed to align related:

- Names
- Types
- Assignment operators
- Function arguments
- Return types
- Switch arrows
- Calls and closing parentheses
- Inline comments

Alignment is intentional, not incidental whitespace. When modifying an aligned
group, realign the entire group. Align semantically related lines rather than
unrelated code merely located nearby.

```zig
const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const VecA  = utl.VecA;
const Angle = utl.Angle;
```

```zig
pub inline fn norm(  self : Vec2               ) Vec2 { return self.normToLen( 1.0 ); }
pub inline fn dot(   self : Vec2, other : Vec2 ) f64  { return ( self.x * other.x ) + ( self.y * other.y ); }
pub inline fn cross( self : Vec2, other : Vec2 ) f64  { return ( self.x * other.y ) - ( self.y * other.x ); }
```

```zig
switch( ng.state )
{
  .OFF     => start( ng ),
  .STARTED => open(  ng ),
  .OPENED  => play(  ng ),
  else     => unreachable,
}
```

## File Organization

- Begin with imports, followed by local type aliases grouped by domain.
- Use large banner comments for major file or struct sections.
- Use shorter banner comments for subsections and sub-subsections.
- Organize functions by responsibility rather than only by visibility.
- Keep public facade modules thin and delegate substantial behavior to focused
  implementation modules.

```zig
// ================================ ENGINE IMPLEMENTATIONS ================================

// ================ STATE FUNCTIONS ================

// ======== PLAY & PAUSE ========
```

## Implementation Style

- Prefer small functions with one clear responsibility.
- Use `inline` for inexpensive wrappers, predicates, conversions, and math
  helpers.
- Keep simple operations compact; expand functions when validation, branching,
  or lifecycle work requires explanation.
- Prefer direct iteration and mutation over abstraction-heavy designs.
- Prefer practical, performance-aware solutions over framework-heavy designs.
- Extract reused logic when it clearly reduces meaningful duplication.
- Keep ownership explicit through manager `init` and `deinit` functions.
- Initialize resources in dependency order and deinitialize them in reverse
  order.
- Separate scheduled operations from forced operations using clear names such
  as `tryTickWorld` and `forceTickWorld`.
- Remove deprecated or dead code made obsolete by a refactor.

## Defensive Behavior

- Validate lifecycle state and initialization before performing operations.
- On invalid operations, log the reason and return early.
- Use nullable returns for expected lookup or creation failures.
- Handle allocation failures close to the failing operation.
- Avoid silently correcting invalid state.
- Use dedicated epsilon-aware helpers for floating-point comparisons.

## Naming

- Types and structs use `PascalCase`.
- Functions, fields, and local variables use `lowerCamelCase`.
- Engine states and global configuration identifiers use uppercase.
- Use short, established module aliases such as `eng`, `utl`, and `ng`.
- Prefer behavioral prefixes that communicate contracts:
  - `is...` and `can...` for predicates
  - `get...` for retrieval
  - `try...` when work may be skipped
  - `force...` when scheduling restrictions are intentionally bypassed
  - `load...`, `render...`, `tick...`, and `delete...` for lifecycle operations
- Suggest clearer names when existing names are ambiguous.

## Comments And Logging

- Comments should explain intent, constraints, lifecycle phases, or non-obvious
  decisions. Avoid comments that merely restate straightforward code or add more
  visual noise than it clarifies context.
- Add `///` documentation comments to potentially ambiguous functions, data
  structures, types, and API calls.
- Prioritize documentation for game-facing and public engine-facing APIs:
  ownership boundaries, initialization/deinitialization requirements, pointer
  validity, failure behavior, ordering guarantees, and expected usage.
- Use normal `//` comments for local or codeblock implementation notes and
  `///` comments for declarations that users or future systems are expected
  to call, store, or copy.
- Use `NOTE` and `TODO` markers for specific concerns.
- Use scoped blocks to visually group lifecycle phases.
- Log state transitions, lifecycle events, invalid operations, and failures near
  their source.
