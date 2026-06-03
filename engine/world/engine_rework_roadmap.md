# ENGINE REWORK ROADMAP - ZIGUEZON ENGINE

This file holds implementation sequencing and migration notes for the
world/entity/simulation rework. The guiding principles live in
`engine/world/entity_roadmap.txt`.


## Immediate Blocker

Move legacy `BodyManager` and Script usage onto the current ECS/world direction
before deeper simulation infrastructure work. This is a blocker, not the main
design topic of the world reference document.


## Build Direction

1. Stabilize the current ECS path after legacy migration.

2. Add `engine/world/world.zig`.

3. Move entity and component access behind `World`.

4. Rework the component system around user-selectable storage policies:
   `storeType = .dense`, `storeType = .sparse`, and later other policies when
   justified.

5. Keep at least one minimal generic reference component in engine code.

6. Add relation storage as the first major World extension after the World
   wrapper and component rework.

7. Keep at least one minimal generic reference relation in engine code.

8. Add generic event records/queues after entity/component/relation changes have
   clear ownership.

9. Keep at least one minimal generic reference event in engine code.

10. Add rule/reaction support only after events exist.

11. Keep at least one minimal generic reference rule/reaction in engine code.

12. Add traits/metaproperties and archetypes/templates after the base world data
    model is usable.

13. Keep at least one minimal generic reference trait and archetype in engine
    code.

14. Add scheduler/query/view helpers progressively, driven by real game needs.


## Implementation Constraints

- Keep implementation details out of `entity_roadmap.txt`.
- Keep engine-level examples generic.
- Do not add specialized simulation content to engine/world.
- Do not grow a large built-in content library.
- Prefer data tables, relation indexes, and explicit metadata over hidden object
  graphs.
- Avoid linked-list storage unless a specific profile proves it is justified.
- Preserve room for future save/load and deterministic replay without building
  those systems yet.
