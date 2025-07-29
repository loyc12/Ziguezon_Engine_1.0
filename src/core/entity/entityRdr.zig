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

fn renderRelativeTri( self : *const entity, p0 : def.vec2, p1 : def.vec2, p2 : def.vec2 ) void
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

  switch( self.shape )
  {
    .TRIA =>
    {
      renderRelativeTri( self, //                    NOTE : scale.y is negative here because "up" is -y in rendering
        .{ .x = 0,                                              .y = -self.scale.y                                  }, // P0
        .{ .x = self.scale.x * @sin( 4.0 * std.math.pi / 3.0 ), .y = -self.scale.y * @cos( 4.0 * std.math.pi / 3.0 )}, // P1
        .{ .x = self.scale.x * @sin( 2.0 * std.math.pi / 3.0 ), .y = -self.scale.y * @cos( 2.0 * std.math.pi / 3.0 )}, // P2
      );
    },

    .RECT =>
    {
      renderRelativeQuad( self,
        .{ .x =  self.scale.x, .y =  self.scale.y }, // P0
        .{ .x =  self.scale.x, .y = -self.scale.y }, // P1
        .{ .x = -self.scale.x, .y = -self.scale.y }, // P2
        .{ .x = -self.scale.x, .y =  self.scale.y }, // P3
      );
    },

    .DIAM =>
    {
      renderRelativeQuad( self,
        .{ .x =  0,            .y = -self.scale.y }, // P0
        .{ .x = -self.scale.x, .y =  0            }, // P1
        .{ .x =  0,            .y =  self.scale.y }, // P2
        .{ .x =  self.scale.x, .y =  0            }, // P3
      );
    },

    .CIRC => // TODO : add reg polygon support and use that instead
    {
      def.ray.drawCircle(
        @intFromFloat( self.pos.x ),
        @intFromFloat( self.pos.y ),
        ( self.scale.x + self.scale.y ) / 2, // Use average of X and Y scale for radius
        self.colour );
    },

    .STAR => // aka : two overlaping but inverted triangles
    {
      renderRelativeTri( self,
        .{ .x = 0,                                              .y = -self.scale.y                                  }, // P0
        .{ .x = self.scale.x * @sin( 4.0 * std.math.pi / 3.0 ), .y = -self.scale.y * @cos( 4.0 * std.math.pi / 3.0 )}, // P1
        .{ .x = self.scale.x * @sin( 2.0 * std.math.pi / 3.0 ), .y = -self.scale.y * @cos( 2.0 * std.math.pi / 3.0 )}, // P2
      );
      renderRelativeTri( self,
        .{ .x = self.scale.x * @sin( std.math.pi ),           .y = -self.scale.y * @cos( std.math.pi )            }, // P0
        .{ .x = self.scale.x * @sin( 7 * std.math.pi / 3.0 ), .y = -self.scale.y * @cos( 7.0 * std.math.pi / 3.0 )}, // P1
        .{ .x = self.scale.x * @sin( 5 * std.math.pi / 3.0 ), .y = -self.scale.y * @cos( 5.0 * std.math.pi / 3.0 )}, // P2
      );
    },

    .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added
  }
}