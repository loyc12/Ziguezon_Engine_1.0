# Orbiter Todo

This file tracks the active task loop for the current Orbiter rework. It is
currently scoped to Phase 0 of [roadmap.md](roadmap.md): alignment and safety
rails before live economy behavior changes.

## Phase 0 - Alignment And Safety Rails

Goal: make the rework vocabulary explicit before changing live behavior.

### 1. Audit Concept Replacements

Audit names that will be replaced or split:

* `Industry` / `Infrastructure` -> `Facility`;
* `EconLoc` -> `SettlementType` plus `BodyLocation`;
* current population `HUMAN` -> `dependants` / `workers`;
* agent/requester names -> `EconAgent` groups;
* `WORK` -> `LABOUR`.

### 2. Compile-Clean Renames

Perform code-wide compile-clean renames where they are simple and mechanically
safe:

* resources;
* facilities;
* population;
* old infrastructure/industry instance names.

Update comments and references during the rename pass.

### 3. Assumption Audits

Identify all code paths that assume economies are stored inside `BodyComp`.

Identify all code paths that assume current `EconLoc` values imply economy
rules.

Identify all code paths that hardcode:

* `WORK`;
* `PART`;
* `DEPOT`;
* `ASSEMBLY`;
* current infrastructure/industry tables.

### 4. Phase 1 Data Boundaries

Treat starred entries in [feature_ideas/resources.md](feature_ideas/resources.md)
and [feature_ideas/facilities.md](feature_ideas/facilities.md) as mandatory
Phase 1 entries.

Keep non-MVP resources and facilities as commented-out enum candidates rather
than implementing them early.

### 5. Phase 0 Exit Check

Phase 0 is complete when the first implementation slice can be described
without guessing which old concept maps to which new concept.

### 6. Archive Rule For Phase 1

Before a file receives its first major Phase 1 rewrite, copy its pre-Phase 1
version into `src/.oldFiles/` with the same relative path.

Do not edit archived files. Keep only one archived version unless the user
explicitly asks for another.
