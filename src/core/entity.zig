const std  = @import( "std" );
const h    = @import( "../headers.zig" );


pub const e_shape = enum
{
  NONE, // No shape defined ( will not be rendered )
  TRIA, // Triangle ( isosceles, pointing up )
  RECT, // Square / Rectangle
  DIAM, // Square / Diamond ( rhombus )
  CIRC, // Circle / Ellipse
};

pub const entity = struct
{
  id     : u32,  // Unique identifier for the entity
  active : bool, // Whether the entity is active or not

  // ================ POSITION PROPERTIES ================

  pos : h.vec2, // Position of the entity in 2D space
//vel : h.vec2, // Velocity of the entity in 2D space
//acc : h.vec2, // Acceleration of the entity in 2D space

  // ================ ROTATION PROPERTIES ================

  rotPos : f16, // Rotation of the entity in radians
//rotVel : f16, // Angular velocity of the entity in radians per second
//rotAcc : f16, // Angular acceleration of the entity in radians per second squared

  // ================ SHAPE PROPERTIES ================

  shape  : e_shape,    // Shape of the entity
  scale  : h.vec2,     // Scale of the entity in X and Y
  colour : h.rl.Color, // Colour of the entity ( used for rendering )

  // ================ FUNCTIONS ================

  pub fn renderSelf( self : *const entity ) void
  {
    h.log( .DEBUG, 0, @src(), "Rendering entity {d} at position ({d}, {d}) with shape {s}", .{ self.id, self.pos.x, self.pos.y, @tagName( self.shape ) });

    switch( self.shape )
    {
      .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added

      .TRIA =>
      {
        h.rl.drawTriangle(
          .{ .x = self.pos.x,                .y = self.pos.y - self.scale.y }, // P0
          .{ .x = self.pos.x - self.scale.x, .y = self.pos.y + self.scale.y }, // P2
          .{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y }, // P1
          self.colour );
      },

      .RECT =>
      {
        h.rl.drawTriangle(
          .{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y }, // P0
          .{ .x = self.pos.x + self.scale.x, .y = self.pos.y - self.scale.y }, // P1
          .{ .x = self.pos.x - self.scale.x, .y = self.pos.y - self.scale.y }, // P2
          self.colour );

        h.rl.drawTriangle(
          .{ .x = self.pos.x - self.scale.x, .y = self.pos.y - self.scale.y }, // P2
          .{ .x = self.pos.x - self.scale.x, .y = self.pos.y + self.scale.y }, // P3
          .{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y }, // P0
          self.colour );
      },

      .DIAM =>
      {
        h.rl.drawTriangle(
          .{ .x = self.pos.x,                .y = self.pos.y - self.scale.y }, // P0
          .{ .x = self.pos.x - self.scale.x, .y = self.pos.y                }, // P1
          .{ .x = self.pos.x,                .y = self.pos.y + self.scale.y }, // P2
          self.colour );

        h.rl.drawTriangle(
          .{ .x = self.pos.x,                .y = self.pos.y + self.scale.y }, // P2
          .{ .x = self.pos.x + self.scale.x, .y = self.pos.y                }, // P3
          .{ .x = self.pos.x,                .y = self.pos.y - self.scale.y }, // P0
          self.colour );
      },

      .CIRC => // TODO : add ellipse support as well
      {
        h.rl.drawCircle(
          @intFromFloat( self.pos.x ),
          @intFromFloat( self.pos.y ),
          ( self.scale.x + self.scale.y ) / 2, // Use average of X and Y scale for radius
          self.colour );
      },
    }
  }

  // NOTE : Assumes that the entities are axis-aligned rectangles
  pub fn getOverlap( self : *const entity, other : *const entity ) ?h.vec2
  {
    h.log( .DEBUG, 0, @src(), "Checking overlap between entity {d} and entity {d}", .{ self.id, other.id });

    if( self.id == other.id ) // Check if the entities are the same
    {
      h.log( .DEBUG, 0, @src(), "Entities are the same : returning" );
      return null;
    }
    if( !self.active or !other.active ) // Check if either entity is inactive
    {
      h.log( .DEBUG, 0, @src(), "One of the entities is inactive : returning" );
      return null;
    }
    if( self.shape == .NONE or other.shape == .NONE ) // Check if either entity has no shape defined
    {
      h.log( .DEBUG, 0, @src(), "One of the entities has no shape defined : returning" );
      return null;
    }
    if( self.pos == other.pos ) // Check if the entities are at the same position
    {
      h.log( .DEBUG, 0, @src(), "Entities are at the same position : returning" );
      return h.vec2{ .x = 0, .y = 0 }; // No overlap direction possible
    }

    // Find the directions of the overlap ( relative to self )
    const dist = h.vec2{ .x = other.pos.x - self.pos.x, .y = other.pos.y - self.pos.y };
    const dir  = h.vec2{ .x = if( dist.x > 0 ) 1 else if ( dist.x < 0 ) -1 else 0,
                         .y = if( dist.y > 0 ) 1 else if ( dist.y < 0 ) -1 else 0 };

    // Find the edges of each entities bounding box
    // NOTE : This assumes that the entities are axis-aligned rectangles // TODO : Add support for other shapes
    const selfEdge = h.vec2{
      .x = self.pos.x + ( dir.x * self.scale.x ),
      .y = self.pos.y + ( dir.y * self.scale.y )};

    const otherEdge = h.vec2{
      .x = other.pos.x - ( dir.x * other.scale.x ),
      .y = other.pos.y - ( dir.y * other.scale.y )};

    // Check for lack of overlap in either axis, based on respective directions
    if( dir.x > 0 and selfEdge.x < otherEdge.x or
        dir.x < 0 and selfEdge.x > otherEdge.x )
    {
      h.log( .DEBUG, 0, @src(), "No overlap detected in X direction : returning" );
      return null;
    }
    if( dir.y > 0 and selfEdge.y < otherEdge.y or
        dir.y < 0 and selfEdge.y > otherEdge.y )
    {
      h.log( .DEBUG, 0, @src(), "No overlap detected in Y direction : returning" );
      return null;
    }

    // If we reach here, there is an overlap in both axes
    // Find the overlap vector ( the magniture of the overlap in each axis )
    const overlap = h.vec2{
      .x = if(      dir.x > 0 ) selfEdge.x  - otherEdge.x
           else if( dir.x < 0 ) otherEdge.x - selfEdge.x
           else 0,
      .y = if(      dir.y > 0 ) selfEdge.y  - otherEdge.y
           else if( dir.y < 0 ) otherEdge.y - selfEdge.y
           else 0,
    };

    h.log( .DEBUG, 0, @src(), "Overlap of magniture {d}:{d} detected", .{ overlap.x, overlap.y });
    return overlap;
  }
};



