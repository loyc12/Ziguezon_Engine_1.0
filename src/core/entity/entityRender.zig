const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ HELPER FUNCTIONS ================

pub fn isOnScreen( e1 : *const Entity ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on screen", .{ e1.id });

  const screenScale = def.getHalfScreenSize();

  return e1.isOnArea( screenScale.neg(), screenScale.abs() );
}

pub fn clampInScreen( e1 : *Entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on screen", .{ e1.id });

  const screenScale = def.getHalfScreenSize();

  e1.clampInArea( screenScale.neg(), screenScale.abs() );
}


// ================ RENDER FUNCTIONS ================

pub fn renderEntity( e1 : *const Entity ) void
{
  if( !e1.isVisible() )
  {
    def.log( .TRACE, e1.id, @src(), "Entity {d} is not visible and will not be rendered", .{ e1.id });
    return;
  }

  def.log(   .TRACE, e1.id, @src(), "Rendering Entity {d} at position {d}:{d} with shape {s}", .{ e1.id, e1.pos.x, e1.pos.y, @tagName( e1.shape ) });

  if( !isOnScreen( e1 ))
  {
    def.log( .TRACE, e1.id, @src(), "Entity {d} is out of range and will not be rendered", .{ e1.id });
    return;
  }

  const p = e1.getCenter();
  const s = e1.scale;
  const r = e1.getRot();
  const c = e1.colour;

  switch( e1.shape )
  {
    .RECT => { def.drawRect( p, s, r, c ); },
    .HSTR => { def.drawHstr( p, s, r, c ); },
    .DSTR => { def.drawDstr( p, s, r, c ); },
    .ELLI => { def.drawElli( p, s, r, c ); },

    .RLIN => { def.drawPoly( p, s, r, c,  1 ); },
    .DLIN => { def.drawPoly( p, s, r, c,  2 ); },
    .TRIA => { def.drawPoly( p, s, r, c,  3 ); },
    .DIAM => { def.drawPoly( p, s, r, c,  4 ); },
    .PENT => { def.drawPoly( p, s, r, c,  5 ); },
    .HEXA => { def.drawPoly( p, s, r, c,  6 ); },
    .OCTA => { def.drawPoly( p, s, r, c,  8 ); },
    .DODE => { def.drawPoly( p, s, r, c, 12 ); },
  }
}