const std    = @import( "std" );
const def    = @import( "defs" );

pub const e_shape = enum
{
  NONE, // No shape defined ( will not be rendered )
  TRIA, // Triangle ( equilateral, pointing towards -y ( up ))
  STAR, // Star ( two overlaping triangles, pointing along the y axis )
  RECT, // Square / Rectangle
  DIAM, // Square / Diamond ( rhombus )
  PENT, // Pentagon  ( regular )
  HEXA, // Hexagon   ( regular )
  OCTA, // Octagon   ( regular )
  DODE, // Dodecagon ( regular )
  CIRC, // Circle / Ellipse ( aproximated via a high facet count polygon )
};

pub const entity = struct
{
  id     : u32  = 0,    // Unique identifier for the entity
  active : bool = true, // Whether the entity is active or not

  // ================ SHAPE PROPERTIES ================

  scale  : def.Vec2,                            // Scale of the entity in X and Y
  colour : def.ray.Color = def.ray.Color.white, // Colour of the entity ( used for rendering )
  shape  : e_shape       = .NONE,               // Shape of the entity

  // ================ POSITION PROPERTIES ================

  pos : def.Vec2,                       // Position of the entity in 2D space
  vel : def.Vec2 = .{ .x = 0, .y = 0 }, // Velocity of the entity in 2D space
  acc : def.Vec2 = .{ .x = 0, .y = 0 }, // Acceleration of the entity in 2D space

  // ================ ROTATION PROPERTIES ================

  rotPos : f32 = 0, // Rotation of the entity in radians
//rotVel : f32 = 0, // Angular velocity of the entity in radians per second
//rotAcc : f32 = 0, // Angular acceleration of the entity in radians per second squared


  // ================ POSITION FUNCTIONS ================
  const nttPos = @import( "entityPos.zig" );

  // DISTANCE FUNCTIONS
  pub fn getXDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getXDistTo(    self, other ); }
  pub fn getYDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getYDistTo(    self, other ); }
  pub fn getSqrDistTo(  self : *const entity, other : *const entity ) f32 { return nttPos.getSqrDistTo(  self, other ); }
  pub fn getDistTo(     self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }
  pub fn getCartDistTo( self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }

  // POSITION ACCESSORS
  pub fn getCenter( self : *const entity ) def.Vec2 { return self.pos ;}

  pub fn getLeftX(   self : *const entity ) f32 { return nttPos.getLeftX(   self ); }
  pub fn getRightX(  self : *const entity ) f32 { return nttPos.getRightX(  self ); }
  pub fn getTopY(    self : *const entity ) f32 { return nttPos.getTopY(    self ); }
  pub fn getBottomY( self : *const entity ) f32 { return nttPos.getBottomY( self ); }

  pub fn getTopLeft(     self : *const entity ) def.Vec2 { return nttPos.getTopLeft(     self ); }
  pub fn getTopRight(    self : *const entity ) def.Vec2 { return nttPos.getTopRight(    self ); }
  pub fn getBottomLeft(  self : *const entity ) def.Vec2 { return nttPos.getBottomLeft(  self ); }
  pub fn getBottomRight( self : *const entity ) def.Vec2 { return nttPos.getBottomRight( self ); }

  // POSITION SETTERS
  pub fn setCenter( self : *entity, newPos : def.Vec2 ) void { self.pos = newPos; }
  pub fn setPos(    self : *entity, newPos : def.Vec2 ) void { self.pos = newPos; }
  pub fn cpyEntityPos( self : *entity, other : *const entity ) void { nttPos.cpyEntityPos( self, other ); }

  pub fn setLeftX(   self : *entity, leftX   : f32 ) void { nttPos.setLeftX(   self, leftX ); }
  pub fn setRightX(  self : *entity, rightX  : f32 ) void { nttPos.setRightX(  self, rightX ); }
  pub fn setTopY(    self : *entity, topY    : f32 ) void { nttPos.setTopY(    self, topY ); }
  pub fn setBottomY( self : *entity, bottomY : f32 ) void { nttPos.setBottomY( self, bottomY ); }

  pub fn setTopLeft(     self : *entity, topLeftPos     : def.Vec2 ) void { nttPos.setTopLeft(     self, topLeftPos ); }
  pub fn setTopRight(    self : *entity, topRightPos    : def.Vec2 ) void { nttPos.setTopRight(    self, topRightPos ); }
  pub fn setBottomLeft(  self : *entity, bottomLeftPos  : def.Vec2 ) void { nttPos.setBottomLeft(  self, bottomLeftPos ); }
  pub fn setBottomRight( self : *entity, bottomRightPos : def.Vec2 ) void { nttPos.setBottomRight( self, bottomRightPos ); }

  // CLAMPING FUNCTIONS
  pub fn clampLeftX(   self : *entity, minLeftX   : f32 ) void { nttPos.clampLeftX(   self, minLeftX ); }
  pub fn clampRightX(  self : *entity, maxRightX  : f32 ) void { nttPos.clampRightX(  self, maxRightX ); }
  pub fn clampTopY(    self : *entity, minTopY    : f32 ) void { nttPos.clampTopY(    self, minTopY ); }
  pub fn clampBottomY( self : *entity, maxBottomY : f32 ) void { nttPos.clampBottomY( self, maxBottomY ); }

  pub fn clampInX(    self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampInX( self, minX, maxX ); }
  pub fn clampInY(    self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampInY( self, minY, maxY ); }
  pub fn clampInArea( self : *entity, minPos : def.Vec2, maxPos : def.Vec2 ) void { nttPos.clampInArea( self, minPos, maxPos ); }

  pub fn clampOnX(     self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampOnX( self, minX, maxX ); }
  pub fn clampOnY(     self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampOnY( self, minY, maxY ); }
  pub fn clampOnArea(  self : *entity, minPos : def.Vec2, maxPos : def.Vec2 ) void { nttPos.clampOnArea( self, minPos, maxPos ); }

  pub fn clampOnPoint(    self : *entity, point : def.Vec2 ) void { nttPos.clampOnPoint( self, point ); }
  pub fn clampOnEntity(   self : *entity, other : *const entity ) void { nttPos.clampOnEntity( self, other ); }
  pub fn clampNearEntity( self : *entity, other : *const entity, maxOffset : def.Vec2 ) void { nttPos.clampNearEntity( self, other, maxOffset ); }

  // RANGE FUNCTIONS
  pub fn isInRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isInRangeX( self, minX, maxX ); }
  pub fn isInRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isInRangeY( self, minY, maxY ); }
  pub fn isInRange(  self : *const entity, minPos : def.Vec2, maxPos : def.Vec2 ) bool { return nttPos.isInRange( self, minPos, maxPos ); }

  pub fn isOnRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isOnRangeX( self, minX, maxX ); }
  pub fn isOnRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isOnRangeY( self, minY, maxY ); }
  pub fn isOnRange(  self : *const entity, minPos : def.Vec2, maxPos : def.Vec2 ) bool { return nttPos.isOnRange( self, minPos, maxPos ); }

  pub fn isOnPoint(  self : *const entity, point : def.Vec2 ) bool { return nttPos.isOnPoint( self, point ); }

  // COLLISION FUNCTIONS
  pub fn isOverlapping( self : *const entity, other : *const entity ) bool { return nttPos.isOverlapping( self, other ); }
  pub fn getOverlap(    self : *const entity, other : *const entity ) ?def.Vec2 { return nttPos.getOverlap( self, other ); }

  // ================ RENDER FUNCTIONS ================
  const nttRdr = @import( "entityRdr.zig" );

  pub fn clampInScreen( self :       *entity ) void { nttPos.clampInScreen( self ); }
  pub fn isOnScreen(    self : *const entity ) bool { return nttRdr.isOnScreen( self ); }
  pub fn renderSelf(    self : *const entity ) void { nttRdr.renderEntity( self ); }
};



