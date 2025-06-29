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
  vel : h.vec2, // Velocity of the entity in 2D space
  acc : h.vec2, // Acceleration of the entity in 2D space

  // ================ ROTATION PROPERTIES ================

  rotPos : f16, // Rotation of the entity in radians
//rotVel : f16, // Angular velocity of the entity in radians per second
//rotAcc : f16, // Angular acceleration of the entity in radians per second squared

  // ================ SHAPE PROPERTIES ================

  shape  : e_shape,    // Shape of the entity
  scale  : h.vec2,     // Scale of the entity in X and Y
  colour : h.rl.Color, // Colour of the entity ( used for rendering )

  // ================ DISTANCE FUNCTIONS ================
  // These functions calculate the distance between two entities in various ways.

  pub fn getXDistTo( self : *const entity, other : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating X distance between entity {d} and {d}", .{ self.id, other.id });
    return @abs( other.pos.x - self.pos.x );
  }
  pub fn getYDistTo( self : *const entity, other : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating Y distance between entity {d} and {d}", .{ self.id, other.id });
    return @abs( other.pos.y - self.pos.y );
  }
  pub fn getSqrDistTo( self : *const entity, other : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating squared distance between entity {d} and {d}", .{ self.id, other.id });
    const dist = h.vec2{ .x = other.pos.x - self.pos.x, .y = other.pos.y - self.pos.y, };
    return ( dist.x * dist.x ) + ( dist.y * dist.y );
  }
  pub fn getDistTo( self : *const entity, other : *const entity ) f32
  {
    return @sqrt( self.getDistSqrTo( other ) );
  }
  pub fn getCartDistTo( self : *const entity, other : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating cartesian distance between entity {d} and {d}", .{ self.id, other.id });
    return @abs( other.pos.x - self.pos.x ) + @abs( other.pos.y - self.pos.y ); // NOTE : taxicab distance
  }

  // ================ POSITION FUNCTIONS ================
  // These functions calculate the sides of the entity's bounding box based on its position and scale.
  // These assume that the entity is an axis-aligned rectangle, meaning that its sides are parallel to the X and Y axes.
  // The sides are defined as follows:
  // TOP    = -Y   // LEFT   = -X
  // BOTTOM = +Y   // RIGHT  = +X

  // These functions return the sides of the entity's bounding box.
  pub fn getLeftSide( self : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating left side of entity {d}", .{ self.id });
    return self.pos.x - self.scale.x;
  }
  pub fn getRightSide( self : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating right side of entity {d}", .{ self.id });
    return self.pos.x + self.scale.x;
  }
  pub fn getTopSide( self : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating top side of entity {d}", .{ self.id });
    return self.pos.y - self.scale.y;
  }
  pub fn getBottomSide( self : *const entity ) f32
  {
    h.log( .TRACE, 0, @src(), "Calculating bottom side of entity {d}", .{ self.id });
    return self.pos.y + self.scale.y;
  }

  // These functions set the sides of the entity's bounding box.
  pub fn setLeftSide( self : *entity, newLeftSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting left side of entity {d} to {d}", .{ self.id, newLeftSide });
    self.pos.x = newLeftSide + self.scale.x;
  }
  pub fn setRightSide( self : *entity, newRightSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting right side of entity {d} to {d}", .{ self.id, newRightSide });
    self.pos.x = newRightSide - self.scale.x;
  }
  pub fn setTopSide( self : *entity, newTopSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting top side of entity {d} to {d}", .{ self.id, newTopSide });
    self.pos.y = newTopSide + self.scale.y;
  }
  pub fn setBottomSide( self : *entity, newBottomSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting bottom side of entity {d} to {d}", .{ self.id, newBottomSide });
    self.pos.y = newBottomSide - self.scale.y;
  }

  // These functions return the corners of the entity's bounding box.
  pub fn getTopLeft( self : *const entity ) h.vec2
  {
    h.log( .TRACE, 0, @src(), "Calculating top left corner of entity {d}", .{ self.id });
    return h.vec2{ .x = self.pos.x - self.scale.x, .y = self.pos.y - self.scale.y };
  }
  pub fn getTopRight( self : *const entity ) h.vec2
  {
    h.log( .TRACE, 0, @src(), "Calculating top right corner of entity {d}", .{ self.id });
    return h.vec2{ .x = self.pos.x + self.scale.x, .y = self.pos.y - self.scale.y };
  }
  pub fn getBottomLeft( self : *const entity ) h.vec2
  {
    h.log( .TRACE, 0, @src(), "Calculating bottom left corner of entity {d}", .{ self.id });
    return h.vec2{ .x = self.pos.x - self.scale.x, .y = self.pos.y + self.scale.y };
  }
  pub fn getBottomRight( self : *const entity ) h.vec2
  {
    h.log( .TRACE, 0, @src(), "Calculating bottom right corner of entity {d}", .{ self.id });
    return h.vec2{ .x = self.pos.x + self.scale.x, .y = self.pos.y + self.scale.y };
  }

  // These functions set the corners of the entity's bounding box.
  pub fn setTopLeft( self : *entity, newTopLeft : h.vec2 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting top left corner of entity {d} to {d}:{d}", .{ self.id, newTopLeft.x, newTopLeft.y });
    self.pos.x = newTopLeft.x + self.scale.x;
    self.pos.y = newTopLeft.y + self.scale.y;
  }
  pub fn setTopRight( self : *entity, newTopRight : h.vec2 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting top right corner of entity {d} to {d}:{d}", .{ self.id, newTopRight.x, newTopRight.y });
    self.pos.x = newTopRight.x - self.scale.x;
    self.pos.y = newTopRight.y + self.scale.y;
  }
  pub fn setBottomLeft( self : *entity, newBottomLeft : h.vec2 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting bottom left corner of entity {d} to {d}:{d}", .{ self.id, newBottomLeft.x, newBottomLeft.y });
    self.pos.x = newBottomLeft.x + self.scale.x;
    self.pos.y = newBottomLeft.y - self.scale.y;
  }
  pub fn setBottomRight( self : *entity, newBottomRight : h.vec2 ) void
  {
    h.log( .TRACE, 0, @src(), "Setting bottom right corner of entity {d} to {d}:{d}", .{ self.id, newBottomRight.x, newBottomRight.y });
    self.pos.x = newBottomRight.x - self.scale.x;
    self.pos.y = newBottomRight.y - self.scale.y;
  }

  // ================ CLAMPING FUNCTIONS ================
  // These functions clamp the entity's position to a given range, preventing it from going out of bounds.
  // They also set the velocity to 0 if the entity was moving in the direction of the clamped side.

  // These functions clamp the entity's sides to a given range, preventing it from going out of bounds in that direction.
  pub fn clampLeftSide( self : *entity, minLeftSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping left side of entity {d} to {d}", .{ self.id, minLeftSide });
    if( self.getLeftSide() < minLeftSide )
    {
      self.setLeftSide( minLeftSide );
      if ( self.vel.x < 0 ){ self.vel.x = 0; }
    }
  }
  pub fn clampRightSide( self : *entity, maxRightSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping right side of entity {d} to {d}", .{ self.id, maxRightSide });
    if( self.getRightSide() > maxRightSide )
    {
      self.setRightSide( maxRightSide );
      if ( self.vel.x > 0 ){ self.vel.x = 0; }
    }
  }
  pub fn clampTopSide( self : *entity, minTopSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping top side of entity {d} to {d}", .{ self.id, minTopSide });
    if( self.getTopSide() < minTopSide )
    {
      self.setTopSide( minTopSide );
      if ( self.vel.y < 0 ){ self.vel.y = 0; }
    }
  }
  pub fn clampBottomSide( self : *entity, maxBottomSide : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping bottom side of entity {d} to {d}", .{ self.id, maxBottomSide });
    if( self.getBottomSide() > maxBottomSide )
    {
      self.setBottomSide( maxBottomSide );
      if ( self.vel.y > 0 ){ self.vel.y = 0; }
    }
  }

  // These functions clamp the entity's position to a given range on the X and Y axes.
  pub fn clampInX( self : *entity, minX : f32, maxX : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping entity {d} on X axis to range {d}:{d}", .{ self.id, minX, maxX });
    self.clampLeftSide(  minX );
    self.clampRightSide( maxX );
  }
  pub fn clampInY( self : *entity, minY : f32, maxY : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping entity {d} on Y axis to range {d}:{d}", .{ self.id, minY, maxY });
    self.clampTopSide(    minY );
    self.clampBottomSide( maxY );
  }

  // This function clamps the entity's position to a given area defined by min and max coordinates.
  pub fn clampInArea( self : *entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping entity {d} in area {d}:{d} to {d}:{d}", .{ self.id, minX, maxX, minY, maxY });
    self.clampInX( minX, maxX );
    self.clampInY( minY, maxY );
  }
  pub fn clampOnScreen( self : *entity ) void
  {
    h.log( .TRACE, 0, @src(), "Clamping entity {d} on screen", .{ self.id });
    const sw : f32 = h.getScreenWidth();
    const sh : f32 = h.getScreenHeight();
    self.clampInArea( -sw / 2, sw / 2, -sh / 2, sh / 2 );
  }

  // ================ RANGE FUNCTIONS ================
  // These functions check if the entity is entirely or partially within a given range.

  // An entity is considered to be in range if its bounding box is entirely within the range.
  pub fn isInRangeX( self : *const entity, minX : f32, maxX : f32 ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is in range X:{d}:{d}", .{ self.id, minX, maxX });
    return( self.getLeftSide() >= minX and self.getRightSide() <= maxX );
  }
  pub fn isInRangeY( self : *const entity, minY : f32, maxY : f32 ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is in range Y:{d}:{d}", .{ self.id, minY, maxY });
    return( self.getTopSide() >= minY and self.getBottomSide() <= maxY );
  }
  pub fn isInRange( self : *const entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is in range {d}:{d} to {d}:{d}", .{ self.id, minX, maxX, minY, maxY });
    return(( self.isInRangeX( minX, maxX ) and self.isInRangeY( minY, maxY )));
  }

  // An entity is considered to be on range if its bounding box overlaps with the range.
  pub fn isOnRangeX( self : *const entity, minX : f32, maxX : f32 ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is on range X:{d}:{d}", .{ self.id, minX, maxX });
    return( self.getRightSide() >= minX and self.getLeftSide() <= maxX );
  }
  pub fn isOnRangeY( self : *const entity, minY : f32, maxY : f32 ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is on range Y:{d}:{d}", .{ self.id, minY, maxY });
    return( self.getBottomSide() >= minY and self.getTopSide() <= maxY );
  }
  pub fn isOnRange( self : *const entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is on range {d}:{d} to {d}:{d}", .{ self.id, minX, maxX, minY, maxY });
    return(( self.isOnRangeX( minX, maxX ) and self.isOnRangeY( minY, maxY )));
  }
  pub fn isOnScreen( self : *const entity ) bool
  {
    h.log( .TRACE, 0, @src(), "Checking if entity {d} is on screen", .{ self.id });
    const sw : f32 = h.getScreenWidth();
    const sh : f32 = h.getScreenHeight();
    return self.isOnRange( -sw / 2, sw / 2, -sh / 2, sh / 2 );
  }

  // ================ CORE FUNCTIONS ================

  // This function renders the entity to the screen.
  pub fn renderSelf( self : *const entity ) void
  {
    h.log( .TRACE, 0, @src(), "Rendering entity {d} at position {d}:{d} with shape {s}", .{ self.id, self.pos.x, self.pos.y, @tagName( self.shape ) });

    if( !self.active ) // Check if the entity is active
    {
      h.log( .DEBUG, 0, @src(), "Entity {d} is inactive and will not be rendered", .{ self.id });
      return;
    }
    if( !isOnScreen( self )) // Check if the entity is on screen
    {
      // NOTE : This is a performance optimization to avoid rendering entities that are not on screen
      h.log( .TRACE, 0, @src(), "Entity {d} is out of range and will not be rendered", .{ self.id });
      return;
    }

    h.OnEntityRender( self ); // Call the entity render injector

    switch( self.shape )
    {
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

      .NONE => {}, // NOTE : Not using else, so that the compiler warns if a new shape type is added
    }
  }

  // This function checks if the entity overlaps with another entity and returns the overlap vector if they do.
  // The overlap vector is the magnitude of the overlap in each axis, relative to the first entity.
  // NOTE : This function assumes that the entities are axis-aligned rectangles
  pub fn getOverlap( self : *const entity, other : *const entity ) ?h.vec2
  {
    h.log( .TRACE, 0, @src(), "Checking overlap between entity {d} and {d}", .{ self.id, other.id });

    if( self.id == other.id ) // Check if the entities are the same
    {
      h.qlog( .DEBUG, 0, @src(), "Entities are the same : returning" );
      return null;
    }
    if( !self.active or !other.active ) // Check if either entity is inactive
    {
      h.qlog( .DEBUG, 0, @src(), "One of the entities is inactive : returning" );
      return null;
    }
    if( self.shape == .NONE or other.shape == .NONE ) // Check if either entity has no shape defined
    {
      h.qlog( .DEBUG, 0, @src(), "One of the entities has no shape defined : returning" );
      return null;
    }
    if( self.pos.x == other.pos.x and self.pos.y == other.pos.y ) // Check if the entities are at the same position
    {
      h.qlog( .TRACE, 0, @src(), "Entities are at the same position : returning" );
      return h.vec2{ .x = 0, .y = 0 }; // No overlap direction possible
    }
    // Check if the entities are too far apart to overlap

    if( self.scale.x + self.scale.y + other.scale.x + other.scale.y < self.getCartDistTo( other ) )
    {
      h.qlog( .TRACE, 0, @src(), "Entities are too far apart to possibly overlap : returning" );
      return null;
    }

    // Find the directions of the overlap ( relative to self )
    const offset = h.vec2{ .x = other.pos.x - self.pos.x, .y = other.pos.y - self.pos.y };
    const dir  = h.vec2{ .x = if( offset.x > 0 ) 1 else if ( offset.x < 0 ) -1 else 0,
                         .y = if( offset.y > 0 ) 1 else if ( offset.y < 0 ) -1 else 0 };

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
      h.qlog( .DEBUG, 0, @src(), "No overlap detected in X direction : returning" );
      return null;
    }
    if( dir.y > 0 and selfEdge.y < otherEdge.y or
        dir.y < 0 and selfEdge.y > otherEdge.y )
    {
      h.qlog( .DEBUG, 0, @src(), "No overlap detected in Y direction : returning" );
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
           else 0, };

    h.log( .DEBUG, 0, @src(), "Overlap of magniture {d}:{d} detected", .{ overlap.x, overlap.y });
    return overlap;
  }
};



