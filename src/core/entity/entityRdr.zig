const std = @import( "std" );
const def = @import( "defs" );

const entity = def.ntt.entity;

// ================ HELPER FUNCTIONS ================

pub fn clampInScreen( e1 : *entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping entity {d} on screen", .{ e1.id });

  const sw : f32 = def.getScreenWidth();
  const sh : f32 = def.getScreenHeight();

  e1.clampInArea( def.Vec2{ .x = -sw / 2, .y = -sh / 2 }, def.Vec2{ .x = sw / 2,  .y = sh / 2 } );
}

pub fn isOnScreen( e1 : *const entity ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if entity {d} is on screen", .{ e1.id });

  const sw : f32 = def.getScreenWidth();
  const sh : f32 = def.getScreenHeight();

  return e1.isOnRange( def.Vec2{ .x = -sw / 2, .y = -sh / 2 }, def.Vec2{ .x = sw / 2,  .y = sh / 2 } );
}

fn renderRelativeTria( self : *const entity, p0 : def.Vec2, p1 : def.Vec2, p2 : def.Vec2 ) void
{
  const np0 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p0, self.rotPos ));
  const np1 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p1, self.rotPos ));
  const np2 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p2, self.rotPos ));

  def.ray.drawTriangle( np0, np1, np2, self.colour );
}

fn renderRelativeQuad( self : *const entity, p0 : def.Vec2, p1 : def.Vec2, p2 : def.Vec2, p3 : def.Vec2 ) void
{
  const np0 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p0, self.rotPos ));
  const np1 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p1, self.rotPos ));
  const np2 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p2, self.rotPos ));
  const np3 : def.Vec2 = def.addVec2( self.pos, def.rotVec2( p3, self.rotPos ));

  def.ray.drawTriangle( np0, np1, np2, self.colour );
  def.ray.drawTriangle( np2, np3, np0, self.colour );
}

fn renderRelativePoly( self : *const entity, points : []const def.Vec2 ) void
{
  if( points.len < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot render polygon with less than 3 points" );
    return;
  }

  // Initialize the first point to the last one, so that we can draw the first triangle
  var p0 = def.addVec2( self.pos, def.rotVec2( points[ points.len - 1 ], self.rotPos ));

  for( points[ 0.. ] )| point |
  {
    const p1 = def.addVec2( self.pos, def.rotVec2( point, self.rotPos ));
    def.ray.drawTriangle( p1, p0, self.pos, self.colour );
    p0 = p1;
  }
}

// ================ RENDER FUNCTIONS ================

// This function renders the entity to the screen.
pub fn renderEntity( self : *const entity ) void
{
  def.log( .TRACE, 0, @src(), "Rendering entity {d} at position {d}:{d} with shape {s}", .{ self.id, self.pos.x, self.pos.y, @tagName( self.shape ) });

  if( !self.active ) // Check if the entity is active
  {
    def.log( .TRACE, 0, @src(), "Entity {d} is inactive and will not be rendered", .{ self.id });
    return;
  }
  if( !isOnScreen( self )) // Check if the entity is on screen
  {
    // NOTE : This is a performance optimization to avoid rendering entities that are not on screen
    def.log( .TRACE, 0, @src(), "Entity {d} is out of range and will not be rendered", .{ self.id });
    return;
  }

  def.setTmpTimer();
  switch( self.shape )
  {
    .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added
    .TRIA => { def.drawTria( self.pos, self.scale, self.rotPos, self.colour     ); },
    .STAR => { def.drawStar( self.pos, self.scale, self.rotPos, self.colour     ); },
    .RECT => { def.drawRect( self.pos, self.scale, self.rotPos, self.colour     ); },
    .DIAM => { def.drawDiam( self.pos, self.scale, self.rotPos, self.colour     ); },
    .PENT => { def.drawPoly( self.pos, self.scale, self.rotPos, self.colour, 5  ); },
    .HEXA => { def.drawPoly( self.pos, self.scale, self.rotPos, self.colour, 6  ); },
    .OCTA => { def.drawPoly( self.pos, self.scale, self.rotPos, self.colour, 8  ); },
    .DODE => { def.drawPoly( self.pos, self.scale, self.rotPos, self.colour, 12 ); },
    .ELLI => { def.drawElli( self.pos, self.scale, self.rotPos, self.colour     ); },
  }
  def.logTmpTimer();
}