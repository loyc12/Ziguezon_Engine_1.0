const std    = @import( "std" );
const def    = @import( "defs" );

pub const e_shape = enum
{
  NONE, // No shape defined ( will not be rendered )
  LINE, // Line ( from center to forward, scaled )
  RECT, // Square / Rectangle
  STAR, // Triangle Star ( two overlaping triangles, pointing along the y axis )
  DSTR, // Diamond Star  ( two overlaping diamong,   pointing along the y axis )
  ELLI, // Circle / Ellipse ( aproximated via a high facet count polygon )

  TRIA, // Triangle ( equilateral, pointing towards -y ( up ))
  DIAM, // Square / Diamond ( rhombus )
  PENT, // Pentagon  ( regular )
  HEXA, // Hexagon   ( regular )
  OCTA, // Octagon   ( regular )
  DODE, // Dodecagon ( regular )
};

pub const entity = struct
{
  id     : u32  = 0,
  active : bool = true,

  scale  : def.Vec2      = .{ .x = 0, .y = 0 },
  colour : def.ray.Color = def.ray.Color.white,
  shape  : e_shape       = .NONE,

  pos : def.VecR,
  vel : def.VecR = .{ .x = 0, .y = 0, .z = 0 },
  acc : def.VecR = .{ .x = 0, .y = 0, .z = 0 },


  // ================ POSITION FUNCTIONS ================

  const nttPos = @import( "entityPos.zig" );

  // DISTANCE FUNCTIONS
  pub inline fn getXDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getXDistTo(    self, other ); }
  pub inline fn getYDistTo(    self : *const entity, other : *const entity ) f32 { return nttPos.getYDistTo(    self, other ); }
  pub inline fn getSqrDistTo(  self : *const entity, other : *const entity ) f32 { return nttPos.getSqrDistTo(  self, other ); }
  pub inline fn getDistTo(     self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }
  pub inline fn getCartDistTo( self : *const entity, other : *const entity ) f32 { return nttPos.getCartDistTo( self, other ); }

  // POSITION ACCESSORS
  pub inline fn getCenter( self : *const entity ) def.Vec2 { return def.Vec2{ .x = self.pos.x, .y = self.pos.y } ;}
  pub inline fn getRot(    self : *const entity ) f32      { return self.pos.z; }

  pub inline fn getLeftX(   self : *const entity ) f32 { return nttPos.getLeftX(   self ); }
  pub inline fn getRightX(  self : *const entity ) f32 { return nttPos.getRightX(  self ); }
  pub inline fn getTopY(    self : *const entity ) f32 { return nttPos.getTopY(    self ); }
  pub inline fn getBottomY( self : *const entity ) f32 { return nttPos.getBottomY( self ); }

  pub inline fn getTopLeft(     self : *const entity ) def.Vec2 { return nttPos.getTopLeft(     self ); }
  pub inline fn getTopRight(    self : *const entity ) def.Vec2 { return nttPos.getTopRight(    self ); }
  pub inline fn getBottomLeft(  self : *const entity ) def.Vec2 { return nttPos.getBottomLeft(  self ); }
  pub inline fn getBottomRight( self : *const entity ) def.Vec2 { return nttPos.getBottomRight( self ); }

  // POSITION SETTERS
  pub inline fn setCenter( self : *entity, newPos : def.Vec2 ) void { self.pos.x = newPos.x; self.pos.y = newPos.y; }
  pub inline fn setRot(    self : *entity, newRot : f32      ) void { self.pos.z = newRot; }

  pub inline fn setPos( self : *entity, x : f32, y : f32, r : f32 ) void { self.pos.x = x; self.pos.y = y; self.pos.z = r; }
  pub inline fn setVel( self : *entity, x : f32, y : f32, r : f32 ) void { self.vel.x = x; self.vel.y = y; self.vel.z = r; }
  pub inline fn setAcc( self : *entity, x : f32, y : f32, r : f32 ) void { self.acc.x = x; self.acc.y = y; self.acc.z = r; }

  pub inline fn cpyEntityPos( self : *entity, other : *const entity ) void { nttPos.cpyEntityPos( self, other ); }
  pub inline fn cpyEntityVel( self : *entity, other : *const entity ) void { nttPos.cpyEntityVel( self, other ); }
  pub inline fn cpyEntityAcc( self : *entity, other : *const entity ) void { nttPos.cpyEntityAcc( self, other ); }

  pub inline fn setLeftX(   self : *entity, leftX   : f32 ) void { nttPos.setLeftX(   self, leftX ); }
  pub inline fn setRightX(  self : *entity, rightX  : f32 ) void { nttPos.setRightX(  self, rightX ); }
  pub inline fn setTopY(    self : *entity, topY    : f32 ) void { nttPos.setTopY(    self, topY ); }
  pub inline fn setBottomY( self : *entity, bottomY : f32 ) void { nttPos.setBottomY( self, bottomY ); }

  pub inline fn setTopLeft(     self : *entity, topLeftPos     : def.Vec2 ) void { nttPos.setTopLeft(     self, topLeftPos ); }
  pub inline fn setTopRight(    self : *entity, topRightPos    : def.Vec2 ) void { nttPos.setTopRight(    self, topRightPos ); }
  pub inline fn setBottomLeft(  self : *entity, bottomLeftPos  : def.Vec2 ) void { nttPos.setBottomLeft(  self, bottomLeftPos ); }
  pub inline fn setBottomRight( self : *entity, bottomRightPos : def.Vec2 ) void { nttPos.setBottomRight( self, bottomRightPos ); }

  // CLAMPING FUNCTIONS
  pub inline fn clampLeftX(   self : *entity, minLeftX   : f32 ) void { nttPos.clampLeftX(   self, minLeftX ); }
  pub inline fn clampRightX(  self : *entity, maxRightX  : f32 ) void { nttPos.clampRightX(  self, maxRightX ); }
  pub inline fn clampTopY(    self : *entity, minTopY    : f32 ) void { nttPos.clampTopY(    self, minTopY ); }
  pub inline fn clampBottomY( self : *entity, maxBottomY : f32 ) void { nttPos.clampBottomY( self, maxBottomY ); }

  pub inline fn clampInX(    self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampInX( self, minX, maxX ); }
  pub inline fn clampInY(    self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampInY( self, minY, maxY ); }
  pub inline fn clampInArea( self : *entity, minPos : def.Vec2, maxPos : def.Vec2 ) void { nttPos.clampInArea( self, minPos, maxPos ); }

  pub inline fn clampOnX(     self : *entity, minX : f32, maxX : f32 ) void { nttPos.clampOnX( self, minX, maxX ); }
  pub inline fn clampOnY(     self : *entity, minY : f32, maxY : f32 ) void { nttPos.clampOnY( self, minY, maxY ); }
  pub inline fn clampOnArea(  self : *entity, minPos : def.Vec2, maxPos : def.Vec2 ) void { nttPos.clampOnArea( self, minPos, maxPos ); }

  pub inline fn clampOnPoint(    self : *entity, point : def.Vec2 ) void { nttPos.clampOnPoint( self, point ); }
  pub inline fn clampOnEntity(   self : *entity, other : *const entity ) void { nttPos.clampOnEntity( self, other ); }
  pub inline fn clampNearEntity( self : *entity, other : *const entity, maxOffset : def.Vec2 ) void { nttPos.clampNearEntity( self, other, maxOffset ); }

  // RANGE FUNCTIONS
  pub inline fn isInRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isInRangeX( self, minX, maxX ); }
  pub inline fn isInRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isInRangeY( self, minY, maxY ); }
  pub inline fn isInRange(  self : *const entity, minPos : def.Vec2, maxPos : def.Vec2 ) bool { return nttPos.isInRange( self, minPos, maxPos ); }

  pub inline fn isOnRangeX( self : *const entity, minX : f32, maxX : f32 ) bool { return nttPos.isOnRangeX( self, minX, maxX ); }
  pub inline fn isOnRangeY( self : *const entity, minY : f32, maxY : f32 ) bool { return nttPos.isOnRangeY( self, minY, maxY ); }
  pub inline fn isOnRange(  self : *const entity, minPos : def.Vec2, maxPos : def.Vec2 ) bool { return nttPos.isOnRange( self, minPos, maxPos ); }

  pub inline fn isOnPoint(  self : *const entity, point : def.Vec2 ) bool { return nttPos.isOnPoint( self, point ); }

  // COLLISION FUNCTIONS
  pub inline fn isOverlapping( self : *const entity, other : *const entity ) bool   { return nttPos.isOverlapping( self, other ); }
  pub inline fn getOverlap(    self : *const entity, other : *const entity ) ?def.Vec2 { return nttPos.getOverlap( self, other ); }


  // ================ RENDER FUNCTIONS ================

  const nttRdr = @import( "entityRdr.zig" );

  pub inline fn clampInScreen( self :       *entity ) void { nttPos.clampInScreen( self ); }
  pub inline fn isOnScreen(    self : *const entity ) bool { return nttRdr.isOnScreen( self ); }
  pub inline fn renderSelf(    self : *const entity ) void { nttRdr.renderEntity( self ); }
};



