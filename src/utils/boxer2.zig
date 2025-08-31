const std = @import( "std" );
const def = @import( "defs" );

const Angle = def.Angle;
const Vec2  = def.Vec2;
const VecA  = def.VecA;

// This is a simple AABB struct ( Axis-Aligned Bounding Box ) meant to ease collision checks and clamping operations.

// NOTE : The orientations are defined as follows:

// LEFT   => -X ( xMin side )
// RIGHT  => +X ( xMax side )
// TOP    => -Y ( minY side )
// BOTTOM => +Y ( maxY side )

// ================================ UTIL FUNCTIONS ================================

pub inline fn isLeftOf(  xVal : f32, thresholdX : f32 ) bool { return xVal < thresholdX; }
pub inline fn isRightOf( xVal : f32, thresholdX : f32 ) bool { return xVal > thresholdX; }
pub inline fn isAbove(   yVal : f32, thresholdY : f32 ) bool { return yVal < thresholdY; } // NOTE : Y axis is inverted in raylib rendering
pub inline fn isBelow(   yVal : f32, thresholdY : f32 ) bool { return yVal > thresholdY; } // NOTE : Y axis is inverted in raylib rendering

pub inline fn getCenterXFromLeftX(   leftX   : f32, scale : Vec2 ) f32 { return leftX   + scale.x; }
pub inline fn getCenterXFromRightX(  rightX  : f32, scale : Vec2 ) f32 { return rightX  - scale.x; }
pub inline fn getCenterYFromTopY(    topY    : f32, scale : Vec2 ) f32 { return topY    + scale.y; }
pub inline fn getCenterYFromBottomY( bottomY : f32, scale : Vec2 ) f32 { return bottomY - scale.y; }

pub inline fn getCenterFromTopLeft(     topLeftPos     : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromLeftX(  topLeftPos.x,     scale ), .y = getCenterYFromTopY(    topLeftPos.y,     scale ) }; }
pub inline fn getCenterFromTopRight(    topRightPos    : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromRightX( topRightPos.x,    scale ), .y = getCenterYFromTopY(    topRightPos.y,    scale ) }; }
pub inline fn getCenterFromBottomLeft(  bottomLeftPos  : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromLeftX(  bottomLeftPos.x,  scale ), .y = getCenterYFromBottomY( bottomLeftPos.y,  scale ) }; }
pub inline fn getCenterFromBottomRight( bottomRightPos : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromRightX( bottomRightPos.x, scale ), .y = getCenterYFromBottomY( bottomRightPos.y, scale ) }; }

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

// ================================ BOX2 STRUCT ================================

pub const Box2 = struct
{
  center : Vec2 = .{},
  scale  : Vec2 = .{}, // Half-size of the box in each dimension

  pub fn new( center : Vec2, scale : Vec2 ) Box2 { return Box2{ .center = center, .scale  = scale }; }

  pub inline fn addScale( self : Box2, delta : Vec2 ) Box2
  {
    return Box2{
      .center = self.center,
      .scale  = self.scale.add( delta ),
    };
  }
  pub inline fn subScale( self : Box2, delta : Vec2 ) Box2
  {
    return Box2{
      .center = self.center,
      .scale  = self.scale.sub( delta ),
    };
  }

  pub inline fn mulScale( self : Box2, factors : Vec2 ) Box2
  {
    return Box2{
      .center = self.center,
      .scale  = self.scale.mul( factors ),
    };
  }
  pub inline fn moveCenter( self : Box2, delta : Vec2 ) Box2
  {
    return Box2{
      .center = self.center.add( delta ),
      .scale  = self.scale,
    };
  }
  pub inline fn rotCenter( self : Box2, a : Angle ) Box2
  {
    return Box2{
      .center = self.center.rot( a ),
      .scale  = self.scale,
    };
  }

  // ================ ACCESSORS & MUTATORS ================

  pub inline fn getLeftX(   self : *const Box2 ) f32 { return self.center.x - self.scale.x; }
  pub inline fn getRightX(  self : *const Box2 ) f32 { return self.center.x + self.scale.x; }
  pub inline fn getTopY(    self : *const Box2 ) f32 { return self.center.y - self.scale.y; }
  pub inline fn getBottomY( self : *const Box2 ) f32 { return self.center.y + self.scale.y; }

  pub inline fn getTopLeft(     self : *const Box2 ) Vec2 { return Vec2{ .x = self.getLeftX(),  .y = self.getTopY()    }; }
  pub inline fn getTopRight(    self : *const Box2 ) Vec2 { return Vec2{ .x = self.getRightX(), .y = self.getTopY()    }; }
  pub inline fn getBottomLeft(  self : *const Box2 ) Vec2 { return Vec2{ .x = self.getLeftX(),  .y = self.getBottomY() }; }
  pub inline fn getBottomRight( self : *const Box2 ) Vec2 { return Vec2{ .x = self.getRightX(), .y = self.getBottomY() }; }

  pub inline fn setLeftX(   self : *Box2, leftX   : f32 ) void { self.center.x = leftX   + self.scale.x ; }
  pub inline fn setRightX(  self : *Box2, rightX  : f32 ) void { self.center.x = rightX  - self.scale.x ; }
  pub inline fn setTopY(    self : *Box2, topY    : f32 ) void { self.center.y = topY    + self.scale.y ; }
  pub inline fn setBottomY( self : *Box2, bottomY : f32 ) void { self.center.y = bottomY - self.scale.y ; }

  pub inline fn setTopLeft(     self : *Box2, topLeftPos     : Vec2 ) void { self.setLeftX(  topLeftPos.x     ); self.setTopY(    topLeftPos.y     ); }
  pub inline fn setTopRight(    self : *Box2, topRightPos    : Vec2 ) void { self.setRightX( topRightPos.x    ); self.setTopY(    topRightPos.y    ); }
  pub inline fn setBottomLeft(  self : *Box2, bottomLeftPos  : Vec2 ) void { self.setLeftX(  bottomLeftPos.x  ); self.setBottomY( bottomLeftPos.y  ); }
  pub inline fn setBottomRight( self : *Box2, bottomRightPos : Vec2 ) void { self.setRightX( bottomRightPos.x ); self.setBottomY( bottomRightPos.y ); }

  // ================ CHECKERS ================

  // ======== PERMISSIVE RANGE CHECKERS ======== ( can be partially outside the range )

  pub inline fn goesLeftOfX(  self : *const Box2, thresholdX : f32 ) bool { return isLeftOf(  self.getLeftX(),   thresholdX ); }
  pub inline fn goesRightOfX( self : *const Box2, thresholdX : f32 ) bool { return isRightOf( self.getRightX(),  thresholdX ); }
  pub inline fn goesAboveY(   self : *const Box2, thresholdY : f32 ) bool { return isAbove(   self.getTopY(),    thresholdY ); }
  pub inline fn goesBelowY(   self : *const Box2, thresholdY : f32 ) bool { return isBelow(   self.getBottomY(), thresholdY ); }

  pub inline fn isOnX(     self : *const Box2, xVal  : f32  ) bool { if( self.isLeftOfX( xVal ) or self.isRightOfX( xVal )){ return false; } return true; }
  pub inline fn isOnY(     self : *const Box2, yVal  : f32  ) bool { if( self.isAboveY(  yVal ) or self.isBelowY(   yVal )){ return false; } return true; }
  pub inline fn isOnPoint( self : *const Box2, p : Vec2 ) bool { if( !self.isOnX( p.x ) or !self.isOnY(  p.y )){ return false; } return true; }

  pub fn isOnXRange( self : *const Box2, xMin : f32, xMax : f32 ) bool
  {
    if( checkMinMax(  xMin, xMax )){ return false; }
    if( self.isLeftOfX(     xMin )){ return false; }
    if( self.isRightOfX(    xMax )){ return false; }
    return true;
  }
  pub fn isOnYRange( self : *const Box2, minY : f32, maxY : f32 ) bool
  {
    if( checkMinMax( minY, maxY )){ return false; }
    if( self.isAboveY(     minY )){ return false; }
    if( self.isBelowY(     maxY )){ return false; }
    return true;
  }
  pub fn isOnArea( self : *const Box2, pMin : Vec2, pMax : Vec2 ) bool
  {
    if( checkMinMax2(     pMin,   pMax   )){ return false; }
    if( !self.isOnXRange( pMin.x, pMax.x )){ return false; }
    if( !self.isOnYRange( pMin.y, pMax.y )){ return false; }
    return true;
  }

  // ======== RESTRICTIVE RANGE CHECKERS ======== ( must be entirely inside the range )

  pub inline fn isLeftOfX(  self : *const Box2, thresholdX : f32 ) bool { return isLeftOf(  self.getRightX(),  thresholdX ); }
  pub inline fn isRightOfX( self : *const Box2, thresholdX : f32 ) bool { return isRightOf( self.getLeftX(),   thresholdX ); }
  pub inline fn isAboveY(   self : *const Box2, thresholdY : f32 ) bool { return isAbove(   self.getBottomY(), thresholdY ); }
  pub inline fn isBelowY(   self : *const Box2, thresholdY : f32 ) bool { return isBelow(   self.getTopY(),    thresholdY ); }

  pub fn isInXRange( self : *const Box2, xMin : f32, xMax : f32 ) bool
  {
    if( checkMinMax(       xMin, xMax )){                   return false; }
    if( checkClampRange(   xMin, xMax, self.scale.x * 2 )){ return false; }
    if( self.goesLeftOfX(  xMin )){                         return false; }
    if( self.goesRightOfX( xMax )){                         return false; }
    return true;
  }
  pub fn isInYRange( self : *const Box2, minY : f32, maxY : f32 ) bool
  {
    if( checkMinMax(      minY, maxY )){                   return false; }
    if( checkClampRange(  minY, maxY, self.scale.y * 2 )){ return false; }
    if( self.goesAboveY(  minY )){                         return false; }
    if( self.goesBellowY( maxY )){                         return false; }
    return true;
  }
  pub fn isInArea( self : *const Box2, pMin : Vec2, pMax : Vec2 ) bool
  {
    if( checkMinMax2(     pMin,   pMax   )){ return false; }
    if( !self.isInXRange( pMin.x, pMax.x )){ return false; }
    if( !self.isInYRange( pMin.y, pMax.y )){ return false; }
    return true;
  }

  // ================ CLAMPERS ================

  // ======== PERMISSIVE CLAMPERS ======== ( can be partially outside the range )

  pub inline fn clampOnLeftX(   self : *Box2, thresholdX : f32 ) void { if( self.isLeftOfX(  thresholdX )){ self.setRightX(  thresholdX ); }}
  pub inline fn clampOnRightX(  self : *Box2, thresholdX : f32 ) void { if( self.isRightOfX( thresholdX )){ self.setLeftX(   thresholdX ); }}
  pub inline fn clampOnTopY(    self : *Box2, thresholdY : f32 ) void { if( self.isAboveY(   thresholdY )){ self.setBottomY( thresholdY ); }}
  pub inline fn clampOnBottomY( self : *Box2, thresholdY : f32 ) void { if( self.isBelowY(   thresholdY )){ self.setTopY(    thresholdY ); }}

  pub fn clampOnX( self : *Box2, xVal : f32 ) void
  {
    if( self.isLeftOfX(  xVal )){ self.setRightX( xVal ); }
    if( self.isRightOfX( xVal )){ self.setLeftX(  xVal ); }
  }
  pub fn clampOnY( self : *Box2, yVal : f32 ) void
  {
    if( self.isAboveY(   yVal )){ self.setBottomY( yVal ); }
    if( self.isBelowY(   yVal )){ self.setTopY(    yVal ); }
  }
  pub fn clampOnPoint( self : *Box2, p : Vec2 ) void
  {
    self.clampOnX( p.x );
    self.clampOnY( p.y );
  }

  pub fn clampOnXRange( self : *Box2, xMin : f32, xMax : f32 ) void
  {
    if( checkMinMax( xMin, xMax )){ return; }
    self.clampOnLeftX(  xMin );
    self.clampOnRightX( xMax );
  }
  pub fn clampOnYRange( self : *Box2, minY : f32, maxY : f32 ) void
  {
    if( checkMinMax( minY, maxY )){ return; }
    self.clampOnTopY(    minY );
    self.clampOnBottomY( maxY );
  }
  pub fn clampOnArea( self : *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( checkMinMax2(   pMin,   pMax )){ return; }
    self.clampOnXRange( pMin.x, pMax.x );
    self.clampOnYRange( pMin.y, pMax.y );
  }

  pub fn clampNotInXRange( self : *Box2, xMin : f32, xMax : f32 ) void
  {
    if( checkMinMax( xMin, xMax )){ return; }
    const leftOverlap  = @abs( self.getRightX() - xMin );
    const rightOverlap = @abs( self.getLeftX()  - xMax );

    if( leftOverlap < rightOverlap ){ self.clampOnLeftX(  xMin ); }
    else                            { self.clampOnRightX( xMax ); }
  }
  pub fn clampNotInYRange( self : *Box2, minY : f32, maxY : f32 ) void
  {
    if( checkMinMax( minY, maxY )){ return; }
    const topOverlap    = @abs( self.getBottomY() - minY );
    const bottomOverlap = @abs( self.getTopY()    - maxY );

    if( topOverlap < bottomOverlap ){ self.clampOnTopY(    minY ); }
    else                            { self.clampOnBottomY( maxY ); }
  }
  pub fn clampNotInArea( self : *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( checkMinMax2( pMin, pMax )){ return; }
    self.clampNotOnXRange( pMin.x, pMax.x );
    self.clampNotOnYRange( pMin.y, pMax.y );
  }


  // ======== RESTRICTIVE CLAMPERS ======== ( must be entirely inside the range )

  pub inline fn clampInLeftX(   self : *Box2, thresholdX : f32 ) void { if( self.goesLeftOfX(  thresholdX )){ self.setLeftX(   thresholdX ); }}
  pub inline fn clampInRightX(  self : *Box2, thresholdX : f32 ) void { if( self.goesRightOfX( thresholdX )){ self.setRightX(  thresholdX ); }}
  pub inline fn clampInTopY(    self : *Box2, thresholdY : f32 ) void { if( self.goesAboveY(   thresholdY )){ self.setTopY(    thresholdY ); }}
  pub inline fn clampInBottomY( self : *Box2, thresholdY : f32 ) void { if( self.goesBelowY(   thresholdY )){ self.setBottomY( thresholdY ); }}

  pub fn clampNotOnX( self : *Box2, xVal : f32 ) void
  {
    if( self.center.x < xVal ){ self.clampInLeftX(  xVal ); }
    else                      { self.clampInRightX( xVal ); }
  }
  pub fn clampNotOnY( self : *Box2, yVal : f32 ) void
  {
    if( self.center.y < yVal ){ self.clampInTopY(    yVal ); }
    else                      { self.clampInBottomY( yVal ); }
  }
  pub fn clampNotOnPoint( self : *Box2, p : Vec2 ) void
  {
    self.clampNotOnX( p.x );
    self.clampNotOnY( p.y );
  }

  pub fn clampInXRange( self : *Box2, xMin : f32, xMax : f32 ) void
  {
    if( checkMinMax(      xMin, xMax )){ return; }
    if( checkClampRange(  xMin, xMax, self.scale.x * 2 )){ self.center.x = ( xMin + xMax ) * 0.5; return; }
    self.clampInLeftX(  xMin );
    self.clampInRightX( xMax );
  }
  pub fn clampInYRange( self : *Box2, minY : f32, maxY : f32 ) void
  {
    if( checkMinMax(     minY, maxY )){ return; }
    if( checkClampRange( minY, maxY, self.scale.y * 2 )){ self.center.y = ( minY + maxY ) * 0.5; return; }
    self.clampInTopY(    minY );
    self.clampInBottomY( maxY );
  }
  pub fn clampInArea( self : *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( checkMinMax2(     pMin,   pMax   )){ return; }
    self.clampInXRange( pMin.x, pMax.x );
    self.clampInYRange( pMin.y, pMax.y );
  }

  pub fn clampNotOnXRange( self : *Box2, xMin : f32, xMax : f32 ) void
  {
    if( checkMinMax( xMin, xMax )){ return; }
    const leftOverlap  = @abs( self.getRightX() - xMin );
    const rightOverlap = @abs( self.getLeftX()  - xMax );

    if( leftOverlap < rightOverlap ){ self.clampInLeftX(  xMin ); }
    else                            { self.clampInRightX( xMax ); }
  }
  pub fn clampNotOnYRange( self : *Box2, minY : f32, maxY : f32 ) void
  {
    if( checkMinMax( minY, maxY )){ return; }
    const topOverlap    = @abs( self.getBottomY() - minY );
    const bottomOverlap = @abs( self.getTopY()    - maxY );

    if( topOverlap < bottomOverlap ){ self.clampInTopY(    minY ); }
    else                            { self.clampInBottomY( maxY ); }
  }
  pub fn clampNotOnArea( self : *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( checkMinMax2( pMin, pMax )){ return; }
    self.clampNotOnXRange( pMin.x, pMax.x );
    self.clampNotOnYRange( pMin.y, pMax.y );
  }

  // ================ OVERLAP CHECKERS ================

  pub fn isOverlapping( self : *const Box2, other : *const Box2 ) bool
  {
    if( self.getRightX()  < other.getLeftX()   ){ return false; } // self is left of other
    if( self.getLeftX()   > other.getRightX()  ){ return false; } // self is right of other
    if( self.getBottomY() < other.getTopY()    ){ return false; } // self is above other
    if( self.getTopY()    > other.getBottomY() ){ return false; } // self is below other
    return true;
  }
  pub fn getOverlap( self : *const Box2, other : *const Box2 ) ?Vec2
  {
    if( !self.isOverlapping( other )){ return null; }
    const boxOffset = self.center.sub( other.center );
    return VecA{ .x = boxOffset.x, .y = boxOffset.y, .a = boxOffset.toAngle() };
  }

  // ================ DEBUG ================

  pub fn drawSelf( self : *const Box2, color : def.Colour ) void { def.drawRect( self.center, self.scale, .{}, color ); }
};









