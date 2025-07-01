const std     = @import( "std" );
const h       = @import( "../../headers.zig" );

const entity  = @import( "entityCore.zig" ).entity;

// ================ DISTANCE FUNCTIONS ================
// These functions calculate the distance between two entities in various ways.

pub fn getXDistTo( e1 : *const entity, e2 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating X distance between entity {d} and {d}", .{ e1.id, e2.id });
  return @abs( e2.pos.x - e1.pos.x );
}
pub fn getYDistTo( e1 : *const entity, e2 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating Y distance between entity {d} and {d}", .{ e1.id, e2.id });
  return @abs( e2.pos.y - e1.pos.y );
}
pub fn getSqrDistTo( e1 : *const entity, e2 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating squared distance between entity {d} and {d}", .{ e1.id, e2.id });
  const dist = h.vec2{ .x = e2.pos.x - e1.pos.x, .y = e2.pos.y - e1.pos.y, };
  return ( dist.x * dist.x ) + ( dist.y * dist.y );
}
pub fn getDistTo( e1 : *const entity, e2 : *const entity ) f32
{
  return @sqrt( getSqrDistTo( e1, e2 ) );
}
pub fn getCartDistTo( e1 : *const entity, e2 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating cartesian distance between entity {d} and {d}", .{ e1.id, e2.id });
  return @abs( e2.pos.x - e1.pos.x ) + @abs( e2.pos.y - e1.pos.y ); // NOTE : taxicab distance
}

// ================ POSITION ACCESSORS ================
// These functions calculate the sides of the entity's bounding box based on its position and scale.
// These assume that the entity is an axis-aligned rectangle, meaning that its sides are parallel to the X and Y axes.
// The sides are defined as follows:
// TOP    = -Y   // LEFT   = -X
// BOTTOM = +Y   // RIGHT  = +X

// These functions return the sides of the entity's bounding box.
pub fn getLeftX( e1 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating left side of entity {d}", .{ e1.id });
  return e1.pos.x - e1.scale.x;
}
pub fn getRightX( e1 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating right side of entity {d}", .{ e1.id });
  return e1.pos.x + e1.scale.x;
}
pub fn getTopY( e1 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating top side of entity {d}", .{ e1.id });
  return e1.pos.y - e1.scale.y;
}
pub fn getBottomY( e1 : *const entity ) f32
{
  h.log( .TRACE, 0, @src(), "Calculating bottom side of entity {d}", .{ e1.id });
  return e1.pos.y + e1.scale.y;
}

// These functions return the corners of the entity's bounding box.
pub fn getTopLeft( e1 : *const entity ) h.vec2
{
  h.log( .TRACE, 0, @src(), "Calculating top left corner of entity {d}", .{ e1.id });
  return h.vec2{ .x = e1.pos.x - e1.scale.x, .y = e1.pos.y - e1.scale.y };
}
pub fn getTopRight( e1 : *const entity ) h.vec2
{
  h.log( .TRACE, 0, @src(), "Calculating top right corner of entity {d}", .{ e1.id });
  return h.vec2{ .x = e1.pos.x + e1.scale.x, .y = e1.pos.y - e1.scale.y };
}
pub fn getBottomLeft( e1 : *const entity ) h.vec2
{
  h.log( .TRACE, 0, @src(), "Calculating bottom left corner of entity {d}", .{ e1.id });
  return h.vec2{ .x = e1.pos.x - e1.scale.x, .y = e1.pos.y + e1.scale.y };
}
pub fn getBottomRight( e1 : *const entity ) h.vec2
{
  h.log( .TRACE, 0, @src(), "Calculating bottom right corner of entity {d}", .{ e1.id });
  return h.vec2{ .x = e1.pos.x + e1.scale.x, .y = e1.pos.y + e1.scale.y };
}

// ================ POSITION SETTERS ================
// These functions set the sides of the entity's bounding box.

pub fn setLeftX( e1 : *entity, leftX : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Setting left side of entity {d} to {d}", .{ e1.id, leftX });
  e1.pos.x = leftX + e1.scale.x;
}
pub fn setRightX( e1 : *entity, rightX : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Setting right side of entity {d} to {d}", .{ e1.id, rightX });
  e1.pos.x = rightX - e1.scale.x;
}
pub fn setTopY( e1 : *entity, topY : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Setting top side of entity {d} to {d}", .{ e1.id, topY });
  e1.pos.y = topY + e1.scale.y;
}
pub fn setBottomY( e1 : *entity, bottomY : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Setting bottom side of entity {d} to {d}", .{ e1.id, bottomY });
  e1.pos.y = bottomY - e1.scale.y;
}

// These functions set the corners of the entity's bounding box.
pub fn setTopLeft( e1 : *entity, topLeftPos : h.vec2 ) void
{
  h.log( .TRACE, 0, @src(), "Setting top left corner of entity {d} to {d}:{d}", .{ e1.id, topLeftPos.x, topLeftPos.y });
  e1.pos.x = topLeftPos.x + e1.scale.x;
  e1.pos.y = topLeftPos.y + e1.scale.y;
}
pub fn setTopRight( e1 : *entity, topRightPos : h.vec2 ) void
{
  h.log( .TRACE, 0, @src(), "Setting top right corner of entity {d} to {d}:{d}", .{ e1.id, topRightPos.x, topRightPos.y });
  e1.pos.x = topRightPos.x - e1.scale.x;
  e1.pos.y = topRightPos.y + e1.scale.y;
}
pub fn setBottomLeft( e1 : *entity, bottomLeftPos : h.vec2 ) void
{
  h.log( .TRACE, 0, @src(), "Setting bottom left corner of entity {d} to {d}:{d}", .{ e1.id, bottomLeftPos.x, bottomLeftPos.y });
  e1.pos.x = bottomLeftPos.x + e1.scale.x;
  e1.pos.y = bottomLeftPos.y - e1.scale.y;
}
pub fn setBottomRight( e1 : *entity, bottomRightPos : h.vec2 ) void
{
  h.log( .TRACE, 0, @src(), "Setting bottom right corner of entity {d} to {d}:{d}", .{ e1.id, bottomRightPos.x, bottomRightPos.y });
  e1.pos.x = bottomRightPos.x - e1.scale.x;
  e1.pos.y = bottomRightPos.y - e1.scale.y;
}

// ================ CLAMPING FUNCTIONS ================
// These functions clamp the entity's position to a given range, preventing it from going out of bounds.
// They also set the velocity to 0 if the entity was moving in the direction of the clamped side.

// These functions clamp the entity's sides to a given range, preventing it from going out of bounds in that direction.
pub fn clampLeftX( e1 : *entity, minLeftX : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping left side of entity {d} to {d}", .{ e1.id, minLeftX });
  if( getLeftX( e1 ) < minLeftX )
  {
    setLeftX( e1, minLeftX );
    if ( e1.vel.x < 0 ){ e1.vel.x = 0; }
  }
}
pub fn clampRightX( e1 : *entity, maxRightX : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping right side of entity {d} to {d}", .{ e1.id, maxRightX });
  if( getRightX( e1 ) > maxRightX )
  {
    setRightX( e1, maxRightX );
    if ( e1.vel.x > 0 ){ e1.vel.x = 0; }
  }
}
pub fn clampTopY( e1 : *entity, minTopY : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping top side of entity {d} to {d}", .{ e1.id, minTopY });
  if( getTopY( e1 ) < minTopY )
  {
    setTopY( e1, minTopY );
    if ( e1.vel.y < 0 ){ e1.vel.y = 0; }
  }
}
pub fn clampBottomY( e1 : *entity, maxBottomY : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping bottom side of entity {d} to {d}", .{ e1.id, maxBottomY });
  if( getBottomY( e1 ) > maxBottomY )
  {
    setBottomY( e1, maxBottomY );
    if ( e1.vel.y > 0 ){ e1.vel.y = 0; }
  }
}

// These functions clamp the entity's hitbox in a given range on the X and Y axes.
pub fn clampInX( e1 : *entity, minX : f32, maxX : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping entity {d} on X axis to range {d}:{d}", .{ e1.id, minX, maxX });
  clampLeftX(  e1, minX );
  clampRightX(  e1,maxX );
}
pub fn clampInY( e1 : *entity, minY : f32, maxY : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping entity {d} on Y axis to range {d}:{d}", .{ e1.id, minY, maxY });
  clampTopY(    e1, minY );
  clampBottomY( e1, maxY );
}
pub fn clampInArea( e1 : *entity, minPos : h.vec2, maxPos : h.vec2 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping entity {d} in area {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  clampInX( e1, minPos.x, maxPos.x );
  clampInY( e1, minPos.y, maxPos.y );
}

// These functions clamp the entity's hitbox on a given range on the X axis ( can overlap only partially ).
pub fn clampOnX( e1 : *entity, minX : f32, maxX : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping entity {d} on X axis to range {d}:{d}", .{ e1.id, minX, maxX });
  clampLeftX(  e1, minX - ( 2 * e1.scale.x ));
  clampRightX( e1, maxX + ( 2 * e1.scale.x ));
}
pub fn clampOnY( e1 : *entity, minY : f32, maxY : f32 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping entity {d} on Y axis to range {d}:{d}", .{ e1.id, minY, maxY });
  clampTopY(    e1, minY - ( 2 * e1.scale.y ));
  clampBottomY( e1, maxY + ( 2 * e1.scale.y ));
}
pub fn clampOnArea( e1 : *entity, minPos : h.vec2, maxPos : h.vec2 ) void
{
  h.log( .TRACE, 0, @src(), "Clamping entity {d} in area {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  clampOnX( e1, minPos.x, maxPos.x );
  clampOnY( e1, minPos.y, maxPos.y );
}

// ================ RANGE FUNCTIONS ================
// These functions check if the entity is entirely or partially within a given range.

// An entity is considered to be in range if its bounding box is entirely within the range.
pub fn isInRangeX( e1 : *const entity, minX : f32, maxX : f32 ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} is in range X:{d}:{d}", .{ e1.id, minX, maxX });
  return( getLeftX( e1 ) >= minX and getRightX( e1 ) <= maxX );
}
pub fn isInRangeY( e1 : *const entity, minY : f32, maxY : f32 ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} is in range Y:{d}:{d}", .{ e1.id, minY, maxY });
  return( .getTopY( e1 ) >= minY and getBottomY( e1 ) <= maxY );
}
pub fn isInRange( e1 : *const entity, minPos : h.vec2, maxPos : h.vec2 ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} is in range {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  return(( isInRangeX( e1, minPos.x, maxPos.x ) and isInRangeY( e1, minPos.y, maxPos.y )));
}

// An entity is considered to be on e1, range if its bounding box overlaps with the range.
pub fn isOnRangeX( e1 : *const entity, minX : f32, maxX : f32 ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} is on range X:{d}:{d}", .{ e1.id, minX, maxX });
  return( getRightX( e1 ) >= minX and getLeftX( e1 ) <= maxX );
}
pub fn isOnRangeY( e1 : *const entity, minY : f32, maxY : f32 ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} is on range Y:{d}:{d}", .{ e1.id, minY, maxY });
  return( getBottomY( e1) >= minY and getTopY( e1 ) <= maxY );
}
pub fn isOnRange( e1 : *const entity, minPos : h.vec2, maxPos : h.vec2 ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} is on range {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  return(( isOnRangeX( e1, minPos.x, maxPos.x ) and isOnRangeY( e1, minPos.y, maxPos.y )));
}

// ================ COLLISION FUNCTIONS ================

pub fn isOverlapping( e1 : *const entity, e2 : *const entity ) bool
{
  h.log( .TRACE, 0, @src(), "Checking if entity {d} overlaps with {d}", .{ e1.id, e2.id });

  // Check if either entity has no shape defined
  if( e1.shape == .NONE or e2.shape == .NONE )
  {
    h.qlog( .DEBUG, 0, @src(), "One of the entities has no shape defined : returning" );
    return false;
  }

  // Check for overlap
  const linearDists = h.vec2{ .x = @abs( e2.pos.x - e1.pos.x ), .y = @abs( e2.pos.y - e1.pos.y )};
  if( linearDists.x > ( e1.scale.x + e2.scale.x ) or linearDists.y > ( e1.scale.y + e2.scale.y ))
  {
    return false; // No overlap in at least one axis
  }

  h.qlog( .TRACE, 0, @src(), "Entities are overlapping : returning" );
  return true; // Overlap detected in both axes
}

// This function checks if the entity overlaps with another entity and returns the overlap vector if they do.
// The overlap vector is the magnitude of the overlap in each axis, relative to the first entity.
// NOTE : This function assumes that the entities are axis-aligned rectangles
// NOTE : Use isOverlapping() if you simply want to check for collision without needing the overlap vector.
pub fn getOverlap( e1 : *const entity, e2 : *const entity ) ?h.vec2
{
  h.log( .TRACE, 0, @src(), "Checking overlap between entity {d} and {d}", .{ e1.id, e2.id });

  if( e1.id == e2.id ) // Check if the entities are the same
  {
    h.qlog( .DEBUG, 0, @src(), "Entities are the same : returning" );
    return null;
  }
  if( !e1.active or !e2.active ) // Check if either entity is inactive
  {
    h.qlog( .DEBUG, 0, @src(), "One of the entities is inactive : returning" );
    return null;
  }
  if( e1.shape == .NONE or e2.shape == .NONE ) // Check if either entity has no shape defined
  {
    h.qlog( .DEBUG, 0, @src(), "One of the entities has no shape defined : returning" );
    return null;
  }
  if( e1.pos.x == e2.pos.x and e1.pos.y == e2.pos.y ) // Check if the entities are at the same position
  {
    h.qlog( .TRACE, 0, @src(), "Entities are at the same position : returning" );
    return h.vec2{ .x = 0, .y = 0 }; // No overlap direction possible
  }
  // Check if the entities are too far apart to overlap

  if( e1.scale.x + e1.scale.y + e2.scale.x + e2.scale.y < getCartDistTo( e1, e2 ) )
  {
    h.qlog( .TRACE, 0, @src(), "Entities are too far apart to possibly overlap : returning" );
    return null;
  }

  // Find the directions of the overlap ( relative to e1 )
  const offset = h.vec2{ .x = e2.pos.x - e1.pos.x, .y = e2.pos.y - e1.pos.y };
  const dir  = h.vec2{ .x = if( offset.x > 0 ) 1 else if ( offset.x < 0 ) -1 else 0,
                        .y = if( offset.y > 0 ) 1 else if ( offset.y < 0 ) -1 else 0 };

  // Find the edges of each entities bounding box
  // NOTE : This assumes that the entities are axis-aligned rectangles
  // TODO : Add support for e2 shapes
  const selfEdge = h.vec2{
    .x = e1.pos.x + ( dir.x * e1.scale.x ),
    .y = e1.pos.y + ( dir.y * e1.scale.y )};

  const otherEdge = h.vec2{
    .x = e2.pos.x - ( dir.x * e2.scale.x ),
    .y = e2.pos.y - ( dir.y * e2.scale.y )};

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
