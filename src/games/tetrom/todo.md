# Tetrom Clear Events, Collapse, Combo Score, And Feedback

## Scope

Implement a staged clear event after a piece locks. It must make diagonal clears
legible, collapse the settled board in a centre-out queue, resolve cascades,
and present clear-event score feedback. Keep the clear detector and collapse
algorithm independently replaceable; do not fold this into active-piece input,
spawn, or render-cache ownership.

## Target Behaviour

- A lock detects both full-width axial diagonal line families and builds one
  deduplicated clear-cell union.
- The clear union records its line count, unique crossing count, and base score
  before any cells move.
- A clear event pauses active-piece progression and spawning until all of its
  clear waves finish.
- Marked cells flash from their original colour to white, then toward the
  playfield grey, before their removal.
- The first implementation uses vertical per-column compaction (`q` constant),
  animated as expanding centre-out one-cell pulses.
- New diagonal lines formed by collapse become another wave in the same clear
  event. The event ends only when no clear remains.
- A clear event accumulates score privately, then adds the final event total to
  `Game.score` once the event ends.

## Data And Ownership Boundary

Keep transient clear data in Tetrom game state, separate from `Board.cells`.
Do not add a `Clearing` board-cell value: the original cell colour remains
needed for the flash, and future collapse models should not depend on a render
sentinel.

```zig
ClearPhase = enum { None, FlashToWhite, FadeToField, Collapse };

PendingClear = struct {
  cells       : [ Board.cellCount ]bool,
  lineCount   : u8,
  crossings   : u8,
  baseScore   : u64,
};

ClearEvent = struct {
  phase           : ClearPhase,
  pending         : PendingClear,
  phaseElapsed    : f32,
  collapsePulse   : usize,
  collapseProgress: [ Board.width ]u8,
  eventScore      : u64,
  latestWaveScore : u64,
  comboBonus      : u64,
  waveCount       : u8,
};
```

`Game` owns the pending-clear/event state. `stateInjects` remains a board-to-
tile display cache. `stepInjects` advances timers, starts queued visual work,
and triggers small camera shake / score presentation. The detector and
compactor should be private `Game` methods with a narrow result/plan boundary.

Keep all initially chosen presentation values as mutable Tetrom globals rather
than buried literals: `CLEAR_FLASH_DURATION`, `CLEAR_FADE_DURATION`,
`COLLAPSE_PULSE_DELAY`, plus the non-time camera-shake strength/scale values.
They are development tuning controls, not engine configuration.

## Planned Source Split

Keep the split concrete and local to Tetrom; do not introduce a generic engine
framework for line clears.

- `game.zig`: `Game`, `Board`, active-piece lifecycle, collision, spawn/lock,
  and the narrow calls into clear resolution. It remains the game-facing owner.
- `clearEvent.zig`: clear phases, pending-clear/event records, diagonal union
  detection, clear-wave lifecycle, cascade orchestration, and the
  column-collapse plan/result types.
- `score.zig`: triangular line base, normalized-sigmoid crossing factor, and
  clear-event combo accumulation. It contains no rendering or board mutation.
- `clearFeedback.zig`: transient centre-score display state and reduced
  `Shake2D` state/update helpers. `stepInjects` calls it; rendering remains in
  the existing world/overlay hooks.
- `stateInjects.zig`: only receives a small display query such as
  `getClearDisplayOverride(index)` so it can render flash/fade colours without
  owning clear state.

Create these files only when implementing the first clear-event slice. Avoid
moving unrelated active-piece, input, or tilemap code merely to satisfy a file
count; each new file must own one durable concern listed above.

## Implementation Plan

1. **Separate locking from spawning.**

   - `lockActivePiece` writes the in-bounds active cells as it does now.
   - Run diagonal detection immediately after the write.
   - If there is no clear, spawn immediately as today.
   - If there is a clear, initialise `ClearEvent` and retain no active spawn
     until the event has completed.
   - While an event is active, skip movement, gravity, locking, and spawning.
     Reset remains available.

2. **Capture one clear wave.**

   - Reuse the existing two-family detector.
   - Build a union mask; a second mark of the same cell increments
     `crossings` exactly once for that cell.
   - Do not erase board cells yet.
   - Calculate the wave base score now:

     ```text
     base = 100 × lines × (lines + 1) / 2
     crossing factor = normalized sigmoid from 1× toward 2×
     wave score = round(base × crossing factor)
     ```

3. **Render the flash/fade phase.**

   - Add mutable globals for flash-to-white and fade-to-field-grey durations.
   - `syncGridDisplay` consults `PendingClear.cells` and the clear phase to
     override only marked display colours; it must not mutate `Board.cells`.
   - Start the reduced camera shake at the beginning of `FlashToWhite`; its
     intensity reaches its configured peak when the marked tiles reach white.
   - At fade completion, erase the marked board cells together and build the
     compaction plan.

4. **Implement a replaceable per-column compaction plan.**

   - Create a private `buildColumnCollapsePlan(board, clearMask)` routine that
     produces target contents per column without modifying the live board.
   - For each fixed board `x` / axial `q`, retain non-empty cells in bottom-up
     order and pack them toward the floor. This is the simple, deterministic
     initial model.
   - Produce centre-out pulse groups for width 9:

     ```text
     4
     4, 3, 5
     4, 3, 5, 2, 6
     4, 3, 5, 2, 6, 1, 7
     4, 3, 5, 2, 6, 1, 7, 0, 8
     ```

   - On every configurable pulse, advance each included column by one planned
     cell step toward its target, then expand to the next group. Continue the
     full-width group until every column reaches its planned target. This is a
     true outward visual wave rather than one whole column settling before the
     next begins.
   - Keep the destination plan separate from this pulse animation. The
     plan/result boundary allows later replacement with rigid connected-
     component gravity without changing detection, scoring, or the event state
     machine.

5. **Resolve the clear event and cascades.**

   - Once all planned columns have committed, scan again for diagonal clears.
   - If another wave exists, start its flash phase without spawning a piece.
   - Otherwise, add `eventScore` to `Game.score`, finish the event, and spawn
     the next piece. Its spawn collision check, and therefore game-over, always
     happens after collapse and all possible cascade waves have resolved.

6. **Accumulate combo score per clear event.**

   - First wave: `eventScore = waveScore`.
   - Every successive wave:

     ```text
     eventScore = floor(eventScore × 1.5) + waveScore
     ```

   - Do not add intermediate waves to `Game.score`; display the accumulating
     event score as feedback, then commit it once at event completion.
   - Record `latestWaveScore` and the value contributed by the 1.5× carry
     (`comboBonus`) separately, so feedback can distinguish the new clear's
     score from its combo contribution.

7. **Add score feedback and reduced Dehexer-style shake.**

   - Show the current accumulating event score in green at screen centre while
     a clear event runs, so it visibly grows from wave to wave.
   - Show smaller values beneath it for the latest wave award and the added
     1.5× combo contribution.
   - Map award magnitude through a clamped/interpolated range to choose font
     size between configured minimum and maximum values; use `utl.lerp`.
   - Port `utl.Shake2D` usage from Dehexer, but use substantially lower
     mutable translation/rotation strengths and advance it using measured tick
     time, not a hard-coded 120 Hz increment.
   - Shake only the world camera initially; HUD and clear-score feedback remain
     stable. Trigger the shake once per wave, scaling gently with line count
     and crossings.

8. **Validate targeted cases.**

   - One diagonal clear, one line from each family crossing once, and a four-by-
     four clear producing the maximum eight lines.
   - A crossing whose excluded side regions contain settled cells.
   - A collapse that produces a second clear wave.
   - Event score sequence with a small first wave and a large first wave.
   - Score feedback separates wave award from combo bonus.
   - Reset during each phase; game-over spawn only after event completion.

9. **Apply the planned source split during implementation.**

   - Extract scoring first because it has pure inputs/outputs and can be
     checked independently.
   - Extract clear-event state/detection next, leaving `Game.lockActivePiece`
     as a short coordinator.
   - Extract score/shake presentation only after event records exist, so UI
     code does not invent duplicate timing state.

## Deferred Upgrade: Rigid Components

The initial column compactor can shear multi-column structures when columns
lose different numbers of cells. A later replacement can flood-fill remaining
six-neighbour connected components after the clear union is removed, drop each
component rigidly in gravity order, and use column packing only for explicitly
permitted fractures. Keep this out of the first implementation, but preserve
the plan boundary above so it does not require a clear-system rewrite.

## Approved Decisions

1. Collapse uses the outward one-cell pulse wave described above.
2. The suggested phase defaults are accepted: 0.12 s flash-to-white, 0.18 s
   fade-to-grey, and 0.04 s between collapse pulses. All are mutable globals.
3. Collapse and all cascades always complete before the next spawn collision
   check can trigger game over.
4. The central green display shows the accumulating event award, with smaller
   latest-wave and 1.5× combo-bonus values beneath it.
5. Only the world camera shakes initially. Shake starts with the clear flash
   and peaks at the white endpoint; its durations and strength controls are
   mutable globals.
