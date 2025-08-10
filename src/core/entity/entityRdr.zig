const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ HELPER FUNCTIONS ================

pub fn isOnScreen( e1 : *const Entity ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on screen", .{ e1.id });

  const shw : f32 = def.getScreenWidth()  / 2;
  const shh : f32 = def.getScreenHeight() / 2;

  return e1.isOnRange( Vec2{ .x = -shw, .y = -shh }, Vec2{ .x = shw,  .y = shh });
}

pub fn clampInScreen( e1 : *Entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on screen", .{ e1.id });

  const shw : f32 = def.getScreenWidth()  / 2;
  const shh : f32 = def.getScreenHeight() / 2;

  e1.clampInArea( Vec2{ .x = -shw, .y = -shh }, Vec2{ .x = shw,  .y = shh });
}


// ================ RENDER FUNCTIONS ================

inline fn drawDirectionLine( self : *const Entity, color : def.ray.Color, width : f32 ) void
{
  const frontPoint = def.radToVec2Scaled( self.getRot(), self.scale );
  def.drawLine( self.getCenter(), def.addVec2( self.getCenter(), frontPoint ), color, width );
}

inline fn drawPolyOnSelf( self : *const Entity, sides : u8 ) void
{
  def.drawPoly( self.getCenter(), self.scale, self.getRot(), self.colour, sides );
}

pub fn renderEntity( self : *const Entity ) void
{
  if( !self.isVisible() )
  {
    def.log( .TRACE, 0, @src(), "Entity {d} is not visible and will not be rendered", .{ self.id });
    return;
  }

  def.log(   .TRACE, 0, @src(), "Rendering Entity {d} at position {d}:{d} with shape {s}", .{ self.id, self.pos.x, self.pos.y, @tagName( self.shape ) });

  if( !isOnScreen( self ))
  {
    def.log( .TRACE, 0, @src(), "Entity {d} is out of range and will not be rendered", .{ self.id });
    return;
  }

  switch( self.shape )
  {
    // NOTE : Exhaustively listing the possible enums, so that the compiler warns if a shape is unimplemented
    .NONE => {},

    .LINE => { drawDirectionLine( self, self.colour, 2.0 ); },
    .RECT => { def.drawRect( self.getCenter(), self.scale, self.getRot(), self.colour ); },
    .STAR => { def.drawStar( self.getCenter(), self.scale, self.getRot(), self.colour ); },
    .DSTR => { def.drawDstr( self.getCenter(), self.scale, self.getRot(), self.colour ); },
    .ELLI => { def.drawElli( self.getCenter(), self.scale, self.getRot(), self.colour ); },

    .TRIA => { drawPolyOnSelf( self,  3 ); },
    .DIAM => { drawPolyOnSelf( self,  4 ); },
    .PENT => { drawPolyOnSelf( self,  5 ); },
    .HEXA => { drawPolyOnSelf( self,  6 ); },
    .OCTA => { drawPolyOnSelf( self,  8 ); },
    .DODE => { drawPolyOnSelf( self, 12 ); },
  }
}