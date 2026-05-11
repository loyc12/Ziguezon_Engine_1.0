const std = @import( "std" );
const def = @import( "defs" );

const Angle = def.Angle;
const Vec2  = def.Vec2;
const VecA  = def.VecA;

// This is a simple AABB struct ( Axis-Aligned Bounding Box ) meant to ease collision checks and position clamping

// NOTE : The orientations are defined as follows :

// LEFT   => -X ( xMin side )
// RIGHT  => +X ( xMax side )
// TOP    => -Y ( yMin side )
// BOTTOM => +Y ( yMax side )

// ================================ UTIL FUNCTIONS ================================

pub inline fn isLeftOf(  valX : f64, thresholdX : f64 ) bool { return valX < thresholdX; }
pub inline fn isRightOf( valX : f64, thresholdX : f64 ) bool { return valX > thresholdX; }
pub inline fn isAbove(   valY : f64, thresholdY : f64 ) bool { return valY < thresholdY; } // NOTE : Y axis is inverted in raylib rendering
pub inline fn isBelow(   valY : f64, thresholdY : f64 ) bool { return valY > thresholdY; } // NOTE : Y axis is inverted in raylib rendering

pub inline fn getCenterXFromMinX( xMin : f64, scale : Vec2 ) f64 { return xMin + scale.x; }
pub inline fn getCenterXFromMaxX( xMax : f64, scale : Vec2 ) f64 { return xMax - scale.x; }
pub inline fn getCenterYFromMinY( yMin : f64, scale : Vec2 ) f64 { return yMin + scale.y; }
pub inline fn getCenterYFromMaxY( yMax : f64, scale : Vec2 ) f64 { return yMax - scale.y; }

// TODO : remove these legacy wrapper functions once they are deemed unused
pub inline fn getCenterXFromLeftX(   leftX   : f64, scale : Vec2 ) f64 { return getCenterXFromMinX( leftX,   scale ); }
pub inline fn getCenterXFromRightX(  rightX  : f64, scale : Vec2 ) f64 { return getCenterXFromMaxX( rightX,  scale ); }
pub inline fn getCenterYFromTopY(    topY    : f64, scale : Vec2 ) f64 { return getCenterYFromMinY( topY,    scale ); }
pub inline fn getCenterYFromBottomY( bottomY : f64, scale : Vec2 ) f64 { return getCenterYFromMaxY( bottomY, scale ); }

pub inline fn getCenterFromTopLeft(     topLeftPos     : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromMinX( topLeftPos.x,     scale ), .y = getCenterYFromMinY( topLeftPos.y,     scale ) }; }
pub inline fn getCenterFromTopRight(    topRightPos    : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromMaxX( topRightPos.x,    scale ), .y = getCenterYFromMinY( topRightPos.y,    scale ) }; }
pub inline fn getCenterFromBottomLeft(  bottomLeftPos  : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromMinX( bottomLeftPos.x,  scale ), .y = getCenterYFromMaxY( bottomLeftPos.y,  scale ) }; }
pub inline fn getCenterFromBottomRight( bottomRightPos : Vec2, scale : Vec2 ) Vec2 { return Vec2{ .x = getCenterXFromMaxX( bottomRightPos.x, scale ), .y = getCenterYFromMaxY( bottomRightPos.y, scale ) }; }

inline fn isMinMaxValid( vMin : f64, vMax : f64 ) bool
{
  if( vMin > vMax )
  {
    def.log( .ERROR, 0, @src(), "Invalid range: vMin ({d}) is greater than vMax ({d})", .{ vMin, vMax });
    return false;
  }
  return true;
}
inline fn isMinMaxValidVec2( pMin : Vec2, pMax : Vec2 ) bool
{
  if( pMin.x > pMax.x or pMin.y > pMax.y )
  {
    def.log( .ERROR, 0, @src(), "Invalid area: pMin ({d}:{d}) is greater than pMax ({d}:{d})", .{ pMin.x, pMin.y, pMax.x, pMax.y });
    return false;
  }
  return true;
}

inline fn isClampRangeValid( vMin : f64, vMax : f64, size : f64 ) bool
{
  if( vMax - vMin < size )
  {
    def.log( .ERROR, 0, @src(), "Invalid range for clamping: range ({d}) is smaller than the box size ({d})", .{ vMax - vMin, size });
    return false;
  }
  return true;
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

  // ================ INITIALIZATION METHODS ================

  pub fn newRectAABB( pos : Vec2, radii : Vec2, a : Angle ) Box2
  {
    if( a.r == 0.0 or a.r == std.math.pi or a.r == -std.math.pi )
    {
      return Box2{
        .center = pos,
        .scale  = radii,
      };
    }

    const cosOfA = @cos( a.r );
    const sinOfA = @sin( a.r );

    const newWidth  = @abs( radii.x * cosOfA ) + @abs( radii.y * sinOfA );
    const newHeight = @abs( radii.x * sinOfA ) + @abs( radii.y * cosOfA );

    return Box2{
      .center = pos,
      .scale  = Vec2{ .x = newWidth, .y = newHeight },
    };
  }

  pub fn newPolyAABB( pos : Vec2, radii : Vec2, a : Angle, sides : u16 ) Box2
  {
    if( sides < 1 )
    {
      def.qlog( .ERROR, 0, @src(), "Cannot create polygon AABB with 0 sides");
      return newRectAABB( pos, radii, a );
    }

    const sideStepAngle = Angle.newRad( def.TAU / @as( f32, @floatFromInt( sides )));
    const rP0 = Vec2.new( radii.x, 0.0 ).rot( a );

    var xMax : f64 = rP0.x;
    var xMin : f64 = rP0.x;
    var yMax : f64 = rP0.y;
    var yMin : f64 = rP0.y;


    if( sides > 2 ) // 1 == radius line, 2 == diametre line
    {
      const iterLimit = if( sides % 2 == 0 ) sides / 2 else sides; // no need to check for each two opposite vertices

      if( radii.x != radii.y ){ for( 1..iterLimit )| i | // NOTE : slower, but accounts for non isoscalar polygons
      {
        const rVertex = Vec2.fromAngleScaled( sideStepAngle.mulVal( @floatFromInt( i )), radii ).rot( a );

        if( rVertex.x > xMax ){ xMax = rVertex.x; }
        if( rVertex.x < xMin ){ xMin = rVertex.x; }
        if( rVertex.y > yMax ){ yMax = rVertex.y; }
        if( rVertex.y < yMin ){ yMin = rVertex.y; }
      }}
      else { for( 1..iterLimit )| i | // NOTE : slightly faster, but requires isoscalar polygons
      {
        const rVertex = rP0.rot( sideStepAngle.mulVal( @floatFromInt( i )));

        if( rVertex.x > xMax ){ xMax = rVertex.x; }
        if( rVertex.x < xMin ){ xMin = rVertex.x; }
        if( rVertex.y > yMax ){ yMax = rVertex.y; }
        if( rVertex.y < yMin ){ yMin = rVertex.y; }
      }}
    }

    const newWidth  = @max( @abs( xMax ), @abs( xMin ));
    const newHeight = @max( @abs( yMax ), @abs( yMin ));

    return Box2{
      .center = pos,
      .scale  = Vec2{ .x = newWidth, .y = newHeight },
    };
  }


  // ================ ACCESSORS & MUTATORS ================

  pub inline fn getMinX( self : *const Box2 ) f64 { return self.center.x - self.scale.x; }
  pub inline fn getMaxX( self : *const Box2 ) f64 { return self.center.x + self.scale.x; }
  pub inline fn getMinY( self : *const Box2 ) f64 { return self.center.y - self.scale.y; }
  pub inline fn getMaxY( self : *const Box2 ) f64 { return self.center.y + self.scale.y; }

  pub inline fn setMinX( self : *Box2, xMin : f64 ) void { self.center.x = xMin + self.scale.x; }
  pub inline fn setMaxX( self : *Box2, xMax : f64 ) void { self.center.x = xMax - self.scale.x; }
  pub inline fn setMinY( self : *Box2, yMin : f64 ) void { self.center.y = yMin + self.scale.y; }
  pub inline fn setMaxY( self : *Box2, yMax : f64 ) void { self.center.y = yMax - self.scale.y; }


  // TODO : remove these legacy wrapper functions once they are deemed unused
  pub inline fn getLeftX(   self : *const Box2 ) f64 { return self.getMinX(); }
  pub inline fn getRightX(  self : *const Box2 ) f64 { return self.getMaxX(); }
  pub inline fn getTopY(    self : *const Box2 ) f64 { return self.getMinY(); }
  pub inline fn getBottomY( self : *const Box2 ) f64 { return self.getMaxY(); }

  pub inline fn setLeftX(   self : *Box2, leftX   : f64 ) void { self.setMinX( leftX   ); }
  pub inline fn setRightX(  self : *Box2, rightX  : f64 ) void { self.setMaxX( rightX  ); }
  pub inline fn setTopY(    self : *Box2, topY    : f64 ) void { self.setMinY( topY    ); }
  pub inline fn setBottomY( self : *Box2, bottomY : f64 ) void { self.setMaxY( bottomY ); }


  pub inline fn getTopLeft(     self : *const Box2 ) Vec2 { return Vec2{ .x = self.getMinX(), .y = self.getMinY() }; }
  pub inline fn getTopRight(    self : *const Box2 ) Vec2 { return Vec2{ .x = self.getMaxX(), .y = self.getMinY() }; }
  pub inline fn getBottomLeft(  self : *const Box2 ) Vec2 { return Vec2{ .x = self.getMinX(), .y = self.getMaxY() }; }
  pub inline fn getBottomRight( self : *const Box2 ) Vec2 { return Vec2{ .x = self.getMaxX(), .y = self.getMaxY() }; }

  pub inline fn setTopLeft(     self : *Box2, topLeftPos     : Vec2 ) void { self.setMinX( topLeftPos.x     ); self.setMinY( topLeftPos.y     ); }
  pub inline fn setTopRight(    self : *Box2, topRightPos    : Vec2 ) void { self.setMaxX( topRightPos.x    ); self.setMinY( topRightPos.y    ); }
  pub inline fn setBottomLeft(  self : *Box2, bottomLeftPos  : Vec2 ) void { self.setMinX( bottomLeftPos.x  ); self.setMaxY( bottomLeftPos.y  ); }
  pub inline fn setBottomRight( self : *Box2, bottomRightPos : Vec2 ) void { self.setMaxX( bottomRightPos.x ); self.setMaxY( bottomRightPos.y ); }


  // TODO : Add "scaled" setters and getters for X, Y, and X+Y


  // ================ CHECKERS ================

  // TODO : add an EPS size range to account for fp errors
  pub inline fn isEq(   self : *const Box2, zoneBox : Box2 ) bool { return self.center.isEq(   zoneBox.center ) and self.scale.isEq(   zoneBox.scale ); }
  pub inline fn isDiff( self : *const Box2, zoneBox : Box2 ) bool { return self.center.isDiff( zoneBox.center ) or  self.scale.isDiff( zoneBox.scale ); }

  // Entirely _ of threshold
  pub inline fn isLeftOfX(  self : *const Box2, thresholdX : f64 ) bool { return isLeftOf(  self.getMaxX(), thresholdX ); }
  pub inline fn isRightOfX( self : *const Box2, thresholdX : f64 ) bool { return isRightOf( self.getMinX(), thresholdX ); }
  pub inline fn isAboveY(   self : *const Box2, thresholdY : f64 ) bool { return isAbove(   self.getMaxY(), thresholdY ); }
  pub inline fn isBelowY(   self : *const Box2, thresholdY : f64 ) bool { return isBelow(   self.getMinY(), thresholdY ); }

  // At least Partially _ of threshold
  pub inline fn goesLeftOfX(  self : *const Box2, thresholdX : f64 ) bool { return isLeftOf(  self.getMinX(), thresholdX ); }
  pub inline fn goesRightOfX( self : *const Box2, thresholdX : f64 ) bool { return isRightOf( self.getMaxX(), thresholdX ); }
  pub inline fn goesAboveY(   self : *const Box2, thresholdY : f64 ) bool { return isAbove(   self.getMinY(), thresholdY ); }
  pub inline fn goesBelowY(   self : *const Box2, thresholdY : f64 ) bool { return isBelow(   self.getMaxY(), thresholdY ); }


  // Fully Inside
  pub fn isInXRange( self : *const Box2, xMin : f64, xMax : f64 ) bool
  {
    if( !isMinMaxValid(       xMin, xMax )){                   return false; }
    if( !isClampRangeValid(   xMin, xMax, self.scale.x * 2 )){ return false; }
    if( self.goesLeftOfX(  xMin )){                         return false; }
    if( self.goesRightOfX( xMax )){                         return false; }
    return true;
  }
  pub fn isInYRange( self : *const Box2, yMin : f64, yMax : f64 ) bool
  {
    if( !isMinMaxValid(     yMin, yMax )){                   return false; }
    if( !isClampRangeValid( yMin, yMax, self.scale.y * 2 )){ return false; }
    if( self.goesAboveY( yMin )){                         return false; }
    if( self.goesBelowY( yMax )){                         return false; }
    return true;
  }
  pub inline fn isInArea( self : *const Box2, pMin : Vec2, pMax : Vec2 ) bool
  {
    if( !self.isInXRange( pMin.x, pMax.x )){ return false; }
    if( !self.isInYRange( pMin.y, pMax.y )){ return false; }
    return true;
  }
  pub inline fn isInBox2( self : *const Box2, zoneBox : *const Box2 ) bool
  {
    return self.isInArea( zoneBox.getTopLeft(), zoneBox.getBottomRight() );
  }

  // Fully Outside
  pub inline fn isOutOfX(     self : *const Box2, valX : f64  ) bool { return !self.isOnX(  valX ); }
  pub inline fn isOutOfY(     self : *const Box2, valY : f64  ) bool { return !self.isOnY(  valY ); }
  pub inline fn isOutOfPoint( self : *const Box2, p    : Vec2 ) bool { return !self.isOnPoint( p ); }

  pub fn isOutOfXRange( self : *const Box2, xMin : f64, xMax : f64 ) bool
  {
    if( !isMinMaxValid(     xMin, xMax )){ return true; }
    if( self.isLeftOfX(  xMin )){       return true; }
    if( self.isRightOfX( xMax )){       return true; }
    return false;
  }
  pub fn isOutOfYRange( self : *const Box2, yMin : f64, yMax : f64 ) bool
  {
    if( !isMinMaxValid(   yMin, yMax )){ return true; }
    if( self.isAboveY( yMin )){       return true; }
    if( self.isBelowY( yMax )){       return true; }
    return false;
  }
  pub inline fn isOutOfArea( self : *const Box2, pMin : Vec2, pMax : Vec2 ) bool
  {
    if( self.isOutOfXRange( pMin.x, pMax.x )){ return true; }
    if( self.isOutOfYRange( pMin.y, pMax.y )){ return true; }
    return false;
  }
  pub inline fn isOutOfBox2( self : *const Box2, zoneBox : *const Box2 ) bool
  {
    return self.isOutOfArea( zoneBox.getTopLeft(), zoneBox.getBottomRight() );
  }

  // Overlaps at least partially
  pub inline fn isOnX(     self : *const Box2, valX : f64  ) bool { if( self.isLeftOfX( valX ) or self.isRightOfX( valX )){ return false; } return true; }
  pub inline fn isOnY(     self : *const Box2, valY : f64  ) bool { if( self.isAboveY(  valY ) or self.isBelowY(   valY )){ return false; } return true; }
  pub inline fn isOnPoint( self : *const Box2, p    : Vec2 ) bool { if( !self.isOnX(    p.x  ) or !self.isOnY(     p.y  )){ return false; } return true; }

  pub fn isOnXRange( self : *const Box2, xMin : f64,  xMax : f64  ) bool { return !self.isOutOfXRange( xMin, xMax ); }
  pub fn isOnYRange( self : *const Box2, yMin : f64,  yMax : f64  ) bool { return !self.isOutOfYRange( yMin, yMax ); }
  pub fn isOnArea(   self : *const Box2, pMin : Vec2, pMax : Vec2 ) bool { return !self.isOutOfArea(   pMin, pMax ); }

  pub fn isOnBox2( self : *const Box2, zoneBox : *const Box2 ) bool
  {
      if( self.getMinX() > zoneBox.getMaxX() ){ return false; } // self is right of zoneBox
      if( self.getMaxX() < zoneBox.getMinX() ){ return false; } // self is left of zoneBox
      if( self.getMinY() > zoneBox.getMaxY() ){ return false; } // self is below zoneBox
      if( self.getMaxY() < zoneBox.getMinY() ){ return false; } // self is above zoneBox
      return true;
  }
  pub inline fn doesOverlap( self : *const Box2, zoneBox : *const Box2 ) bool { return self.isOnBox2( zoneBox ); }

  pub fn getOverlap( self : *const Box2, zoneBox : *const Box2 ) ?Vec2
  {
    if( !self.doesOverlap( zoneBox )){ return null; }

    return Vec2
    {
      .x = @min( self.getMaxX(), zoneBox.getMaxX() ) - @max( self.getMinX(), zoneBox.getMinX() ),
      .y = @min( self.getMaxY(), zoneBox.getMaxY() ) - @max( self.getMinY(), zoneBox.getMinY() ),
    };
  }


  // ================ CLAMPERS ================

  pub inline fn clampLeftOfX(  self : *Box2, thresholdX : f64 ) void { if( self.goesRightOfX( thresholdX )){ self.setMaxX( thresholdX ); }}
  pub inline fn clampRightOfX( self : *Box2, thresholdX : f64 ) void { if( self.goesLeftOfX(  thresholdX )){ self.setMinX( thresholdX ); }}
  pub inline fn clampAboveY(   self : *Box2, thresholdY : f64 ) void { if( self.goesBelowY(   thresholdY )){ self.setMaxY( thresholdY ); }}
  pub inline fn clampBelowY(   self : *Box2, thresholdY : f64 ) void { if( self.goesAboveY(   thresholdY )){ self.setMinY( thresholdY ); }}

  // Keep Fully Inside
  pub fn clampInXRange( self : *Box2, xMin : f64, xMax : f64 ) void
  {
    if( !isMinMaxValid(     xMin, xMax )){ return; }
    if( !isClampRangeValid( xMin, xMax, self.scale.x * 2 ))
    {
      self.center.x = ( xMin + xMax ) * 0.5;
      return;
    }
    self.clampRightOfX( xMin );
    self.clampLeftOfX(  xMax );
  }
  pub fn clampInYRange( self : *Box2, yMin : f64, yMax : f64 ) void
  {
    if( !isMinMaxValid(     yMin, yMax )){ return; }
    if( !isClampRangeValid( yMin, yMax, self.scale.y * 2 ))
    {
      self.center.y = ( yMin + yMax ) * 0.5;
      return;
    }
    self.clampBelowY( yMin );
    self.clampAboveY( yMax );
  }
  pub fn clampInArea( self : *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( !isMinMaxValidVec2( pMin,   pMax )){ return; }
    self.clampInXRange(  pMin.x, pMax.x );
    self.clampInYRange(  pMin.y, pMax.y );
  }
  pub inline fn clampInBox2( self : *const Box2, zoneBox : *const Box2 ) void
  {
    self.clampInArea( zoneBox.getTopLeft(), zoneBox.getBottomRight() );
  }

  // Keep Fully Outside
  pub inline fn clampOutOfX( self : *Box2, valX : f64 ) void
  {
    if( self.center.x < valX ){ self.clampLeftOfX(  valX ); }
    else                      { self.clampRightOfX( valX ); }
  }
  pub inline fn clampOutOfY( self : *Box2, valY : f64 ) void
  {
    if( self.center.y < valY ){ self.clampAboveY( valY ); }
    else                      { self.clampBelowY( valY ); }
  }
  pub fn clampOutOfPoint( self : *Box2, p : Vec2 ) void
  {
    self.clampOutOfX( p.x );
    self.clampOutOfY( p.y );
  }

  // TODO : validate the clampOutOf logic

  pub fn clampOutOfXRange( self : *Box2, xMin : f64, xMax : f64 ) void
  {
    if( !isMinMaxValid( xMin, xMax )){ return; }

    const depthLeft  = self.getMaxX() - xMin;
    const depthRight = xMax - self.getMinX();

    if( @min( depthLeft, depthRight ) < 0.0 ){ return; } // A gap exists ( no overlap )

    if( depthLeft < depthRight ){ self.clampLeftOfX(  xMin ); }
    else                        { self.clampRightOfX( xMax ); }
  }
  pub fn clampOutOfYRange( self : *Box2, yMin : f64, yMax : f64 ) void
  {
    if( !isMinMaxValid( yMin, yMax )){ return; }

    const depthTop    = self.getMaxY() - yMin;
    const depthBottom = yMax - self.getMinY();

    if( @min( depthTop, depthBottom ) < 0.0 ){ return; } // A gap exists ( no overlap )

    if( depthTop < depthBottom ){ self.clampAboveY( yMin ); }
    else                        { self.clampBelowY( yMax ); }
  }
  pub fn clampOutOfArea( self: *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( isMinMaxValidVec2( pMin, pMax )){ return; }

    const depthLeft   = self.getMaxX() - pMin.x;
    const depthRight  = pMax.x - self.getMinX();
    const depthTop    = self.getMaxY() - pMin.y;
    const depthBottom = pMax.y - self.getMinY();

    // Finding the shalowest depth's side
    var side : enum { left, right, top, bottom } = .left;

    var best = depthLeft;

    if( depthRight < best )
    {
      best = depthRight;
      side = .right;
    }
    if( depthTop < best )
    {
      best = depthTop;
      side = .top;
    }
    if( depthBottom < best )
    {
      best = depthBottom;
      side = .bottom;
    }

    if( best < 0.0 ){ return; } // A gap exists ( no overlap )

    switch( side )
    {
      .left   => self.clampLeftOfX(  pMin.x ),
      .right  => self.clampRightOfX( pMax.x ),
      .top    => self.clampAboveY(   pMin.y ),
      .bottom => self.clampBelowY(   pMax.y ),
    }
  }
  pub inline fn clampOutOfBox2( self : *const Box2, zoneBox : *const Box2 ) void
  {
    self.clampOutOfArea( zoneBox.getTopLeft(), zoneBox.getBottomRight() );
  }


  // Maintain overlap at least partially
  pub inline fn clampOnX( self : *Box2, valX : f64 ) void
  {
    if( self.isLeftOfX(  valX )){ self.setMaxX( valX ); }
    if( self.isRightOfX( valX )){ self.setMinX( valX ); }
  }
  pub inline fn clampOnY( self : *Box2, valY : f64 ) void
  {
    if( self.isAboveY( valY )){ self.setMaxY( valY ); }
    if( self.isBelowY( valY )){ self.setMinY( valY ); }
  }
  pub fn clampOnPoint( self : *Box2, p : Vec2 ) void
  {
    self.clampOnX( p.x );
    self.clampOnY( p.y );
  }

  pub fn clampOnXRange( self : *Box2, xMin : f64, xMax : f64 ) void
  {
    if( !isMinMaxValid(    xMin, xMax )){ return; }
    self.clampRightOfX( xMin - self.scale.x );
    self.clampLeftOfX(  xMax + self.scale.x );
  }
  pub fn clampOnYRange( self : *Box2, yMin : f64, yMax : f64 ) void
  {
    if( !isMinMaxValid(  yMin, yMax )){ return; }
    self.clampBelowY( yMin - self.scale.y );
    self.clampAboveY( yMax + self.scale.y );
  }
  pub fn clampOnArea( self : *Box2, pMin : Vec2, pMax : Vec2 ) void
  {
    if( !isMinMaxValidVec2( pMin,   pMax )){ return; }
    self.clampOnXRange(  pMin.x, pMax.x );
    self.clampOnYRange(  pMin.y, pMax.y );
  }

  pub inline fn clampOnBox2( self : *const Box2, zoneBox : *const Box2 ) void
  {
    self.clampOnArea( zoneBox.getTopLeft(), zoneBox.getBottomRight() );
  }


  // ================ DEBUG METHODS ================

  pub fn drawSelf( self : *const Box2, color : def.Colour ) void { def.drawRect( self.center, self.scale, .{}, color ); }
};









