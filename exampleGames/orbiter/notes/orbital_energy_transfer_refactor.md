# Orbital Energy Transfer Refactor Task List

## Summary

Refactor Orbiter's transfer model away from pairwise Hohmann-style table recomputation and toward an on-demand hierarchical gravity-well cost proxy.

The target model should be deterministic, cheap to query, based on stored per-body orbital energy data, and adjusted only in the lowest common orbital frame shared by the source and destination route.

## Core Tasks

- [ ] 1. Replace the current transfer-table mental model with a per-body transfer cache keyed by dynamic `EntityId`.
- [ ] 2. Define a compact transfer node struct containing:
  - [ ] 2.1. parent id
  - [ ] 2.2. body mass and radius
  - [ ] 2.3. orbit semi-major axis
  - [ ] 2.4. eccentricity
  - [ ] 2.5. orientation
  - [ ] 2.6. current angular position and velocity
  - [ ] 2.7. gravitational parameter
  - [ ] 2.8. current orbital energy proxy
  - [ ] 2.9. SOI / Hill boundary energy proxy
  - [ ] 2.10. validity flag
- [ ] 3. Populate transfer node data from `OrbitComp`, `BodyComp`, and `ORBITANCE`.
- [ ] 4. Refresh transfer node data after the stellar system is initialized.
- [ ] 5. Refresh dynamic angular state after orbital positions update.
- [ ] 6. Add helpers to build ancestor chains from body ids.
- [ ] 7. Add a helper to find the lowest common orbital parent between two body ids.
- [ ] 8. Add an on-demand API such as `estimateTransfer( fromBodyId, fromLoc, toBodyId, toLoc )`.
- [ ] 9. Add a temporary compatibility wrapper for `BodyEconPair` callers if useful during migration.

## Location Rules

- [ ] 10. Add explicit transfer handling for `GROUND`.
- [ ] 11. Add explicit transfer handling for `ORBIT`.
- [ ] 12. Add explicit transfer handling for `L1` and `L2`.
- [ ] 13. Add explicit transfer handling for `L3`, `L4`, and `L5`.
- [ ] 14. Treat `GROUND` as body-local surface placement.
- [ ] 15. Treat `ORBIT` as body-local low orbit.
- [ ] 16. Treat `L1` and `L2` as body SOI gateway locations.
- [ ] 17. Treat `L3`, `L4`, and `L5` as parent-frame co-orbitals using angular offsets from the host body:
  - [ ] 17.1. `L3 = host angular position + PI`
  - [ ] 17.2. `L4 = host angular position + PI / 3`
  - [ ] 17.3. `L5 = host angular position - PI / 3`

## Cost Rules

- [ ] 18. Implement symmetric ascent and descent well costs using orbital energy differences.
- [ ] 19. Treat rising from and falling into a gravity well as the same cost by default.
- [ ] 20. Add the atmospheric landing exception:
  - [ ] 20.1. reduce only `GROUND` descent cost for Terra-style atmosphere
  - [ ] 20.2. keep this hardcoded or minimally represented until atmosphere becomes richer body data
- [ ] 21. Ensure placement inside intermediate wells is free except for ascent and descent.
- [ ] 22. Apply local mismatch penalties only in the lowest common orbital parent frame.
- [ ] 23. Include lowest-common-frame penalty for orbital energy difference.
- [ ] 24. Include lowest-common-frame penalty for eccentricity mismatch.
- [ ] 25. Include lowest-common-frame penalty for orientation mismatch.
- [ ] 26. Include lowest-common-frame penalty for phase / angular offset.
- [ ] 27. Include lowest-common-frame retrograde penalty when representative angular velocity signs oppose.
- [ ] 28. Keep inclination penalty at zero until the orbit model becomes 3D.

## Economy / Debug Integration

- [X] 29. Replace or deprecate `updateTravelTable()` so economy ticks no longer recompute all pairwise routes.
- [ ] 30. Avoid rebuilding an `N x N` route-cost table every economy tick.
- [ ] 31. Update debug logging to call the on-demand estimator instead of reading stale pairwise table entries.
- [ ] 32. Rename output fields away from physical `deltaV` terminology when downstream code no longer depends on it.
- [ ] 33. Until then, clearly document any compatibility fields as abstract cost proxies, not real maneuver delta-V.

## Test Scenarios

- [ ] 34. Terra ground to Terra orbit pays only Terra local ascent / descent.
- [ ] 35. Terra ground to Luna ground climbs and descends through the Terra / Luna hierarchy.
- [ ] 36. Phobos to Deimos uses Mars as the lowest common frame.
- [ ] 37. Terra to Mars uses Sol as the lowest common frame.
- [ ] 38. Terra L4 to Terra L5 avoids Terra well ascent and applies only Sol-frame local penalties.
- [ ] 39. Retrograde penalty applies only in the lowest common frame.
- [ ] 40. Pair costs are queried on demand without rebuilding an `N x N` table every economy tick.

## Assumptions

- A1. Rising and falling through a gravity well cost the same by default.
- A2. Atmospheric landing is the only asymmetric descent case for now. ( higher than normal to rise, lower than ascend do descend, factor aproximates irl costs )
- A3. Terra is the only current Earth-like atmospheric landing exception.
- A4. Inclination logic is present but commented out, in case inclination is added at a later point.
- A5. The first version should prioritize stable gameplay scaling over physical accuracy.
