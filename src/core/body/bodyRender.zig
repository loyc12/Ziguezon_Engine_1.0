const std = @import( "std" );
const def = @import( "defs" );

const Body = def.bdy.Body;
const Vec2 = def.Vec2;

// ================ HELPER FUNCTIONS ================

pub fn isOnScreen( e1 : *const Body ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Body {d} is on screen", .{ e1.id });

  const screenScale = def.getHalfScreenSize();

  return e1.isOnArea( screenScale.neg(), screenScale.abs() );
}

pub fn clampInScreen( e1 : *Body ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Body {d} on screen", .{ e1.id });

  const screenScale = def.getHalfScreenSize();

  e1.clampInArea( screenScale.neg(), screenScale.abs() );
}


// ================ RENDER FUNCTIONS ================

pub fn renderBody( e1 : *const Body ) void
{
  if( !e1.isVisible() )
  {
    def.log( .TRACE, e1.id, @src(), "Body {d} is not visible and will not be rendered", .{ e1.id });
    return;
  }

  def.log(   .TRACE, e1.id, @src(), "Rendering Body {d} at position {d}:{d} with shape {s}", .{ e1.id, e1.pos.x, e1.pos.y, @tagName( e1.shape ) });

  if( !isOnScreen( e1 ))
  {
    def.log( .TRACE, e1.id, @src(), "Body {d} is out of range and will not be rendered", .{ e1.id });
    return;
  }

  const p = e1.getCenter();
  const s = e1.scale;
  const a = e1.getRot();
  const c = e1.colour;

  switch( e1.shape )
  {
    .RECT => { def.drawRect( p, s, a, c ); },
    .HSTR => { def.drawHstr( p, s, a, c ); },
    .DSTR => { def.drawDstr( p, s, a, c ); },
    else  => { def.drawPoly( p, s, a, c, e1.shape.getSideCount() ); },
  }
}