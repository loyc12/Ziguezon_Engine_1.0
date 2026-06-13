# Resource Subtypes

Resources should be grouped by category. Non-MVP entries can stay as
commented-out enum values until the resource system stabilizes.

Capacity resources are special: they are availability-priced,
non-transportable, and often behave like current `WORK`, which should become
`LABOUR`.

Starred entries are mandatory for Phase 1. Unstarred entries can be implemented
in Phase 2 if directly useful; otherwise defer them to post-MVP.

## Capacity

- area*
- housing*
- labour*  ( split into subtypes ? )
- compute
- energy*
- research

## Material

- organics
- water ice
- volatiles
- sillicates  ( includes regolith )
- base metals*
- rare earths
- deuterium

## Manufactured

- ingots*
- plating
- fabrics
- structures
- electronics
- machinery* ( replaces parts for now )

## Consumables

- foodstuffs*
- appliances
- propellant
- clean water*
- clean air
- dirty water*
