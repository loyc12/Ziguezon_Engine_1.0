# Orbiter — Design Philosophy & Engineering Guidelines

This document is a reference for design and implementation decisions, not a feature list. When in doubt about whether a mechanic, refactor, or feature belongs in the game, read this and ask whether the proposal aligns with these principles.

For player-facing game design (gameplay loop, economic model, scope), see [design_document.md](design_document.md).

---

# Engineering Principles

## 1. Physical Causation First, Money Second

The economy is grounded in resource flows (minerals, energy, work, food). Money and prices are signals laid on top of physical flows; they should only change behaviour through agent decisions or enabling transactions, never replace the underlying physical accounting invariants. If we ever find ourselves clamping a stock for a pricing reason, we have inverted the layers.

---

## 2. Agent-Local Decisions, Global Consequences

Each economic agent (population, industry, infrastructure operator, government, trader) decides what to invest in or divest from solely based its own state (savings, margin, access). Aggregate behaviour is the sum of local decisions. There is no oracle that "knows" the right answer for the whole economy. The solver coordinates allocation, but it does not strategise.

---

## 3. Component-First, State-Explicit

Every persistent thing is a struct of plain data, accessed by typed keys (`ResStateData`, `IndStateData`, etc). Behaviour lives in functions that take those structs. No hidden mutable globals reachable from simulation code. If we cannot serialise it, it probably should not persist.

---

## 4. Multi-Scale by Construction

Mechanics must work the same whether you simulate one Mars colony or 200 economies across the system. Per-tick costs must be linear in the number of agents (or near-linear). Aggregation (variable tick rate, background economies) is a first-class feature, not a late optimisation.

---

## 5. High-Level Readability

The simulation should be inspectable. Logs are first-class. Significant metrics are accumulated even when no UI consumes them yet. Debug overlays should show the same numbers the solver uses, not summaries of summaries. If a balancing pass requires reading the source, logs are missing.

---

# Design Heuristics

* **"Why does this exist?"** — Every system must answer the question "what does the player do differently because this exists?". If the only answer is "nothing, but it is realistic", cut it.

* **"Could the player have predicted this?"** — Outcomes should be explicable from visible state and ensuing player descisions. If a colony collapses, the player should be able to walk back to the cause. Hidden randomness that significantly affect outcomes is forbidden; transparent randomness that abstract minute and irelevant details is acceptable.

* **"Does it scale?"** — Before adding a per-tick computation, multiply by 1000 economies and ask if it still ticks. If the answer is no, it needs optimisation and aggregation.

* **"Does it introduce a special case?"** — Prefer mechanics that fit inside an existing loop (another `ResType`, another consumer class) over mechanics that introduce a new top-level pass. The various solvers' phase ordering is the project's spine.

* **"Can a contributor read it cold?"** — Names, comments, and structure should be self-explanatory at the file level. Save cleverness for the math; the surface should be boring and readable, even if that means superfluous variable declaration or longer names.

---

# Collaboration Guidelines

* When adding planning a new feature, update the relevant roadmap FIRST. If no roadmap exist, or the feature because significant enough, a separate roadmap for this new feature-set should be strongly considered.

* Roadmaps are implementation contracts; if we realise a roadmap is suboptimal, it should be adjusted FIRST based on newinsight, rather than updated after implementation already significantly diverged

* Solver phases ( ex : `stepEcon`) are the spine. New behaviours get a new phase function or extends an existing one; do not bypass the phase ordering, unless it is strongly justified.

* Numbers in flight: keep `f64` inside the solvers. Round only when publishing back to econ state (e.g. floor / ceil at boundaries). It is easier to use the same scalar type everywhere than constantly convert between them.

* Logging is documentation. Every phase should log enough that a balance issue can be diagnosed from a single tick's logs without re-running the simulator. Well designed but currently unhelpful log calls should be commented out or set to TRACE, not removed.

* Debug-only code (`debugAutoBuild`, `debugSet*`, `debugTestEcon` ) lives next to the real code but is clearly marked with `debug`. It is allowed to violate general principle while the real version is being built. It must be considered as temporary, not gradually entrenched as a core program part.
