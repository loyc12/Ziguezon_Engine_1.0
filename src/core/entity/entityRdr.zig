const std = @import( "std" );
const def = @import( "defs" );

const entity = def.ntt.entity;

// ================ RENDER FUNCTIONS ================

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
      def.ray.drawTriangle(
        .{ .x = self.pos.x,                .y = self.pos.y - self.scale.y }, // P0
        .{ .x = self.pos.x - self.scale.x, .y = self.pos.y + self.scale.y }, // P2
        .{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y }, // P1
        self.colour );
    },

    .RECT =>
    {
      def.ray.drawTriangle(
        .{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y }, // P0
        .{ .x = self.pos.x + self.scale.x, .y = self.pos.y - self.scale.y }, // P1
        .{ .x = self.pos.x - self.scale.x, .y = self.pos.y - self.scale.y }, // P2
        self.colour );

      def.ray.drawTriangle(
        .{ .x = self.pos.x - self.scale.x, .y = self.pos.y - self.scale.y }, // P2
        .{ .x = self.pos.x - self.scale.x, .y = self.pos.y + self.scale.y }, // P3
        .{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y }, // P0
        self.colour );
    },

    .DIAM =>
    {
      def.ray.drawTriangle(
        .{ .x = self.pos.x,                .y = self.pos.y - self.scale.y }, // P0
        .{ .x = self.pos.x - self.scale.x, .y = self.pos.y                }, // P1
        .{ .x = self.pos.x,                .y = self.pos.y + self.scale.y }, // P2
        self.colour );

      def.ray.drawTriangle(
        .{ .x = self.pos.x,                .y = self.pos.y + self.scale.y }, // P2
        .{ .x = self.pos.x + self.scale.x, .y = self.pos.y                }, // P3
        .{ .x = self.pos.x,                .y = self.pos.y - self.scale.y }, // P0
        self.colour );
    },

    .CIRC => // TODO : add ellipse support as well
    {
      def.ray.drawCircle(
        @intFromFloat( self.pos.x ),
        @intFromFloat( self.pos.y ),
        ( self.scale.x + self.scale.y ) / 2, // Use average of X and Y scale for radius
        self.colour );
    },

    .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added
  }
}