const std = @import( "std" );
const def = @import( "defs" );



pub const OrbitComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  orbitee : ?def.EntityId = null,
  mass    : f32           = 1.0,

  pub fn tickOrbit
  (
    selfOrbit : *OrbitComp,     otherOrbit : *OrbitComp,
    selfTrans : *def.TransComp, otherTrans : *def.TransComp,
    sdt : f32
  ) void
  {
    const m1 = selfOrbit.mass;
    const m2 = otherOrbit.mass;

    const p1 = selfTrans.pos;
    const p2 = otherTrans.pos;

    const distSqr = p1.getDistSqr( p2 );

    const gravForce = m1 * m2 / distSqr;
    const gravDir   = p2.sub( p1 ).toAngle();

    selfTrans.acc += def.Vec2.fromAngle( gravDir ).mulVal( sdt * gravForce / m1 );
  }
};