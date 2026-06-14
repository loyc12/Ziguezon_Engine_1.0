# Orbiter Idea Parking

This file parks cross-cutting Orbiter ideas that should influence design, but
are not direct MVP requirements yet. Keep concrete MVP target state in
[../goals.md](../goals.md).

## Post-MVP Gameplay

Colonization is deferred until after the economic-simulation MVP. The MVP may
use pre-existing Terra, Luna, and Venus economies rather than asking the player
to found new settlements.

Politics is also post-MVP. Government data, taxes, subsidies, and trade support
can exist for economic control, but autonomy, laws, unrest, welfare, political
divergence, and local-governor behavior should wait until the economy loop is
stable.

The long-term game still needs a real gameplay core, not only a detailed
simulation. Player-facing goals, victory/failure conditions, expansion pacing,
colonial directives, crises, and inspectable decisions should be revisited
after the economy rework stops consuming all design bandwidth.

## Ships And Logistics

Ships should eventually contain modules with specific purposes. Module design
must remain compatible with facilities, capacity resources, population support,
storage, trade, and future ship-bound economies.

Ship modules are not part of the MVP. MVP trade can be abstract and should not
require vessel entities, cargo entities, migration, or ship movement.

Possible later module families:

* cargo holds;
* fluid tanks;
* quarters;
* reactors;
* engines;
* shielding;
* hangars;
* mass drivers.

Trade-route agents may eventually own route-local inventories. More generally,
agents may later own inventories sized from their represented facilities or
roles. Defer this unless next-tick wholesale trade proves too limiting.

## Trade And Transfer Realism

The current transfer estimator exposes approximate `deltaE`, `deltaV`, and
`deltaT`. Long term, trade should account for dynamic transfer windows, dynamic
fuel cost from `deltaV`, supply cost, and travel time.

For the MVP, use a simpler `deltaV` transfer-cost gate. It can use current,
best-case, or clamped `deltaV`, reviewed so bad temporary transfer geometry
does not explode route costs and prevent stable test economies.

Transfer windows should become important later: a trade route may wait for a
cheaper or faster window rather than departing immediately.

## Economy Variants

The MVP should implement full economies first. Later, economy types may split
into lighter update models:

* normal local economies;
* automated asteroid mines;
* ship-bound economies;
* arcships or colony ships;
* interplanetary cyclers;
* regional aggregate economies such as the asteroid belt.

Do not overfit the MVP update loop so tightly that lighter economy variants
become difficult to add.

## Population Depth

The MVP only needs dependants and workers. Births create dependants, and
dependants convert into workers at a fixed rate. A roughly 1/20 per-year
conversion rate is the current MVP target, implemented as a close per-week
float ratio.

Later conversion rules may depend on education, wealth, laws, culture, or local
policy. That depth should wait until the simple two-type loop is stable and
useful.

Migration is deferred.

## Settlements And Locations

Settlement types should eventually take over logic currently attached directly
to `EconLoc`. Surface, subsurface, aerial, and orbital settlement types are the
near-term vocabulary.

Mobile, quarry, split orbital layers, arbitrary solar-orbit settlements, and
star-hosted multiple locations are deferred ideas.

Economies are now game-owned data referenced by bodies through ids. Future
settlements, routes, and mobile entities should keep using references into the
game-owned economy container rather than owning economy state directly.

## Resources And Facilities

Resources need a broad revamp. Capacity resources are a special resource class
similar to current `WORK`: availability-priced, non-transportable, and produced
by facilities or population instead of shipped between economies.

Facilities should fold current industry and infrastructure into one stable
concept. Categories and subtypes can preserve the design distinction between
industry-like, infrastructure-like, extraction, manufacturing, service,
transport, and capacity-producing facilities.

The MVP can use one `EconAgent` per facility type present in each economy.
Grouping facility agents above the facility-type level may be useful later if
per-type agents prove too noisy or costly, but do not use per-instance facility
agents by default.

Non-MVP resources and facilities may stay as commented-out enum values while
the systems stabilize.

`FUEL` should be removed from the MVP after Phase 0 and replaced much later by
a propellant/fuel model.

Code and docs should use Canadian spelling, including `LABOUR`.

## Codebase Integration

Many Orbiter systems were developed independently: bodies, orbits, economies,
build queues, the economy solver, travel, data grids, and feature notes. The
rework should make these systems feel more integrated without forcing an
abstract architecture doctrine onto the codebase.

The desired code style is clean, concise, inspectable, practical, and aligned
with the author's taste. Prefer clear data flow and local reasoning over large
framework-like abstractions.

## Notes Cleanup

Older notes, TODOs, and session ideas should be gathered and classified over
time as:

* MVP input;
* post-MVP idea;
* design philosophy;
* stale or superseded;
* needs explicit user decision.

Do not discard old ideas silently. Shelve them unless the user approves removal
or replacement.

## Quick idea dump

having agents own their own storage directly
