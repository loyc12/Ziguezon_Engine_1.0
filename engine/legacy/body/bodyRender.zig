const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Body = eng.bdy.Body;
const Vec2 = utl.Vec2;

// ================ HELPER FUNCTIONS ================

pub fn isOnScreen( e1 : *const Body ) bool
{
  utl.log( .TRACE, 0, @src(), "Checking if Body {d} is on screen", .{ e1.id });

  const screenScale = utl.getHalfScreenSize();

  return e1.isOnArea( screenScale.neg(), screenScale.abs() );
}

pub fn clampInScreen( e1 : *Body ) void
{
  utl.log( .TRACE, 0, @src(), "Clamping Body {d} on screen", .{ e1.id });

  const screenScale = utl.getHalfScreenSize();

  e1.clampInArea( screenScale.neg(), screenScale.abs() );
}


// ================ RENDER FUNCTIONS ================

pub fn renderBody( e1 : *const Body ) void
{
  if( !e1.isVisible() )
  {
    utl.log( .TRACE, e1.id, @src(), "Body {d} is not visible and will not be rendered", .{ e1.id });
    return;
  }

  utl.log(   .TRACE, e1.id, @src(), "Rendering Body {d} at position {d}:{d} with shape {s}", .{ e1.id, e1.pos.x, e1.pos.y, @tagName( e1.shape ) });

  if( !isOnScreen( e1 ))
  {
    utl.log( .TRACE, e1.id, @src(), "Body {d} is out of range and will not be rendered", .{ e1.id });
    return;
  }

  const p = e1.getCenter();
  const s = e1.scale;
  const a = e1.getRot();
  const c = e1.colour;


  if( e1.shape == .RECT )
  {
    utl.wDraw.rect( p, s, a, c );
  }
  else if( e1.shape.isStar() )
  {
    utl.wDraw.star( p, s, a, c, e1.shape.getEdgeCount(), e1.shape.getSkipFactor() );
  }
  else // Lines can be handled by drawPoly()
  {
    utl.wDraw.poly( p, s, a, c, e1.shape.getEdgeCount() );
  }
}