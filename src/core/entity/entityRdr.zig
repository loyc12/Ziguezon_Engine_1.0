const std = @import( "std" );
const def = @import( "defs" );

const entity = def.ntt.entity;

// ================ HELPER FUNCTIONS ================

pub fn clampInScreen( e1 : *entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping entity {d} on screen", .{ e1.id });

  const sw : f32 = def.getScreenWidth();
  const sh : f32 = def.getScreenHeight();

  e1.clampInArea( def.vec2{ .x = -sw / 2, .y = -sh / 2 }, def.vec2{ .x = sw / 2,  .y = sh / 2 } );
}

pub fn isOnScreen( e1 : *const entity ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if entity {d} is on screen", .{ e1.id });

  const sw : f32 = def.getScreenWidth();
  const sh : f32 = def.getScreenHeight();

  return e1.isOnRange( def.vec2{ .x = -sw / 2, .y = -sh / 2 }, def.vec2{ .x = sw / 2,  .y = sh / 2 } );
}

fn renderRelativeTria( self : *const entity, p0 : def.vec2, p1 : def.vec2, p2 : def.vec2 ) void
{
  const np0 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p0, self.rotPos ));
  const np1 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p1, self.rotPos ));
  const np2 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p2, self.rotPos ));

  def.ray.drawTriangle( np0, np1, np2, self.colour );
}

fn renderRelativeQuad( self : *const entity, p0 : def.vec2, p1 : def.vec2, p2 : def.vec2, p3 : def.vec2 ) void
{
  const np0 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p0, self.rotPos ));
  const np1 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p1, self.rotPos ));
  const np2 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p2, self.rotPos ));
  const np3 : def.vec2 = def.addVec2( self.pos, def.rotVec2Rad( p3, self.rotPos ));

  def.ray.drawTriangle( np0, np1, np2, self.colour );
  def.ray.drawTriangle( np2, np3, np0, self.colour );
}

fn renderRelativePoly( self : *const entity, points : []const def.vec2 ) void
{
  if( points.len < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "Cannot render polygon with less than 3 points" );
    return;
  }

  // Initialize the first point to the last one, so that we can draw the first triangle
  var p0 = def.addVec2( self.pos, def.rotVec2Rad( points[ points.len - 1 ], self.rotPos ));

  for( points[ 0.. ] )| point |
  {
    const p1 = def.addVec2( self.pos, def.rotVec2Rad( point, self.rotPos ));
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

  var sideCount : u32 = 0;

  switch( self.shape )
  {
    .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added
    .TRIA =>
    {
      sideCount = 3; // Triangle has 3 sides
      renderRelativeTria( self,
        def.getScaledVec2FromDeg( self.scale, 0.0   ), // P0
        def.getScaledVec2FromDeg( self.scale, 240.0 ), // P1
        def.getScaledVec2FromDeg( self.scale, 120.0 ), // P2
      );
    },
    .STAR => // aka : two overlaping but inverted triangles
    {
      sideCount = 6;
      renderRelativeTria( self,
        def.getScaledVec2FromDeg( self.scale, 0.0   ), // P0
        def.getScaledVec2FromDeg( self.scale, 240.0 ), // P1
        def.getScaledVec2FromDeg( self.scale, 120.0 ), // P2
      );
      renderRelativeTria( self,
        def.getScaledVec2FromDeg( self.scale, 180.0 ), // P0
        def.getScaledVec2FromDeg( self.scale, 60.0  ), // P1
        def.getScaledVec2FromDeg( self.scale, 300.0 ), // P2
      );
    },
    .RECT =>
    {
      sideCount = 4;
      renderRelativeQuad( self,
        .{ .x =  self.scale.x, .y =  self.scale.y }, // P0
        .{ .x =  self.scale.x, .y = -self.scale.y }, // P1
        .{ .x = -self.scale.x, .y = -self.scale.y }, // P2
        .{ .x = -self.scale.x, .y =  self.scale.y }, // P3
      );
    },
    .DIAM =>
    {
      sideCount = 4;
      renderRelativeQuad( self,
        .{ .x =  0, .y = -self.scale.y }, // P0
        .{ .x = -self.scale.x, .y =  0 }, // P1
        .{ .x =  0, .y =  self.scale.y }, // P2
        .{ .x =  self.scale.x, .y =  0 }, // P3
      );
    },
    .PENT => { sideCount = 5;  },
    .HEXA => { sideCount = 6;  },
    .OCTA => { sideCount = 8;  },
    .DODE => { sideCount = 12; },
    .CIRC => { sideCount = 24; }, // Pretending a circle is a regular polygon
  }

  if( sideCount >= 5 )
  {
    if( def.getScaledPolyVerts( self.scale, sideCount )) | points |
    {
      renderRelativePoly( self, points );
      def.alloc.free( points );
    }
    else{ def.log( .ERROR, 0, @src(), "Failed to get polygon vertexs for entity {d} with shape {s}", .{ self.id, @tagName( self.shape ) }); }
  }
}