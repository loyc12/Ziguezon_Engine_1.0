const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;

// These various functions all related to AABB ( boxes ) calculations.
// They are used to calculate the position of a box in relation to its center and scale, or vice versa.
// They also provide functions to check if a box is within a certain range, or to clamp it within said range.

// The sides are defined as follows:
// LEFT   = -X ( xMin )
// RIGHT  = +X ( xMax )
// TOP    = -Y ( minY )
// BOTTOM = +Y ( maxY )

// ================================ UTIL FUNCTIONS ================================

inline fn isLeftOf(  xVal : f32, thresholdX : f32 ) bool { return xVal < thresholdX; }
inline fn isRightOf( xVal : f32, thresholdX : f32 ) bool { return xVal > thresholdX; }
inline fn isAbove(   yVal : f32, thresholdY : f32 ) bool { return yVal < thresholdY; } // NOTE : Y axis is inverted in raylib rendering
inline fn isBelow(   yVal : f32, thresholdY : f32 ) bool { return yVal > thresholdY; } // NOTE : Y axis is inverted in raylib rendering

inline fn checkMinMax( minVal : f32, maxVal : f32 ) bool
{
  if( minVal > maxVal )
  {
    def.log( .ERROR, 0, @src(), "Invalid range: minVal ({d}) is greater than maxVal ({d})", .{ minVal, maxVal });
    return true;
  }
  return false;
}
inline fn checkMinMax2( pMin : Vec2, pMax : Vec2 ) bool
{
  if( pMin.x > pMax.x or pMin.y > pMax.y )
  {
    def.log( .ERROR, 0, @src(), "Invalid area: pMin ({d}:{d}) is greater than pMax ({d}:{d})", .{ pMin.x, pMin.y, pMax.x, pMax.y });
    return true;
  }
  return false;
}

inline fn checkClampRange( minVal : f32, maxVal : f32, size : f32 ) bool
{
  if( maxVal - minVal < size )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for clamping: range ({d}) is smaller than the box size ({d})", .{ maxVal - minVal, size });
    return true;
  }
  return false;
}

// ================================ SIMPLE GETTERS & SETTERS ================================

pub inline fn getLeftX(   center : Vec2, scale : Vec2 ) f32                        { return center.x - scale.x; }
pub inline fn getRightX(  center : Vec2, scale : Vec2 ) f32                        { return center.x + scale.x; }
pub inline fn getTopY(    center : Vec2, scale : Vec2 ) f32                        { return center.y - scale.y; }
pub inline fn getBottomY( center : Vec2, scale : Vec2 ) f32                        { return center.y + scale.y; }

pub inline fn getTopLeft(     center : Vec2, scale : Vec2 ) Vec2                   { return Vec2{ .x = center.x - scale.x, .y = center.y - scale.y }; }
pub inline fn getTopRight(    center : Vec2, scale : Vec2 ) Vec2                   { return Vec2{ .x = center.x + scale.x, .y = center.y - scale.y }; }
pub inline fn getBottomLeft(  center : Vec2, scale : Vec2 ) Vec2                   { return Vec2{ .x = center.x - scale.x, .y = center.y + scale.y }; }
pub inline fn getBottomRight( center : Vec2, scale : Vec2 ) Vec2                   { return Vec2{ .x = center.x + scale.x, .y = center.y + scale.y }; }

pub inline fn getCenterXFromLeftX(   leftX   : f32, scale : Vec2 ) f32             { return leftX   + scale.x; }
pub inline fn getCenterXFromRightX(  rightX  : f32, scale : Vec2 ) f32             { return rightX  - scale.x; }
pub inline fn getCenterYFromTopY(    topY    : f32, scale : Vec2 ) f32             { return topY    + scale.y; }
pub inline fn getCenterYFromBottomY( bottomY : f32, scale : Vec2 ) f32             { return bottomY - scale.y; }

pub inline fn getCenterFromTopLeft(     topLeftPos     : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = topLeftPos.x     + scale.x, .y = topLeftPos.y     + scale.y }; }
pub inline fn getCenterFromTopRight(    topRightPos    : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = topRightPos.x    - scale.x, .y = topRightPos.y    + scale.y }; }
pub inline fn getCenterFromBottomLeft(  bottomLeftPos  : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = bottomLeftPos.x  + scale.x, .y = bottomLeftPos.y  - scale.y }; }
pub inline fn getCenterFromBottomRight( bottomRightPos : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = bottomRightPos.x - scale.x, .y = bottomRightPos.y - scale.y }; }


// ================================ RANGE FUNCTIONS ================================
// Checks if the box is entirely or partially within the given range

pub inline fn isLeftOfX(   center : Vec2, scale : Vec2, xVal : f32 ) bool { return getRightX(  center, scale ) < xVal; }
pub inline fn isRightOfX(  center : Vec2, scale : Vec2, xVal : f32 ) bool { return getLeftX(   center, scale ) > xVal; }
pub inline fn isAboveY(    center : Vec2, scale : Vec2, yVal : f32 ) bool { return getBottomY( center, scale ) < yVal; }
pub inline fn isBelowY(    center : Vec2, scale : Vec2, yVal : f32 ) bool { return getTopY(    center, scale ) > yVal; }

// ================ INCLUSIVE RANGE FUNCTIONS ================
// Checks if the box overlaps with the given range

pub inline fn isOnX( center : Vec2, scale : Vec2, xVal : f32 ) bool
{
  if( getLeftX( center, scale ) > xVal or getRightX( center, scale ) < xVal ){ return false; }
  return true;
}
pub inline fn isOnY( center : Vec2, scale : Vec2, yVal : f32 ) bool
{
  if( getTopY( center, scale ) > yVal or getBottomY( center, scale ) < yVal ){ return false; }
  return true;
}
pub inline fn isOnPoint( center : Vec2, scale : Vec2, p : Vec2 ) bool
{
  if( !isOnX( center, scale, p.x ) or !isOnY( center, scale, p.y )){ return false; }
  return true;
}

pub inline fn isOnXRange( center : Vec2, scale : Vec2, xMin : f32, xMax : f32 ) bool
{
  if( checkMinMax( xMin, xMax )){ return false; }
  if( getLeftX( center, scale ) > xMax or getRightX( center, scale ) < xMin ){ return false; }
  return true;
}
pub inline fn isOnYRange( center : Vec2, scale : Vec2, minY : f32, maxY : f32 ) bool
{
  if( checkMinMax( minY, maxY )){ return false; }
  if( getTopY( center, scale ) > maxY or getBottomY( center, scale ) < minY ){ return false; }
  return true;
}
pub inline fn isOnArea( center : Vec2, scale : Vec2, pMin : Vec2, pMax : Vec2 ) bool
{
  if( !checkMinMax2( pMin, pMax )) { return false; }
  if( !isOnXRange( center, scale, pMin.x, pMax.x ) or !isOnYRange( center, scale, pMin.y, pMax.y )){ return false; }
  return true;
}

// ================ EXCLUSIVE RANGE FUNCTIONS ================
// Checks if the box is entirely within the given range

pub inline fn isInXRange( center : Vec2, scale : Vec2, xMin : f32, xMax : f32 ) bool
{
  if( checkMinMax( xMin, xMax )){ return false; }
  if( getRightX( center, scale ) > xMax or getLeftX( center, scale ) < xMin ){ return false; }
  return true;
}
pub inline fn isInYRange( center : Vec2, scale : Vec2, minY : f32, maxY : f32 ) bool
{
  if( checkMinMax(  minY, maxY )){ return false; }
  if( getBottomY( center, scale ) > maxY or getTopY( center, scale ) < minY ){ return false; }
  return true;
}
pub inline fn isInArea( center : Vec2, scale : Vec2, pMin : Vec2, pMax : Vec2 ) bool
{
  if( checkMinMax2( pMin, pMax )){ return false; }
  if( !isInXRange( center, scale, pMin.x, pMax.x )){ return false; }
  if( !isInYRange( center, scale, pMin.y, pMax.y )){ return false; }
  return true;
}


// ================================ CLAMPING FUNCTIONS ================================
// Calculates an updated center position for a box, clamping it within or over the given range

pub inline fn clampLeftOfX(   center : Vec2, scale : Vec2, thresholdX : f32 ) f32 { if( getLeftX(   center, scale ) < thresholdX ) return thresholdX + scale.x else return center.x; }
pub inline fn clampRightOfX(  center : Vec2, scale : Vec2, thresholdX : f32 ) f32 { if( getRightX(  center, scale ) > thresholdX ) return thresholdX - scale.x else return center.x; }
pub inline fn clampBelowY(    center : Vec2, scale : Vec2, thresholdY : f32 ) f32 { if( getTopY(    center, scale ) < thresholdY ) return thresholdY + scale.y else return center.y; }
pub inline fn clampAboveY(    center : Vec2, scale : Vec2, thresholdY : f32 ) f32 { if( getBottomY( center, scale ) > thresholdY ) return thresholdY - scale.y else return center.y; }

// ================ INCLUSIVE CLAMPING FUNCTIONS ================
// Calculates an updated center position for a box, so that it is partially over the given range

pub inline fn clampOnXVal( center : Vec2, scale : Vec2, x : f32 ) f32
{
  if( getLeftX(  center, scale ) > x ){ return x + scale.x; }
  if( getRightX( center, scale ) < x ){ return x - scale.x; }
  return center.x;
}
pub inline fn clampOnYVal( center : Vec2, scale : Vec2, y : f32 ) f32
{
  if( getTopY(    center, scale ) > y ){ return y + scale.y; }
  if( getBottomY( center, scale ) < y ){ return y - scale.y; }
  return center.y;
}
pub inline fn clampOnPoint( center : Vec2, scale : Vec2, p : Vec2 ) Vec2
{
  return Vec2{
    .x = clampOnXVal( center, scale, p.x ),
    .y = clampOnYVal( center, scale, p.y )
  };
}

pub inline fn clampOnXRange( center : Vec2, scale : Vec2, xMin : f32, xMax : f32 ) f32
{
  if( checkMinMax( xMin, xMax )){ return center.x; }

  if( getRightX( center, scale ) < xMin ){ return xMin - scale.x; }
  if( getLeftX(  center, scale ) > xMax ){ return xMax + scale.x; }
  return center.x;
}
pub inline fn clampOnYRange( center : Vec2, scale : Vec2, minY : f32, maxY : f32 ) f32
{
  if( checkMinMax(  minY, maxY )){ return center.y; }

  if( getBottomY( center, scale ) < minY ){ return minY - scale.y; }
  if( getTopY(    center, scale ) > maxY ){ return maxY + scale.y; }
  return center.y;
}
pub inline fn clampOnArea( center : Vec2, scale : Vec2, pMin : Vec2, pMax : Vec2 ) Vec2
{
  if( checkMinMax2( pMin, pMax )){ return center; }
  return Vec2{
    .x = clampOnXRange( center, scale, pMin.x, pMax.x ),
    .y = clampOnYRange( center, scale, pMin.y, pMax.y )
  };
}

// ================ EXCLUSIVE CLAMPING FUNCTIONS ================
// Calculates an updated center position for a box, so that it is entirely within the given range

pub inline fn clampInXRange( center : Vec2, scale : Vec2, xMin : f32, xMax : f32 ) f32
{
  if( checkMinMax( xMin, xMax )){ return center.x; }
  if( checkClampRange( xMin, xMax, scale.x * 2 )){ return @divFloor( xMin + xMax, 2 ); }

  if( getLeftX(  center, scale ) < xMin ){ return xMin + scale.x; }
  if( getRightX( center, scale ) > xMax ){ return xMax - scale.x; }
  return center.x;
}
pub inline fn clampInYRange( center : Vec2, scale : Vec2, minY : f32, maxY : f32 ) f32
{
  if( checkMinMax( minY, maxY )){ return center.y; }
  if( checkClampRange( minY, maxY, scale.y * 2 )){ return @divFloor( minY + maxY, 2 ); }

  if( getTopY(    center, scale ) < minY ){ return minY + scale.y; }
  if( getBottomY( center, scale ) > maxY ){ return maxY - scale.y; }
  return center.y;
}
pub inline fn clampInArea( center : Vec2, scale : Vec2, pMin : Vec2, pMax : Vec2 ) Vec2
{
  if( checkMinMax2( pMin, pMax )){ return center; }
  return Vec2{
    .x = clampInXRange( center, scale, pMin.x, pMax.x ),
    .y = clampInYRange( center, scale, pMin.y, pMax.y )
  };
}