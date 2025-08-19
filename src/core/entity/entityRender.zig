const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ HELPER FUNCTIONS ================

pub fn isOnScreen( e1 : *const Entity ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on screen", .{ e1.id });

  // Adding half the entity's scale to give a margin for angled entities ( 1.5 ~= 1.414)
  const screenScale = def.getHalfScreenSize().add( e1.scale.mulVal( 0.5 ));

  return e1.isOnRange( screenScale.mulVal( -1 ), screenScale );
}

pub fn clampInScreen( e1 : *Entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on screen", .{ e1.id });

  const screenScale = def.getHalfScreenSize();

  e1.clampInArea( screenScale.mulVal( -1 ), screenScale );
}


// ================ RENDER FUNCTIONS ================

inline fn drawDirectionLine( e1 : *const Entity, color : def.Colour, width : f32 ) void
{
  const frontPoint = Vec2.fromAngleScaled( e1.getRot(), e1.scale );
  def.drawLine( e1.getCenter(), e1.getCenter().add( frontPoint ), color, width );
}

inline fn drawPolyOne1( e1 : *const Entity, sides : u8 ) void
{
  def.drawPoly( e1.getCenter(), e1.scale, e1.getRot(), e1.colour, sides );
}

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

  switch( e1.shape )
  {
    .NONE => {},

    .LINE => { drawDirectionLine( e1, e1.colour, 2.0 ); },
    .RECT => { def.drawRect( e1.getCenter(), e1.scale, e1.getRot(), e1.colour ); },
    .STAR => { def.drawStar( e1.getCenter(), e1.scale, e1.getRot(), e1.colour ); },
    .DSTR => { def.drawDstr( e1.getCenter(), e1.scale, e1.getRot(), e1.colour ); },
    .ELLI => { def.drawElli( e1.getCenter(), e1.scale, e1.getRot(), e1.colour ); },

    .TRIA => { drawPolyOne1( e1,  3 ); },
    .DIAM => { drawPolyOne1( e1,  4 ); },
    .PENT => { drawPolyOne1( e1,  5 ); },
    .HEXA => { drawPolyOne1( e1,  6 ); },
    .OCTA => { drawPolyOne1( e1,  8 ); },
    .DODE => { drawPolyOne1( e1, 12 ); },
  }
}