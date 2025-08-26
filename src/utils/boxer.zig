const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;

// These various functions all related to AABB ( boxes ) calculations.
// They are used to calculate the position of a box in relation to its center and radii, or vice versa.
// They also provide functions to check if a box is within a certain range, or to clamp it within said range.

// The sides are defined as follows:
// TOP    = -Y   // LEFT  = -X
// BOTTOM = +Y   // RIGHT = +X


// ================================ SIMPLE GETTERS & SETTERS ================================

pub inline fn getLeftX(   center : Vec2, radii : Vec2 ) f32                        { return center.x - radii.x; }
pub inline fn getRightX(  center : Vec2, radii : Vec2 ) f32                        { return center.x + radii.x; }
pub inline fn getTopY(    center : Vec2, radii : Vec2 ) f32                        { return center.y - radii.y; }
pub inline fn getBottomY( center : Vec2, radii : Vec2 ) f32                        { return center.y + radii.y; }

pub inline fn getTopLeft(     center : Vec2, radii : Vec2 ) Vec2                   { return Vec2{ .x = center.x - radii.x, .y = center.y - radii.y }; }
pub inline fn getTopRight(    center : Vec2, radii : Vec2 ) Vec2                   { return Vec2{ .x = center.x + radii.x, .y = center.y - radii.y }; }
pub inline fn getBottomLeft(  center : Vec2, radii : Vec2 ) Vec2                   { return Vec2{ .x = center.x - radii.x, .y = center.y + radii.y }; }
pub inline fn getBottomRight( center : Vec2, radii : Vec2 ) Vec2                   { return Vec2{ .x = center.x + radii.x, .y = center.y + radii.y }; }

pub inline fn getCenterXFromLeftX(   leftX   : f32, radii : Vec2 ) f32             { return  leftX   + radii.x; }
pub inline fn getCenterXFromRightX(  rightX  : f32, radii : Vec2 ) f32             { return  rightX  - radii.x; }
pub inline fn getCenterYFromTopY(    topY    : f32, radii : Vec2 ) f32             { return  topY    + radii.y; }
pub inline fn getCenterYFromBottomY( bottomY : f32, radii : Vec2 ) f32             { return  bottomY - radii.y; }

pub inline fn getCenterFromTopLeft(     topLeftPos     : Vec2, radii : Vec2 ) Vec2 { return Vec2{ .x = topLeftPos.x     + radii.x, .y = topLeftPos.y     + radii.y }; }
pub inline fn getCenterFromTopRight(    topRightPos    : Vec2, radii : Vec2 ) Vec2 { return Vec2{ .x = topRightPos.x    - radii.x, .y = topRightPos.y    + radii.y }; }
pub inline fn getCenterFromBottomLeft(  bottomLeftPos  : Vec2, radii : Vec2 ) Vec2 { return Vec2{ .x = bottomLeftPos.x  + radii.x, .y = bottomLeftPos.y  - radii.y }; }
pub inline fn getCenterFromBottomRight( bottomRightPos : Vec2, radii : Vec2 ) Vec2 { return Vec2{ .x = bottomRightPos.x - radii.x, .y = bottomRightPos.y - radii.y }; }


// ================================ RANGE FUNCTIONS ================================
// Checks if the box is entirely or partially within the given range

pub inline fn isLeftOfX(   center : Vec2, radii : Vec2, xVal : f32 ) bool { return getRightX(  center, radii ) < xVal; }
pub inline fn isRightOfX(  center : Vec2, radii : Vec2, xVal : f32 ) bool { return getLeftX(   center, radii ) > xVal; }
pub inline fn isBelowY(    center : Vec2, radii : Vec2, yVal : f32 ) bool { return getBottomY( center, radii ) < yVal; }
pub inline fn isAboveY(    center : Vec2, radii : Vec2, yVal : f32 ) bool { return getTopY(    center, radii ) > yVal; }

// ================ INCLUSIVE RANGE FUNCTIONS ================
// Checks if the box overlaps with the given range

pub inline fn isOnXVal( center : Vec2, radii : Vec2, xVal : f32 ) bool
{
  if( getLeftX( center, radii ) > xVal or getRightX( center, radii ) < xVal ){ return false; }
  return true;
}
pub inline fn isOnYVal( center : Vec2, radii : Vec2, yVal : f32 ) bool
{
  if( getTopY( center, radii ) > yVal or getBottomY( center, radii ) < yVal ){ return false; }
  return true;
}
pub inline fn isOnPoint( center : Vec2, radii : Vec2, point : Vec2 ) bool
{
  if( !isOnXVal( center, radii, point.x ) or !isOnYVal( center, radii, point.y )){ return false; }
  return true;
}

pub inline fn isOnXRange( center : Vec2, radii : Vec2, minX : f32, maxX : f32 ) bool
{
  if( minX > maxX )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for checking on X: minX ({d}) is greater than maxX ({d})", .{ minX, maxX });
    return false;
  }
  if( getLeftX( center, radii ) > maxX or getRightX( center, radii ) < minX ){ return false; }
  return true;
}
pub inline fn isOnYRange( center : Vec2, radii : Vec2, minY : f32, maxY : f32 ) bool
{
  if( minY > maxY )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for checking on Y: minY ({d}) is greater than maxY ({d})", .{ minY, maxY });
    return false;
  }
  if( getTopY( center, radii ) > maxY or getBottomY( center, radii ) < minY ){ return false; }
  return true;
}
pub inline fn isOnArea( center : Vec2, radii : Vec2, minPos : Vec2, maxPos : Vec2 ) bool
{
  if( minPos.x > maxPos.x or minPos.y > maxPos.y )
  {
    def.log( .ERROR, 0, @src(), "Invalid area for checking: minPos ({d}:{d}) is greater than maxPos ({d}:{d})", .{ minPos.x, minPos.y, maxPos.x, maxPos.y });
    return false;
  }
  if( !isOnXRange( center, radii, minPos.x, maxPos.x ) or !isOnYRange( center, radii, minPos.y, maxPos.y )){ return false; }
  return true;
}

// ================ EXCLUSIVE RANGE FUNCTIONS ================
// Checks if the box is entirely within the given range

pub inline fn isInXRange( center : Vec2, radii : Vec2, minX : f32, maxX : f32 ) bool
{
  if( minX > maxX )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for checking in X: minX ({d}) is greater than maxX ({d})", .{ minX, maxX });
    return false;
  }
  if( getRightX( center, radii ) > maxX or getLeftX( center, radii ) < minX ){ return false; }
  return true;
}
pub inline fn isInYRange( center : Vec2, radii : Vec2, minY : f32, maxY : f32 ) bool
{
  if( minY > maxY )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for checking in Y: minY ({d}) is greater than maxY ({d})", .{ minY, maxY });
    return false;
  }
  if( getBottomY( center, radii ) > maxY or getTopY( center, radii ) < minY ){ return false; }
  return true;
}
pub inline fn isInArea( center : Vec2, radii : Vec2, minPos : Vec2, maxPos : Vec2 ) bool
{
  if( minPos.x > maxPos.x or minPos.y > maxPos.y )
  {
    def.log( .ERROR, 0, @src(), "Invalid area for checking: minPos ({d}:{d}) is greater than maxPos ({d}:{d})", .{ minPos.x, minPos.y, maxPos.x, maxPos.y });
    return false;
  }
  if( !isInXRange( center, radii, minPos.x, maxPos.x ) or !isInYRange( center, radii, minPos.y, maxPos.y )){ return false; }
  return true;
}


// ================================ CLAMPING FUNCTIONS ================================
// Calculates an updated center position for a box, clamping it within or over the given range

pub inline fn clampLeftOfX(   center : Vec2, radii : Vec2, minLeftX   : f32 ) f32 { if( getLeftX(   center, radii ) < minLeftX   ) return minLeftX   + radii.x else return center.x; }
pub inline fn clampRightOfX(  center : Vec2, radii : Vec2, maxRightX  : f32 ) f32 { if( getRightX(  center, radii ) > maxRightX  ) return maxRightX  - radii.x else return center.x; }
pub inline fn clampBelowY(    center : Vec2, radii : Vec2, minTopY    : f32 ) f32 { if( getTopY(    center, radii ) < minTopY    ) return minTopY    + radii.y else return center.y; }
pub inline fn clampAboveY(    center : Vec2, radii : Vec2, maxBottomY : f32 ) f32 { if( getBottomY( center, radii ) > maxBottomY ) return maxBottomY - radii.y else return center.y; }

// ================ INCLUSIVE CLAMPING FUNCTIONS ================
// Calculates an updated center position for a box, so that it is partially over the given range

pub inline fn clampOnXVal( center : Vec2, radii : Vec2, x : f32 ) f32
{
  if( getLeftX(  center, radii ) > x ){ return x + radii.x; }
  if( getRightX( center, radii ) < x ){ return x - radii.x; }
  return center.x;
}
pub inline fn clampOnYVal( center : Vec2, radii : Vec2, y : f32 ) f32
{
  if( getTopY(    center, radii ) > y ){ return y + radii.y; }
  if( getBottomY( center, radii ) < y ){ return y - radii.y; }
  return center.y;
}
pub inline fn clampOnPoint( center : Vec2, radii : Vec2, point : Vec2 ) Vec2
{
  return Vec2{
    .x = clampOnXVal( center, radii, point.x ),
    .y = clampOnYVal( center, radii, point.y )
  };
}

pub inline fn clampOnXRange( center : Vec2, radii : Vec2, minX : f32, maxX : f32 ) f32
{
  if( minX > maxX )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for clamping on X: minX ({d}) is greater than maxX ({d})", .{ minX, maxX });
    return center.x;
  }
  if( getRightX( center, radii ) < minX ){ return minX - radii.x; }
  if( getLeftX(  center, radii ) > maxX ){ return maxX + radii.x; }
  return center.x;
}
pub inline fn clampOnYRange( center : Vec2, radii : Vec2, minY : f32, maxY : f32 ) f32
{
  if( minY > maxY )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for clamping on Y: minY ({d}) is greater than maxY ({d})", .{ minY, maxY });
    return center.y;
  }
  if( getBottomY( center, radii ) < minY ){ return minY - radii.y; }
  if( getTopY(    center, radii ) > maxY ){ return maxY + radii.y; }
  return center.y;
}
pub inline fn clampOnArea( center : Vec2, radii : Vec2, minPos : Vec2, maxPos : Vec2 ) Vec2
{
  if( minPos.x > maxPos.x or minPos.y > maxPos.y )
  {
    def.log( .ERROR, 0, @src(), "Invalid area for clamping: minPos ({d}:{d}) is greater than maxPos ({d}:{d})", .{ minPos.x, minPos.y, maxPos.x, maxPos.y });
    return center;
  }
  return Vec2{
    .x = clampOnXRange( center, radii, minPos.x, maxPos.x ),
    .y = clampOnYRange( center, radii, minPos.y, maxPos.y )
  };
}

// ================ EXCLUSIVE CLAMPING FUNCTIONS ================
// Calculates an updated center position for a box, so that it is entirely within the given range

pub inline fn clampInXRange( center : Vec2, radii : Vec2, minX : f32, maxX : f32 ) f32
{
  if( minX > maxX )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for clamping in X: minX ({d}) is greater than maxX ({d})", .{ minX, maxX });
    return center.x;
  }
  if( getLeftX(  center, radii ) < minX and getRightX( center, radii ) > maxX )
  {
    def.qlog( .WARN, 0, @src(), "Trying to clamp a box in an X range that is too small for it" );
    return @divFloor( minX + maxX, 2 );
  }
  if( getLeftX(  center, radii ) < minX ){ return minX + radii.x; }
  if( getRightX( center, radii ) > maxX ){ return maxX - radii.x; }
  return center.x;
}
pub inline fn clampInYRange( center : Vec2, radii : Vec2, minY : f32, maxY : f32 ) f32
{
  if( minY > maxY )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for clamping in Y: minY ({d}) is greater than maxY ({d})", .{ minY, maxY });
    return center.y;
  }
  if( getTopY(    center, radii ) < minY and getBottomY( center, radii ) > maxY )
  {
    def.qlog( .WARN, 0, @src(), "Trying to clamp a box in a Y range that is too small for it" );
    return @divFloor( minY + maxY, 2 );
  }
  if( getTopY(    center, radii ) < minY ){ return minY + radii.y; }
  if( getBottomY( center, radii ) > maxY ){ return maxY - radii.y; }
  return center.y;
}
pub inline fn clampInArea( center : Vec2, radii : Vec2, minPos : Vec2, maxPos : Vec2 ) Vec2
{
  if( minPos.x > maxPos.x or minPos.y > maxPos.y )
  {
    def.log( .ERROR, 0, @src(), "Invalid area for clamping: minPos ({d}:{d}) is greater than maxPos ({d}:{d})", .{ minPos.x, minPos.y, maxPos.x, maxPos.y });
    return center;
  }
  return Vec2{
    .x = clampInXRange( center, radii, minPos.x, maxPos.x ),
    .y = clampInYRange( center, radii, minPos.y, maxPos.y )
  };
}