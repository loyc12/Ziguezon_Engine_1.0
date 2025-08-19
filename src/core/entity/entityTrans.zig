const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ MOVEMENT FUNCTIONS ================

pub fn moveSelf( e1 : *Entity, sdt : f32 ) void
{
  if( !e1.isMobile() )
  {
    def.log( .TRACE, e1.id, @src(), "Entity {d} is not mobile and cannot be moved", .{ e1.id });
    return;
  }

  def.log( .TRACE, e1.id, @src(), "Moving Entity {d} by velocity {d}:{d} with acceleration {d}:{d} over time {d}", .{ e1.id, e1.vel.x, e1.vel.y, e1.acc.x, e1.acc.y, sdt });

  e1.vel.x += e1.acc.x * sdt;
  e1.vel.y += e1.acc.y * sdt;
  e1.vel.r += e1.acc.r * sdt;

  e1.pos.x += e1.vel.x * sdt;
  e1.pos.y += e1.vel.y * sdt;
  e1.pos.r += e1.vel.r * sdt;

  e1.acc.x = 0;
  e1.acc.y = 0;
  e1.acc.r = 0;
}