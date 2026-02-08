const std = @import( "std" );
const def = @import( "defs" );



pub const OrbitComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  const gravForceFactor = 1_000_000_000;

  orbiteeId : ?def.EntityId = null,
  mass      : f32           = 1.0,
  isStatic  : bool          = false,

  pub fn tickOrbit
  (
    selfOrbit : *const OrbitComp, otherOrbit : *const OrbitComp,
    selfTrans : *def.TransComp,   otherTrans : *const def.TransComp,
    sdt : f32
  ) void
  {
    if( selfOrbit.isStatic ){ return; }

    //const m1 = selfOrbit.mass;
    const m2 = otherOrbit.mass;

    const p1 = selfTrans.pos;
    const p2 = otherTrans.pos;

    const distSqr = p1.getDistSqr( p2 );

    const gravForcePart = gravForceFactor * m2 / distSqr; // Partial Gravitatinal force ( avoids dividing by m1 later )
    const gravDir       = p2.sub( p1 ).toAngle();

    selfTrans.acc = selfTrans.acc.add( def.Vec2.fromAngle( gravDir ).mulVal( sdt * gravForcePart ).toVecA( .{} ));
  }
};