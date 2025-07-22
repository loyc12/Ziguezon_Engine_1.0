const std    = @import( "std" );
const h      = @import( "defs" );

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
  id     : u32  = 0,    // Unique identifier for the entity
  active : bool = true, // Whether the entity is active or not

  // ================ SHAPE PROPERTIES ================

  scale  : h.vec2,                          // Scale of the entity in X and Y
  colour : h.ray.Color = h.ray.Color.white, // Colour of the entity ( used for rendering )
  shape  : e_shape     = .NONE,             // Shape of the entity

  // ================ POSITION PROPERTIES ================

  pos : h.vec2,                       // Position of the entity in 2D space
  vel : h.vec2 = .{ .x = 0, .y = 0 }, // Velocity of the entity in 2D space
  acc : h.vec2 = .{ .x = 0, .y = 0 }, // Acceleration of the entity in 2D space

  // ================ ROTATION PROPERTIES ================

  rotPos : f16 = 0, // Rotation of the entity in radians
//rotVel : f16 = 0, // Angular velocity of the entity in radians per second
//rotAcc : f16 = 0, // Angular acceleration of the entity in radians per second squared


  // ================ POSITION FUNCTIONS ================
  const nttPos = @import( "entityPos.zig" );

  // DISTANCE FUNCTIONS
  pub fn getXDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getXDistTo(    self, other ); }
  pub fn getYDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getYDistTo(    self, other ); }
  pub fn getSqrDistTo(  self : *const entity, other : *const entity ) f32 { return nttPos.getSqrDistTo(  self, other ); }
  pub fn getDistTo(     self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }
  pub fn getCartDistTo( self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }

  // POSITION ACCESSORS
  pub fn getCenter( self : *const entity ) h.vec2 { return self.pos ;}

  pub fn getLeftX(   self : *const entity ) f32 { return nttPos.getLeftX(   self ); }
  pub fn getRightX(  self : *const entity ) f32 { return nttPos.getRightX(  self ); }
  pub fn getTopY(    self : *const entity ) f32 { return nttPos.getTopY(    self ); }
  pub fn getBottomY( self : *const entity ) f32 { return nttPos.getBottomY( self ); }

  pub fn getTopLeft(     self : *const entity ) h.vec2 { return nttPos.getTopLeft(     self ); }
  pub fn getTopRight(    self : *const entity ) h.vec2 { return nttPos.getTopRight(    self ); }
  pub fn getBottomLeft(  self : *const entity ) h.vec2 { return nttPos.getBottomLeft(  self ); }
  pub fn getBottomRight( self : *const entity ) h.vec2 { return nttPos.getBottomRight( self ); }

  // POSITION SETTERS
  pub fn setCenter( self : *entity, newPos : h.vec2 ) void { self.pos = newPos; }
  pub fn setPos(    self : *entity, newPos : h.vec2 ) void { self.pos = newPos; }
  pub fn cpyEntityPos( self : *entity, other : *const entity ) void { nttPos.cpyEntityPos( self, other ); }

  pub fn setLeftX(   self : *entity, leftX   : f32 ) void { nttPos.setLeftX(   self, leftX ); }
  pub fn setRightX(  self : *entity, rightX  : f32 ) void { nttPos.setRightX(  self, rightX ); }
  pub fn setTopY(    self : *entity, topY    : f32 ) void { nttPos.setTopY(    self, topY ); }
  pub fn setBottomY( self : *entity, bottomY : f32 ) void { nttPos.setBottomY( self, bottomY ); }

  pub fn setTopLeft(     self : *entity, topLeftPos     : h.vec2 ) void { nttPos.setTopLeft(     self, topLeftPos ); }
  pub fn setTopRight(    self : *entity, topRightPos    : h.vec2 ) void { nttPos.setTopRight(    self, topRightPos ); }
  pub fn setBottomLeft(  self : *entity, bottomLeftPos  : h.vec2 ) void { nttPos.setBottomLeft(  self, bottomLeftPos ); }
  pub fn setBottomRight( self : *entity, bottomRightPos : h.vec2 ) void { nttPos.setBottomRight( self, bottomRightPos ); }

  // CLAMPING FUNCTIONS
  pub fn clampLeftX(   self : *entity, minLeftX   : f32 ) void { nttPos.clampLeftX(   self, minLeftX ); }
  pub fn clampRightX(  self : *entity, maxRightX  : f32 ) void { nttPos.clampRightX(  self, maxRightX ); }
  pub fn clampTopY(    self : *entity, minTopY    : f32 ) void { nttPos.clampTopY(    self, minTopY ); }
  pub fn clampBottomY( self : *entity, maxBottomY : f32 ) void { nttPos.clampBottomY( self, maxBottomY ); }

  pub fn clampInX(    self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampInX( self, minX, maxX ); }
  pub fn clampInY(    self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampInY( self, minY, maxY ); }
  pub fn clampInArea( self : *entity, minPos : h.vec2, maxPos : h.vec2 ) void { nttPos.clampInArea( self, minPos, maxPos ); }

  pub fn clampOnX(     self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampOnX( self, minX, maxX ); }
  pub fn clampOnY(     self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampOnY( self, minY, maxY ); }
  pub fn clampOnArea(  self : *entity, minPos : h.vec2, maxPos : h.vec2 ) void { nttPos.clampOnArea( self, minPos, maxPos ); }

  pub fn clampOnPoint(    self : *entity, point : h.vec2 ) void { nttPos.clampOnPoint( self, point ); }
  pub fn clampOnEntity(   self : *entity, other : *const entity ) void { nttPos.clampOnEntity( self, other ); }
  pub fn clampNearEntity( self : *entity, other : *const entity, maxOffset : h.vec2 ) void { nttPos.clampNearEntity( self, other, maxOffset ); }

  // RANGE FUNCTIONS
  pub fn isInRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isInRangeX( self, minX, maxX ); }
  pub fn isInRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isInRangeY( self, minY, maxY ); }
  pub fn isInRange(  self : *const entity, minPos : h.vec2, maxPos : h.vec2 ) bool { return nttPos.isInRange( self, minPos, maxPos ); }

  pub fn isOnRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isOnRangeX( self, minX, maxX ); }
  pub fn isOnRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isOnRangeY( self, minY, maxY ); }
  pub fn isOnRange(  self : *const entity, minPos : h.vec2, maxPos : h.vec2 ) bool { return nttPos.isOnRange( self, minPos, maxPos ); }

  pub fn isOnPoint(  self : *const entity, point : h.vec2 ) bool { return nttPos.isOnPoint( self, point ); }

  // COLLISION FUNCTIONS
  pub fn isOverlapping( self : *const entity, other : *const entity ) bool { return nttPos.isOverlapping( self, other ); }
  pub fn getOverlap(    self : *const entity, other : *const entity ) ?h.vec2 { return nttPos.getOverlap( self, other ); }

  // ================ RENDER FUNCTIONS ================
  const nttRdr = @import( "entityRdr.zig" );

  pub fn clampInScreen( self :       *entity ) void { nttPos.clampInScreen( self ); }
  pub fn isOnScreen(    self : *const entity ) bool { return nttRdr.isOnScreen( self ); }
  pub fn renderSelf(    self : *const entity ) void { nttRdr.renderEntity( self ); }
};



