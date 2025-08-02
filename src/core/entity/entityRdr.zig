const std = @import( "std" );
const def = @import( "defs" );

const entity = def.ntt.entity;

// ================ HELPER FUNCTIONS ================

pub fn clampInScreen( e1 : *entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping entity {d} on screen", .{ e1.id });

  const shw : f32 = def.getScreenWidth()  / 2;
  const shh : f32 = def.getScreenHeight() / 2;

  e1.clampInArea( def.Vec2{ .x = -shw, .y = -shh }, def.Vec2{ .x = shw,  .y = shh });
}

pub fn isOnScreen( e1 : *const entity ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if entity {d} is on screen", .{ e1.id });

  const shw : f32 = def.getScreenWidth()  / 2;
  const shh : f32 = def.getScreenHeight() / 2;

  return e1.isOnRange( def.Vec2{ .x = -shw, .y = -shh }, def.Vec2{ .x = shw,  .y = shh });
}


// ================ RENDER FUNCTIONS ================

pub fn renderEntity( self : *const entity ) void
{
  def.log( .TRACE, 0, @src(), "Rendering entity {d} at position {d}:{d} with shape {s}", .{ self.id, self.pos.x, self.pos.y, @tagName( self.shape ) });

  if( !self.active )
  {
    def.log( .TRACE, 0, @src(), "Entity {d} is inactive and will not be rendered", .{ self.id });
    return;
  }
  if( !isOnScreen( self ))
  {
    def.log( .TRACE, 0, @src(), "Entity {d} is out of range and will not be rendered", .{ self.id });
    return;
  }

  switch( self.shape )
  {
    .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added
    .TRIA => { def.drawTria( self.getCenter(), self.scale, self.getRot(), self.colour     ); },
    .STAR => { def.drawStar( self.getCenter(), self.scale, self.getRot(), self.colour     ); },
    .RECT => { def.drawRect( self.getCenter(), self.scale, self.getRot(), self.colour     ); },
    .DIAM => { def.drawDiam( self.getCenter(), self.scale, self.getRot(), self.colour     ); },
    .PENT => { def.drawPoly( self.getCenter(), self.scale, self.getRot(), self.colour, 5  ); },
    .HEXA => { def.drawPoly( self.getCenter(), self.scale, self.getRot(), self.colour, 6  ); },
    .OCTA => { def.drawPoly( self.getCenter(), self.scale, self.getRot(), self.colour, 8  ); },
    .DODE => { def.drawPoly( self.getCenter(), self.scale, self.getRot(), self.colour, 12 ); },
    .ELLI => { def.drawElli( self.getCenter(), self.scale, self.getRot(), self.colour     ); },
  }
}