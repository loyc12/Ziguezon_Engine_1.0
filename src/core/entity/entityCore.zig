const std    = @import( "std" );
const h      = @import( "../../headers.zig" );

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

  // ================ POSITION FUNCTIONS ================
  const nttPos = @import( "entityPos.zig" );

  pub fn getXDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getXDistTo(    self, other ); }
  pub fn getYDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getYDistTo(    self, other ); }
  pub fn getSqrDistTo(  self : *const entity, other : *const entity ) f32 { return nttPos.getSqrDistTo(  self, other ); }
  pub fn getDistTo(     self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }
  pub fn getCartDistTo( self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }

  pub fn getLeftSide(   self : *const entity ) f32 { return nttPos.getLeftSide(   self ); }
  pub fn getRightSide(  self : *const entity ) f32 { return nttPos.getRightSide(  self ); }
  pub fn getTopSide(    self : *const entity ) f32 { return nttPos.getTopSide(    self ); }
  pub fn getBottomSide( self : *const entity ) f32 { return nttPos.getBottomSide( self ); }

  pub fn getTopLeft(     self : *const entity ) h.vec2 { return nttPos.getTopLeft(     self ); }
  pub fn getTopRight(    self : *const entity ) h.vec2 { return nttPos.getTopRight(    self ); }
  pub fn getBottomLeft(  self : *const entity ) h.vec2 { return nttPos.getBottomLeft(  self ); }
  pub fn getBottomRight( self : *const entity ) h.vec2 { return nttPos.getBottomRight( self ); }

  pub fn setLeftSide(   self : *entity, newLeftSide   : f32 ) void { nttPos.setLeftSide(   self, newLeftSide ); }
  pub fn setRightSide(  self : *entity, newRightSide  : f32 ) void { nttPos.setRightSide(  self, newRightSide ); }
  pub fn setTopSide(    self : *entity, newTopSide    : f32 ) void { nttPos.setTopSide(    self, newTopSide ); }
  pub fn setBottomSide( self : *entity, newBottomSide : f32 ) void { nttPos.setBottomSide( self, newBottomSide ); }

  pub fn setTopLeft(     self : *entity, newTopLeft     : h.vec2 ) void { nttPos.setTopLeft(     self, newTopLeft ); }
  pub fn setTopRight(    self : *entity, newTopRight    : h.vec2 ) void { nttPos.setTopRight(    self, newTopRight ); }
  pub fn setBottomLeft(  self : *entity, newBottomLeft  : h.vec2 ) void { nttPos.setBottomLeft(  self, newBottomLeft ); }
  pub fn setBottomRight( self : *entity, newBottomRight : h.vec2 ) void { nttPos.setBottomRight( self, newBottomRight ); }

  pub fn clampLeftSide(   self : *entity, minLeftSide   : f32 ) void { nttPos.clampLeftSide(   self, minLeftSide ); }
  pub fn clampRightSide(  self : *entity, maxRightSide  : f32 ) void { nttPos.clampRightSide(  self, maxRightSide ); }
  pub fn clampTopSide(    self : *entity, minTopSide    : f32 ) void { nttPos.clampTopSide(    self, minTopSide ); }
  pub fn clampBottomSide( self : *entity, maxBottomSide : f32 ) void { nttPos.clampBottomSide( self, maxBottomSide ); }

  pub fn clampInX(    self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampInX( self, minX, maxX ); }
  pub fn clampInY(    self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampInY( self, minY, maxY ); }
  pub fn clampInArea( self : *entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) void { nttPos.clampInArea( self, minX, maxX, minY, maxY ); }

//pub fn clampOnX(    self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampOnX( self, minX, maxX ); }
//pub fn clampOnY(    self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampOnY( self, minY, maxY ); }
//pub fn clampOnArea( self : *entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) void { nttPos.clampOnArea( self, minX, maxX, minY, maxY ); }

  pub fn isInRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isInRangeX( self, minX, maxX ); }
  pub fn isInRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isInRangeY( self, minY, maxY ); }
  pub fn isInRange(  self : *const entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) bool { return nttPos.isInRange( self, minX, maxX, minY, maxY ); }

  pub fn isOnRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isOnRangeX( self, minX, maxX ); }
  pub fn isOnRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isOnRangeY( self, minY, maxY ); }
  pub fn isOnRange(  self : *const entity, minX : f32, maxX : f32, minY : f32, maxY : f32 ) bool { return nttPos.isOnRange( self, minX, maxX, minY, maxY ); }

  pub fn getOverlap( self : *const entity, other : *const entity ) ?h.vec2 { return nttPos.getOverlap( self, other ); }

  // ================ RENDER FUNCTIONS ================
  const nttRdr = @import( "entityRdr.zig" );

  pub fn clampInScreen( self :       *entity ) void { nttPos.clampInScreen( self ); }
  pub fn isOnScreen(    self : *const entity ) bool { return nttRdr.isOnScreen( self ); }
  pub fn renderSelf(    self : *const entity ) void { nttRdr.renderEntity( self ); }
};



