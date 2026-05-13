# Orbiter — Design Philosophy & Engineering Guidelines

This document is a reference for design and implementation decisions, not a feature list. When in doubt about whether a mechanic, refactor, or feature belongs in Orbiter, read this and ask whether the proposal aligns with these principles.

For player-facing game design (gameplay loop, economic model, scope), see [design_document.md](design_document.md).

---

# Engineering Principles

## 1. Physical Causation First, Money Second

The economy is grounded in resource flows (mass, energy, work). Money and prices are signals laid on top of physical flows; they should only change behaviour through agent decisions, never replace the underlying physical accounting. If we ever find ourselves clamping a stock for a pricing reason, we have inverted the layers.

---

## 2. Agent-Local Decisions, Global Consequences

Each economic agent (pop, industry, infrastructure operator, government, trader) decides from its own state (savings, margin, access) and only its own state. Aggregate behaviour is the sum of local decisions. There is no oracle that "knows" the right answer for the whole economy. The solver coordinates allocation, but it does not strategise.

---

## 3. Component-First, State-Explicit

Every persistent thing is a struct of plain data, accessed by typed keys (`ResStateData`, `InfStateData`, etc). Behaviour lives in functions that take those structs. No hidden mutable globals reachable from simulation code. If we cannot serialise it, it probably should not exist.

---

## 4. Multi-Scale by Construction

Mechanics must work the same whether you simulate one Mars colony or 200 economies across the system. Per-tick costs must be linear in the number of agents (or near-linear). Aggregation (variable tick rate, background economies) is a first-class feature, not a late optimisation.

---

## 5. Research-Grade Readability

The simulation should be inspectable. Logs are first-class. Metrics are accumulated even when no UI consumes them. Debug overlays should show the same numbers the solver uses, not summaries of summaries. If a balancing pass requires reading the source, something is wrong.

---

# Design Heuristics

* **"Why does this exist?"** — Every system must answer the question "what does the player do differently because this exists?". If the only answer is "nothing, but it is realistic", cut it.

* **"Could the player have predicted this?"** — Outcomes should be explicable from visible state. If a colony collapses, the player should be able to walk back to the cause. Hidden randomness that flips outcomes is forbidden; transparent randomness that varies textures is fine.

* **"Does it scale?"** — Before adding a per-tick computation, multiply by 1000 economies and ask if it still ticks. If the answer is no, it needs optimisation and aggregation.

* **"Does it introduce a special case?"** — Prefer mechanics that fit inside an existing loop (another `ResType`, another consumer class) over mechanics that introduce a new top-level pass. The solver's phase ordering is the project's spine.

* **"Can a contributor read it cold?"** — Names, comments, and structure should be self-explanatory at the file level. Save cleverness for the math; the surface should be boring and readable.

---

# Collaboration Guidelines

* When adding a feature, update the relevant roadmap FIRST. The roadmap is the contract; the code follows it, not the other way round.

* Solver phases ( ex : `tickEcon`, `stepEcon`) are the spine. New behaviour gets a new phase function or extends an existing one; do not bypass the phase ordering.

* Numbers in flight: keep `f64` inside the solver. Round only when publishing back to econ state (e.g. floor / ceil at boundaries).

* Logging is design documentation. Every phase should log enough that a balance issue can be diagnosed from a single tick's logs without re-running the simulator.

* Debug-only code (`debugAutoBuild`, `debugSet*`, `testEconLogs`) lives next to the real code but is clearly marked. It is allowed to violate the agent-locality principle while the real version is being built. It must be replaced, not entrenched.
