const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ POSITION ACCESSORS ================
// These functions calculate the sides of the Entity's bounding box based on its position and scale.
// These assume that the Entity is an axis-aligned rectangle, meaning that its sides are parallel to the X and Y axes.

// The sides are defined as follows:
// TOP    = -Y   // LEFT  = -X
// BOTTOM = +Y   // RIGHT = +X

// These functions return the sides of the Entity's bounding box.
pub fn getLeftX( e1 : *const Entity ) f32
{
  def.log( .TRACE, 0, @src(), "Calculating left side of Entity {d}", .{ e1.id });
  return e1.pos.x - e1.scale.x;
}
pub fn getRightX( e1 : *const Entity ) f32
{
  def.log( .TRACE, 0, @src(), "Calculating right side of Entity {d}", .{ e1.id });
  return e1.pos.x + e1.scale.x;
}
pub fn getTopY( e1 : *const Entity ) f32
{
  def.log( .TRACE, 0, @src(), "Calculating top side of Entity {d}", .{ e1.id });
  return e1.pos.y - e1.scale.y;
}
pub fn getBottomY( e1 : *const Entity ) f32
{
  def.log( .TRACE, 0, @src(), "Calculating bottom side of Entity {d}", .{ e1.id });
  return e1.pos.y + e1.scale.y;
}

// These functions return the corners of the Entity's bounding box.
pub fn getTopLeft( e1 : *const Entity ) Vec2
{
  def.log( .TRACE, 0, @src(), "Calculating top left corner of Entity {d}", .{ e1.id });
  return Vec2{ .x = e1.pos.x - e1.scale.x, .y = e1.pos.y - e1.scale.y };
}
pub fn getTopRight( e1 : *const Entity ) Vec2
{
  def.log( .TRACE, 0, @src(), "Calculating top right corner of Entity {d}", .{ e1.id });
  return Vec2{ .x = e1.pos.x + e1.scale.x, .y = e1.pos.y - e1.scale.y };
}
pub fn getBottomLeft( e1 : *const Entity ) Vec2
{
  def.log( .TRACE, 0, @src(), "Calculating bottom left corner of Entity {d}", .{ e1.id });
  return Vec2{ .x = e1.pos.x - e1.scale.x, .y = e1.pos.y + e1.scale.y };
}
pub fn getBottomRight( e1 : *const Entity ) Vec2
{
  def.log( .TRACE, 0, @src(), "Calculating bottom right corner of Entity {d}", .{ e1.id });
  return Vec2{ .x = e1.pos.x + e1.scale.x, .y = e1.pos.y + e1.scale.y };
}

// ================ POSITION SETTERS ================
// These functions set the sides of the Entity's bounding box.

pub fn cpyEntityPos( e1 : *Entity, e2 : *const Entity ) void
{
  def.log( .TRACE, 0, @src(), "Copying position from Entity {d} to Entity {d}", .{ e2.id, e1.id });
  e1.pos = e2.pos;
}
pub fn cpyEntityVel( e1 : *Entity, e2 : *const Entity ) void
{
  def.log( .TRACE, 0, @src(), "Copying velocity from Entity {d} to Entity {d}", .{ e2.id, e1.id });
  e1.vel = e2.vel;
}
pub fn cpyEntityAcc( e1 : *Entity, e2 : *const Entity ) void
{
  def.log( .TRACE, 0, @src(), "Copying acceleration from Entity {d} to Entity {d}", .{ e2.id, e1.id });
  e1.acc = e2.acc;
}

pub fn setLeftX( e1 : *Entity, leftX : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Setting left side of Entity {d} to {d}", .{ e1.id, leftX });
  e1.pos.x = leftX + e1.scale.x;
}
pub fn setRightX( e1 : *Entity, rightX : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Setting right side of Entity {d} to {d}", .{ e1.id, rightX });
  e1.pos.x = rightX - e1.scale.x;
}
pub fn setTopY( e1 : *Entity, topY : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Setting top side of Entity {d} to {d}", .{ e1.id, topY });
  e1.pos.y = topY + e1.scale.y;
}
pub fn setBottomY( e1 : *Entity, bottomY : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Setting bottom side of Entity {d} to {d}", .{ e1.id, bottomY });
  e1.pos.y = bottomY - e1.scale.y;
}

// These functions set the corners of the Entity's bounding box.
pub fn setTopLeft( e1 : *Entity, topLeftPos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Setting top left corner of Entity {d} to {d}:{d}", .{ e1.id, topLeftPos.x, topLeftPos.y });
  e1.pos.x = topLeftPos.x + e1.scale.x;
  e1.pos.y = topLeftPos.y + e1.scale.y;
}
pub fn setTopRight( e1 : *Entity, topRightPos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Setting top right corner of Entity {d} to {d}:{d}", .{ e1.id, topRightPos.x, topRightPos.y });
  e1.pos.x = topRightPos.x - e1.scale.x;
  e1.pos.y = topRightPos.y + e1.scale.y;
}
pub fn setBottomLeft( e1 : *Entity, bottomLeftPos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Setting bottom left corner of Entity {d} to {d}:{d}", .{ e1.id, bottomLeftPos.x, bottomLeftPos.y });
  e1.pos.x = bottomLeftPos.x + e1.scale.x;
  e1.pos.y = bottomLeftPos.y - e1.scale.y;
}
pub fn setBottomRight( e1 : *Entity, bottomRightPos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Setting bottom right corner of Entity {d} to {d}:{d}", .{ e1.id, bottomRightPos.x, bottomRightPos.y });
  e1.pos.x = bottomRightPos.x - e1.scale.x;
  e1.pos.y = bottomRightPos.y - e1.scale.y;
}

// ================ CLAMPING FUNCTIONS ================
// These functions clamp the Entity's position to a given range, preventing it from going out of bounds.
// They also set the velocity to 0 if the Entity was moving in the direction of the clamped side.

// These functions clamp the Entity's sides to a given range, preventing it from going out of bounds in that direction.
pub fn clampLeftX( e1 : *Entity, minLeftX : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping left side of Entity {d} to {d}", .{ e1.id, minLeftX });
  if( getLeftX( e1 ) < minLeftX )
  {
    setLeftX( e1, minLeftX );
    if( e1.vel.x < 0 ){ e1.vel.x = 0; }
  }
}
pub fn clampRightX( e1 : *Entity, maxRightX : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping right side of Entity {d} to {d}", .{ e1.id, maxRightX });
  if( getRightX( e1 ) > maxRightX )
  {
    setRightX( e1, maxRightX );
    if( e1.vel.x > 0 ){ e1.vel.x = 0; }
  }
}
pub fn clampTopY( e1 : *Entity, minTopY : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping top side of Entity {d} to {d}", .{ e1.id, minTopY });
  if( getTopY( e1 ) < minTopY )
  {
    setTopY( e1, minTopY );
    if( e1.vel.y < 0 ){ e1.vel.y = 0; }
  }
}
pub fn clampBottomY( e1 : *Entity, maxBottomY : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping bottom side of Entity {d} to {d}", .{ e1.id, maxBottomY });
  if( getBottomY( e1 ) > maxBottomY )
  {
    setBottomY( e1, maxBottomY );
    if( e1.vel.y > 0 ){ e1.vel.y = 0; }
  }
}

// These functions clamp the Entity's hitbox in a given range on the X and Y axes.
pub fn clampInX( e1 : *Entity, minX : f32, maxX : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on X axis to range {d}:{d}", .{ e1.id, minX, maxX });
  clampLeftX(  e1, minX );
  clampRightX(  e1,maxX );
}
pub fn clampInY( e1 : *Entity, minY : f32, maxY : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on Y axis to range {d}:{d}", .{ e1.id, minY, maxY });
  clampTopY(    e1, minY );
  clampBottomY( e1, maxY );
}
pub fn clampInArea( e1 : *Entity, minPos : Vec2, maxPos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} in area {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  clampInX( e1, minPos.x, maxPos.x );
  clampInY( e1, minPos.y, maxPos.y );
}

// These functions clamp the Entity's hitbox on a given range on the X axis ( can overlap only partially ).
pub fn clampOnX( e1 : *Entity, minX : f32, maxX : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on X axis to range {d}:{d}", .{ e1.id, minX, maxX });
  clampLeftX(  e1, minX - ( 2 * e1.scale.x ));
  clampRightX( e1, maxX + ( 2 * e1.scale.x ));
}
pub fn clampOnY( e1 : *Entity, minY : f32, maxY : f32 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on Y axis to range {d}:{d}", .{ e1.id, minY, maxY });
  clampTopY(    e1, minY - ( 2 * e1.scale.y ));
  clampBottomY( e1, maxY + ( 2 * e1.scale.y ));
}
pub fn clampOnArea( e1 : *Entity, minPos : Vec2, maxPos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} in area {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  clampOnX( e1, minPos.x, maxPos.x );
  clampOnY( e1, minPos.y, maxPos.y );
}

pub fn clampOnPoint( e1 : *Entity, pos : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on point {d}:{d}", .{ e1.id, pos.x, pos.y });
  clampOnX( e1, pos.x, pos.x );
  clampOnY( e1, pos.y, pos.y );
}
pub fn clampOnEntity( e1 : *Entity, e2 : *const Entity ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} on Entity {d}", .{ e1.id, e2.id });
  clampOnX( e1, getLeftX( e2 ), getRightX( e2 ));
  clampOnY( e1, getTopY( e2 ), getBottomY( e2 ));
}
pub fn clampNearEntity( e1 : *Entity, e2 : *const Entity, masOffset : Vec2 ) void
{
  def.log( .TRACE, 0, @src(), "Clamping Entity {d} near Entity {d}", .{ e1.id, e2.id });
  // This function clamps the Entity to be near another Entity, allowing for partial overlap.
  clampInX( e1, getLeftX( e2 ) - masOffset.x, getRightX( e2 ) + masOffset.x );
  clampInY( e1, getTopY( e2 ) - masOffset.y, getBottomY( e2 ) + masOffset.y );
}

// ================ RANGE FUNCTIONS ================
// These functions check if the Entity is entirely or partially within a given range.
// NOTE : These assume that the Entity is an axis-aligned rectangle

// An Entity is considered to be in range if its bounding box is entirely within the range.
pub fn isInRangeX( e1 : *const Entity, minX : f32, maxX : f32 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is in range X:{d}:{d}", .{ e1.id, minX, maxX });
  return( getLeftX( e1 ) >= minX and getRightX( e1 ) <= maxX );
}
pub fn isInRangeY( e1 : *const Entity, minY : f32, maxY : f32 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is in range Y:{d}:{d}", .{ e1.id, minY, maxY });
  return( .getTopY( e1 ) >= minY and getBottomY( e1 ) <= maxY );
}
pub fn isInRange( e1 : *const Entity, minPos : Vec2, maxPos : Vec2 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is in range {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  return(( isInRangeX( e1, minPos.x, maxPos.x ) and isInRangeY( e1, minPos.y, maxPos.y )));
}

// An Entity is considered to be on e1, range if its bounding box overlaps with the range.
pub fn isOnRangeX( e1 : *const Entity, minX : f32, maxX : f32 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on range X:{d}:{d}", .{ e1.id, minX, maxX });
  return( getRightX( e1 ) >= minX and getLeftX( e1 ) <= maxX );
}
pub fn isOnRangeY( e1 : *const Entity, minY : f32, maxY : f32 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on range Y:{d}:{d}", .{ e1.id, minY, maxY });
  return( getBottomY( e1) >= minY and getTopY( e1 ) <= maxY );
}
pub fn isOnRange( e1 : *const Entity, minPos : Vec2, maxPos : Vec2 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on range {d}:{d} to {d}:{d}", .{ e1.id, minPos.x, minPos.y, maxPos.x, maxPos.y });
  return(( isOnRangeX( e1, minPos.x, maxPos.x ) and isOnRangeY( e1, minPos.y, maxPos.y )));
}

pub fn isOnPoint( e1 : *const Entity, pos : Vec2 ) bool
{
  def.log( .TRACE, 0, @src(), "Checking if Entity {d} is on point {d}:{d}", .{ e1.id, pos.x, pos.y });
  return( getLeftX( e1 ) <= pos.x and getRightX( e1 ) >= pos.x and getTopY( e1 ) <= pos.y and getBottomY( e1 ) >= pos.y );
}

// TODO : add checks and setters for the angles


// ================ MOVEMENT FUNCTIONS ================

pub fn moveSelf( e1 : *Entity, sdt : f32 ) void
{
  if( !e1.isMobile() )
  {
    def.log( .TRACE, 0, @src(), "Entity {d} is not mobile and cannot be moved", .{ e1.id });
    return;
  }

  def.log( .TRACE, 0, @src(), "Moving Entity {d} by velocity {d}:{d} with acceleration {d}:{d} over time {d}", .{ e1.id, e1.vel.x, e1.vel.y, e1.acc.x, e1.acc.y, sdt });

  e1.vel.x += e1.acc.x * sdt;
  e1.vel.y += e1.acc.y * sdt;
  e1.vel.z += e1.acc.z * sdt;

  e1.pos.x += e1.vel.x * sdt;
  e1.pos.y += e1.vel.y * sdt;
  e1.pos.z += e1.vel.z * sdt;

  e1.acc.x = 0;
  e1.acc.y = 0;
  e1.acc.z = 0;
}