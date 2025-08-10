const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const VecR = def.VecR;

pub const e_ntt_shape = enum
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

pub const e_ntt_flags = enum( u8 )
{
  DELETE  = 0b10000000, // Entity is marked for deletion ( will be cleaned up at the end of the frame )
  ACTIVE  = 0b01000000, // Entity is active ( overrides the following flags if set to false )
  VISIBLE = 0b00100000, // Entity will be rendered
  MOBILE  = 0b00010000, // Entity can change position
  SOLID   = 0b00001000, // Entity can collide with other entities
//TRIGGER = 0b00000100, // Entity can trigger events
//ANIMATE = 0b00000010, // Entity has an animation
  DEBUG   = 0b00000001, // Entity will be rendered with debug information

  DEFAULT = 0b01111000, // Default flags for default entities ( active, visible, mobile, solid )
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};

pub const Entity = struct
{
  id     : u32  = 0,
  flags  : u8   = @intFromEnum( e_ntt_flags.DEFAULT ),
  pos    : VecR,
  vel    : VecR = .{ .x = 0, .y = 0, .z = 0 },
  acc    : VecR = .{ .x = 0, .y = 0, .z = 0 },
  scale  : Vec2 = .{ .x = 0, .y = 0 },

  colour : def.Colour = def.Colour.white,
  shape  : e_ntt_shape   = .NONE,


  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Entity, flag : e_ntt_flags ) bool { return ( self.flags & @intFromEnum( flag )) != 0; }

  pub inline fn setAllFlags( self : *Entity, flags : u8          ) void { self.flags  =  flags; }
  pub inline fn addFlag(     self : *Entity, flag  : e_ntt_flags ) void { self.flags |=  @intFromEnum( flag ); }
  pub inline fn delFlag(     self : *Entity, flag  : e_ntt_flags ) void { self.flags &= ~@intFromEnum( flag ); }
  pub inline fn setFlag(     self : *Entity, flag  : e_ntt_flags, value : bool ) void
  {
    if( value ){ self.addFlag( flag ); } else { self.delFlag( flag ); }
  }

  pub inline fn canBeDel(  self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.DELETE ); }
  pub inline fn isActive(  self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.ACTIVE  );}
  pub inline fn isMobile(  self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.MOBILE  ); }
  pub inline fn isSolid(   self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.SOLID   ); }
  pub inline fn isVisible( self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.VISIBLE ); }
//pub inline fn isTrigger( self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.TRIGGER ); }
//pub inline fn isAnimate( self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.ANIMATE ); }
  pub inline fn showDBG(   self : *const Entity ) bool { return self.hasFlag( e_ntt_flags.DEBUG   ); }


  // ================ POSITION FUNCTIONS ================

  const nttPos = @import( "entityPos.zig" );

  // POSITION ACCESSORS
  pub inline fn getCenter( self : *const Entity ) Vec2 { return Vec2{ .x = self.pos.x, .y = self.pos.y } ;}
  pub inline fn getRot(    self : *const Entity ) f32  { return self.pos.z; }

  pub inline fn getLeftX(   self : *const Entity ) f32 { return nttPos.getLeftX(   self ); }
  pub inline fn getRightX(  self : *const Entity ) f32 { return nttPos.getRightX(  self ); }
  pub inline fn getTopY(    self : *const Entity ) f32 { return nttPos.getTopY(    self ); }
  pub inline fn getBottomY( self : *const Entity ) f32 { return nttPos.getBottomY( self ); }

  pub inline fn getTopLeft(     self : *const Entity ) Vec2 { return nttPos.getTopLeft(     self ); }
  pub inline fn getTopRight(    self : *const Entity ) Vec2 { return nttPos.getTopRight(    self ); }
  pub inline fn getBottomLeft(  self : *const Entity ) Vec2 { return nttPos.getBottomLeft(  self ); }
  pub inline fn getBottomRight( self : *const Entity ) Vec2 { return nttPos.getBottomRight( self ); }

  // POSITION SETTERS
  pub inline fn setCenter( self : *Entity, newPos : Vec2 ) void { self.pos.x = newPos.x; self.pos.y = newPos.y; }
  pub inline fn setRot(    self : *Entity, newRot : f32  ) void { self.pos.z = newRot; }

  pub inline fn setPos( self : *Entity, x : f32, y : f32, r : f32 ) void { self.pos.x = x; self.pos.y = y; self.pos.z = r; }
  pub inline fn setVel( self : *Entity, x : f32, y : f32, r : f32 ) void { self.vel.x = x; self.vel.y = y; self.vel.z = r; }
  pub inline fn setAcc( self : *Entity, x : f32, y : f32, r : f32 ) void { self.acc.x = x; self.acc.y = y; self.acc.z = r; }

  pub inline fn cpyEntityPos( self : *Entity, other : *const Entity ) void { nttPos.cpyEntityPos( self, other ); }
  pub inline fn cpyEntityVel( self : *Entity, other : *const Entity ) void { nttPos.cpyEntityVel( self, other ); }
  pub inline fn cpyEntityAcc( self : *Entity, other : *const Entity ) void { nttPos.cpyEntityAcc( self, other ); }

  pub inline fn setLeftX(   self : *Entity, leftX   : f32 ) void { nttPos.setLeftX(   self, leftX ); }
  pub inline fn setRightX(  self : *Entity, rightX  : f32 ) void { nttPos.setRightX(  self, rightX ); }
  pub inline fn setTopY(    self : *Entity, topY    : f32 ) void { nttPos.setTopY(    self, topY ); }
  pub inline fn setBottomY( self : *Entity, bottomY : f32 ) void { nttPos.setBottomY( self, bottomY ); }

  pub inline fn setTopLeft(     self : *Entity, topLeftPos     : Vec2 ) void { nttPos.setTopLeft(     self, topLeftPos ); }
  pub inline fn setTopRight(    self : *Entity, topRightPos    : Vec2 ) void { nttPos.setTopRight(    self, topRightPos ); }
  pub inline fn setBottomLeft(  self : *Entity, bottomLeftPos  : Vec2 ) void { nttPos.setBottomLeft(  self, bottomLeftPos ); }
  pub inline fn setBottomRight( self : *Entity, bottomRightPos : Vec2 ) void { nttPos.setBottomRight( self, bottomRightPos ); }

  // CLAMPING FUNCTIONS
  pub inline fn clampLeftX(   self : *Entity, minLeftX   : f32 ) void { nttPos.clampLeftX(   self, minLeftX ); }
  pub inline fn clampRightX(  self : *Entity, maxRightX  : f32 ) void { nttPos.clampRightX(  self, maxRightX ); }
  pub inline fn clampTopY(    self : *Entity, minTopY    : f32 ) void { nttPos.clampTopY(    self, minTopY ); }
  pub inline fn clampBottomY( self : *Entity, maxBottomY : f32 ) void { nttPos.clampBottomY( self, maxBottomY ); }

  pub inline fn clampInX(    self : *Entity, minX   : f32,  maxX   : f32  ) void { nttPos.clampInX(    self, minX, maxX ); }
  pub inline fn clampInY(    self : *Entity, minY   : f32,  maxY   : f32  ) void { nttPos.clampInY(    self, minY, maxY ); }
  pub inline fn clampInArea( self : *Entity, minPos : Vec2, maxPos : Vec2 ) void { nttPos.clampInArea( self, minPos, maxPos ); }

  pub inline fn clampOnX(     self : *Entity, minX   : f32,  maxX   : f32  ) void { nttPos.clampOnX(    self, minX, maxX ); }
  pub inline fn clampOnY(     self : *Entity, minY   : f32,  maxY   : f32  ) void { nttPos.clampOnY(    self, minY, maxY ); }
  pub inline fn clampOnArea(  self : *Entity, minPos : Vec2, maxPos : Vec2 ) void { nttPos.clampOnArea( self, minPos, maxPos ); }

  pub inline fn clampOnPoint(    self : *Entity, point : Vec2 ) void { nttPos.clampOnPoint( self, point ); }
  pub inline fn clampOnEntity(   self : *Entity, other : *const Entity ) void { nttPos.clampOnEntity( self, other ); }
  pub inline fn clampNearEntity( self : *Entity, other : *const Entity, maxOffset : Vec2 ) void { nttPos.clampNearEntity( self, other, maxOffset ); }

  // RANGE FUNCTIONS
  pub inline fn isInRangeX( self : *const Entity, minX   : f32,  maxX   : f32  ) bool { return nttPos.isInRangeX( self, minX, maxX ); }
  pub inline fn isInRangeY( self : *const Entity, minY   : f32,  maxY   : f32  ) bool { return nttPos.isInRangeY( self, minY, maxY ); }
  pub inline fn isInRange(  self : *const Entity, minPos : Vec2, maxPos : Vec2 ) bool { return nttPos.isInRange(  self, minPos, maxPos ); }

  pub inline fn isOnRangeX( self : *const Entity, minX   : f32,  maxX   : f32  ) bool { return nttPos.isOnRangeX( self, minX, maxX ); }
  pub inline fn isOnRangeY( self : *const Entity, minY   : f32,  maxY   : f32  ) bool { return nttPos.isOnRangeY( self, minY, maxY ); }
  pub inline fn isOnRange(  self : *const Entity, minPos : Vec2, maxPos : Vec2 ) bool { return nttPos.isOnRange(  self, minPos, maxPos ); }

  pub inline fn isOnPoint( self : *const Entity, point : Vec2 ) bool { return nttPos.isOnPoint( self, point ); }

  // MOVEMENT FUNCTIONS
  pub inline fn moveSelf( self : *Entity, sdt : f32 ) void { nttPos.moveSelf( self, sdt ); }

  // ================ COLLISION FUNCTIONS ================

  const nttCld = @import( "entityCld.zig" );

  // DISTANCE FUNCTIONS
  pub inline fn getXDistTo(    self : *const Entity, other : *const Entity ) f32 { return nttCld.getXDistTo(    self, other ); }
  pub inline fn getYDistTo(    self : *const Entity, other : *const Entity ) f32 { return nttCld.getYDistTo(    self, other ); }
  pub inline fn getSqrDistTo(  self : *const Entity, other : *const Entity ) f32 { return nttCld.getSqrDistTo(  self, other ); }
  pub inline fn getDistTo(     self : *const Entity, other : *const Entity ) f32 { return nttCld.getCartDistTo( self, other ); }
  pub inline fn getCartDistTo( self : *const Entity, other : *const Entity ) f32 { return nttCld.getCartDistTo( self, other ); }

  // COLLISION FUNCTIONS
  pub inline fn isOverlapping( self : *const Entity, other : *const Entity ) bool  { return nttCld.isOverlapping( self, other ); }
  pub inline fn getOverlap(    self : *const Entity, other : *const Entity ) ?Vec2 { return nttCld.getOverlap(    self, other ); }
  pub inline fn collideWith(   self :       *Entity, other :       *Entity ) bool  { return nttCld.collideWith( self, other ); }

  // ================ RENDER FUNCTIONS ================

  const nttRdr = @import( "entityRdr.zig" );

  pub inline fn isOnScreen(    self : *const Entity ) bool { return nttRdr.isOnScreen( self ); }
  pub inline fn clampInScreen( self :       *Entity ) void { nttPos.clampInScreen( self ); }
  pub inline fn renderSelf(    self : *const Entity ) void { nttRdr.renderEntity( self ); }
};



