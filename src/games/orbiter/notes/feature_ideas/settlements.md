# Settlement Types

Settlement types should carry rules that are currently too tightly coupled to
`EconLoc`. They describe how an economy physically exists at a location.

Near-term types:

* surface: hospitable or baseline body-surface settlement;
* subsurface: buried or covered settlement on inhospitable worlds and
  asteroids;
* aerial: Venus-like or gas-giant floating settlement;
* orbital: station, habitat, or orbital facility. Do not split orbital layers
  yet.

Deferred types:

* mobile: arcship, world ship, colony ship, or cycler economy;
* quarry: automated extraction site or asteroid mine.

Each body should eventually be able to hold one instance of each near-term
settlement type. The star may later host an arbitrary number of settlement
instances, but this is not MVP scope.
