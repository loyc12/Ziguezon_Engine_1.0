# Orbiter Design Philosophy

This file holds broad design and engineering heuristics for Orbiter. It is not
a feature list. For player-facing game design, see [design_doc.md](design_doc.md).
For current implementation facts, see [reference.md](reference.md).

## Engineering Principles

### Physical Causation First, Money Second

The economy is grounded in resource flows: minerals, energy, work, food, and
other physical capacities. Money and prices are signals layered on top of
physical flows. They should change behavior through agent decisions or enabled
transactions, never replace the physical accounting invariants.

If a stock is clamped for a pricing reason, the layers have been inverted.

### Agent-Local Decisions, Global Consequences

Each economic agent should decide what to invest in or divest from based on its
own state: savings, margin, resource access, policy, and local constraints.
Aggregate behavior is the sum of local decisions.

The solver coordinates allocation. It should not act as a global oracle that
knows the best answer for the whole economy.

### Game-Owned State, Explicit Boundaries

Persistent simulation state should be explicit plain data accessed through
typed keys and data matrices. Behavior should live in functions over that data.

Game-owned global state is acceptable when it is an intentional ownership
surface. `G_DATA` can hold broadly accessed mutable Orbiter runtime state, just
as `D_CONST` holds mostly-constant data. The problem to avoid is miscellaneous
hidden state with unclear lifetime, reset behavior, or serialization path.

If state cannot be reasoned about, reset, inspected, or eventually serialized,
it probably should not persist.

### Multi-Scale By Construction

Mechanics must work the same whether Orbiter simulates one Mars colony or many
economies across the solar system. Per-tick costs should be linear or
near-linear in the number of agents, or have an explicit aggregation path.

Aggregation, variable tick rates, and background-economy handling are
first-class design concerns, not late optimizations.

Do not force the MVP into one update model that makes later lightweight economy
types hard to add. Automated mines, ship-bound economies, regional aggregates,
and background economies should remain possible even if they are deferred.

### High-Level Readability

The simulation should be inspectable. Logs are first-class. Significant
metrics should be accumulated even when no UI consumes them yet.

Debug output should show the same values the solver uses, not disconnected
summaries. If a balancing pass requires reading the source, logs are missing.

The codebase should become more integrated and holistic as systems are reworked,
but not by imposing an abstract architecture doctrine. Prefer concise,
practical, locally understandable code shaped by the actual problem and the
project's existing style.

## Design Heuristics

### Why Does This Exist?

Every system must answer: what does the player do differently because this
exists?

If the only answer is "nothing, but it is realistic", cut it.

### Could The Player Have Predicted This?

Outcomes should be explainable from visible state and player choices. If a
colony collapses, the player should be able to trace the cause.

Hidden randomness that significantly affects outcomes is forbidden. Transparent
randomness that abstracts minute and irrelevant details is acceptable.

### Does It Scale?

Before adding per-tick computation, multiply it by many economies and ask
whether it still ticks. If not, it needs optimization, aggregation, or a
different model.

### Does It Introduce A Special Case?

Prefer mechanics that fit inside an existing loop, such as another resource
type or consumer class, over mechanics that introduce a new top-level pass.
The solver phase order is the simulation spine.

Special cases are acceptable when they model real economic differences, but
they should be named and isolated. Capacity resources, settlement types, and
trader agents are deliberate model concepts, not accidental bypasses.

### What Can Wait?

The project has a tendency to deepen simulation before proving the playable
loop. Defer systems that do not support the next stable economic sandbox,
especially politics, colonization, migration, ship modules, and detailed
demographics.

Do not defer the core economy rework when later features depend on it being
stable. Resource/capacity accounting, facilities, population, trade, and the
economy update pipeline are foundational.

### Can A Contributor Read It Cold?

Names, comments, and structure should be self-explanatory at the file level.
Save cleverness for math. The surface should be boring and readable, even when
that means longer names or explicit intermediate variables.

## Collaboration Guidelines

When planning a new feature, update the relevant roadmap first. If no roadmap
exists, or if the feature becomes significant enough, create a separate roadmap
for that feature set.

Roadmaps are implementation contracts. If a roadmap becomes suboptimal, adjust
the roadmap from the new insight before implementation significantly diverges.

Solver phases, such as `stepEcon`, are the spine. New behavior should get a
new phase function or extend an existing phase. Bypassing phase order requires
a strong justification.

During the economy rework, it is acceptable to replace `stepEcon` with a
better-organized successor pipeline if that makes resource, capacity,
facility, population, construction, trade, and finance behavior easier to
reason about.

Use `f64` inside solvers. Round only when publishing back to state or at
explicit integer boundaries.

Logging is documentation. Every phase should log enough that a balance issue
can be diagnosed from one tick's logs without re-running the simulator.
Well-designed but currently too-noisy log calls should be commented out or set
to trace-level behavior, not removed.

Debug-only code such as `debugAutoBuild`, `debugSet*`, and `debugTestEcon`
lives next to the real code but must be clearly marked with `debug`. It may
violate general principles while the real version is being built, but it should
stay temporary and should not become entrenched as a core program path.
