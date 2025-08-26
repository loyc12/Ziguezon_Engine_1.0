const std  = @import( "std" );
const def  = @import( "defs" );

const Angle = def.Angle;

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
  vel    : VecR = .{},
  acc    : VecR = .{},
  scale  : Vec2 = .{},

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
  // Assumes AABB hitboxes for all shapes and orientations

  // MOVEMENT FUNCTIONS

  pub fn moveSelf( self : *Entity, sdt : f32 ) void
  {
    if( !self.isMobile() )
    {
      def.log( .TRACE, self.id, @src(), "Entity {d} is not mobile and cannot be moved", .{ self.id });
      return;
    }

    def.log( .TRACE, self.id, @src(), "Moving Entity {d} by velocity {d}:{d} with acceleration {d}:{d} over time {d}", .{ self.id, self.vel.x, self.vel.y, self.acc.x, self.acc.y, sdt });

    self.vel.x += self.acc.x * sdt;
    self.vel.y += self.acc.y * sdt;
    self.vel.r = self.vel.r.rot( self.acc.r.mulVal( sdt ));

    self.pos.x += self.vel.x * sdt;
    self.pos.y += self.vel.y * sdt;
    self.pos.r = self.pos.r.rot( self.vel.r.mulVal( sdt ));

    self.acc.x = 0;
    self.acc.y = 0;
    self.acc.r = def.Angle.zero();
  }

  // POSITION ACCESSORS

  pub inline fn getCenter( self : *const Entity ) Vec2 { return self.pos.toVec2() ;}
  pub inline fn getRot(    self : *const Entity ) Angle { return self.pos.r; }

  pub inline fn getLeftX(   self : *const Entity ) f32 { return def.getLeftX(   self.pos.toVec2(), self.scale ); }
  pub inline fn getRightX(  self : *const Entity ) f32 { return def.getRightX(  self.pos.toVec2(), self.scale ); }
  pub inline fn getTopY(    self : *const Entity ) f32 { return def.getTopY(    self.pos.toVec2(), self.scale ); }
  pub inline fn getBottomY( self : *const Entity ) f32 { return def.getBottomY( self.pos.toVec2(), self.scale ); }

  pub inline fn getTopLeft(     self : *const Entity ) Vec2 { return def.getTopLeft(     self.pos.toVec2(), self.scale ); }
  pub inline fn getTopRight(    self : *const Entity ) Vec2 { return def.getTopRight(    self.pos.toVec2(), self.scale ); }
  pub inline fn getBottomLeft(  self : *const Entity ) Vec2 { return def.getBottomLeft(  self.pos.toVec2(), self.scale ); }
  pub inline fn getBottomRight( self : *const Entity ) Vec2 { return def.getBottomRight( self.pos.toVec2(), self.scale ); }

  pub inline fn setCenter( self : *Entity, newPos : Vec2 ) void { self.pos.x = newPos.x; self.pos.y = newPos.y; }
  pub inline fn setRot(    self : *Entity, newRot : f32  ) void { self.pos.r = newRot; }

  pub inline fn setLeftX(   self : *Entity, leftX   : f32 ) void { self.pos.x = def.getCenterXFromLeftX(   leftX,   self.scale ); }
  pub inline fn setRightX(  self : *Entity, rightX  : f32 ) void { self.pos.x = def.getCenterXFromRightX(  rightX,  self.scale ); }
  pub inline fn setTopY(    self : *Entity, topY    : f32 ) void { self.pos.y = def.getCenterYFromTopY(    topY,    self.scale ); }
  pub inline fn setBottomY( self : *Entity, bottomY : f32 ) void { self.pos.y = def.getCenterYFromBottomY( bottomY, self.scale ); }

  pub inline fn setTopLeft(     self : *Entity, topLeftPos     : Vec2 ) void { self.pos = def.getCenterFromTopLeft(     topLeftPos,     self.scale ).toVecR( self.pos.r ); }
  pub inline fn setTopRight(    self : *Entity, topRightPos    : Vec2 ) void { self.pos = def.getCenterFromTopRight(    topRightPos,    self.scale ).toVecR( self.pos.r ); }
  pub inline fn setBottomLeft(  self : *Entity, bottomLeftPos  : Vec2 ) void { self.pos = def.getCenterFromBottomLeft(  bottomLeftPos,  self.scale ).toVecR( self.pos.r ); }
  pub inline fn setBottomRight( self : *Entity, bottomRightPos : Vec2 ) void { self.pos = def.getCenterFromBottomRight( bottomRightPos, self.scale ).toVecR( self.pos.r ); }

  // RANGE CHECK FUNCTIONS

  pub inline fn isLeftOfX(   self : *const Entity, xVal : f32 ) bool { return def.isLeftOfX(  self.pos.toVec2(), self.scale, xVal ); }
  pub inline fn isRightOfX(  self : *const Entity, xVal : f32 ) bool { return def.isRightOfX( self.pos.toVec2(), self.scale, xVal ); }
  pub inline fn isBelowY(    self : *const Entity, yVal : f32 ) bool { return def.isBelowY(   self.pos.toVec2(), self.scale, yVal ); }
  pub inline fn isAboveY(    self : *const Entity, yVal : f32 ) bool { return def.isAboveY(   self.pos.toVec2(), self.scale, yVal ); }

  pub inline fn isOnXVal(  self : *const Entity, xVal  : f32  ) bool { return def.isOnXVal(  self.pos.toVec2(), self.scale, xVal  ); }
  pub inline fn isOnYVal(  self : *const Entity, yVal  : f32  ) bool { return def.isOnYVal(  self.pos.toVec2(), self.scale, yVal  ); }
  pub inline fn isOnPoint( self : *const Entity, point : Vec2 ) bool { return def.isOnPoint( self.pos.toVec2(), self.scale, point ); }

  pub inline fn isOnXRange( self : *const Entity, minX   : f32,  maxX   : f32  ) bool { return def.isOnXRange( self.pos.toVec2(), self.scale, minX,   maxX   ); }
  pub inline fn isOnYRange( self : *const Entity, minY   : f32,  maxY   : f32  ) bool { return def.isOnYRange( self.pos.toVec2(), self.scale, minY,   maxY   ); }
  pub inline fn isOnRange(  self : *const Entity, minPos : Vec2, maxPos : Vec2 ) bool { return def.isOnArea(   self.pos.toVec2(), self.scale, minPos, maxPos ); }

  pub inline fn isInXRange( self : *const Entity, minX   : f32,  maxX   : f32  ) bool { return def.isInXRange( self.pos.toVec2(), self.scale, minX,   maxX   ); }
  pub inline fn isInYRange( self : *const Entity, minY   : f32,  maxY   : f32  ) bool { return def.isInYRange( self.pos.toVec2(), self.scale, minY,   maxY   ); }
  pub inline fn isInRange(  self : *const Entity, minPos : Vec2, maxPos : Vec2 ) bool { return def.isInArea(   self.pos.toVec2(), self.scale, minPos, maxPos ); }

  // CLAMPING FUNCTIONS

  pub inline fn clampLeftOfX(   self : *Entity, minLeftX   : f32 ) void { self.pos.x = def.clampLeftOfX(   self.pos.toVec2(), self.scale, minLeftX   ); }
  pub inline fn clampRighOftX(  self : *Entity, maxRightX  : f32 ) void { self.pos.x = def.clampRightOfX(  self.pos.toVec2(), self.scale, maxRightX  ); }
  pub inline fn clampBelowY(    self : *Entity, minTopY    : f32 ) void { self.pos.y = def.clampBelowY(    self.pos.toVec2(), self.scale, minTopY    ); }
  pub inline fn clampAboveY(    self : *Entity, maxBottomY : f32 ) void { self.pos.y = def.clampAboveY(    self.pos.toVec2(), self.scale, maxBottomY ); }

  pub inline fn clampOnXVal(  self : *Entity, xVal  : f32  ) void { self.pos.x = def.clampOnXVal(  self.pos.toVec2(), self.scale, xVal  ); }
  pub inline fn clampOnYVal(  self : *Entity, yVal  : f32  ) void { self.pos.y = def.clampOnYVal(  self.pos.toVec2(), self.scale, yVal  ); }
  pub inline fn clampOnPoint( self : *Entity, point : Vec2 ) void { self.pos   = def.clampOnPoint( self.pos.toVec2(), self.scale, point ).toVecR( self.pos.r ); }

  pub inline fn clampOnXRange(  self : *Entity, minX   : f32,  maxX   : f32  ) void { self.pos.x = def.clampOnXRange( self.pos.toVec2(), self.scale, minX,   maxX   ); }
  pub inline fn clampOnYRange(  self : *Entity, minY   : f32,  maxY   : f32  ) void { self.pos.y = def.clampOnYRange( self.pos.toVec2(), self.scale, minY,   maxY   ); }
  pub inline fn clampOnArea(    self : *Entity, minPos : Vec2, maxPos : Vec2 ) void { self.pos   = def.clampOnArea(   self.pos.toVec2(), self.scale, minPos, maxPos ).toVecR( self.pos.r ); }

  pub inline fn clampInXRange( self : *Entity, minX   : f32,  maxX   : f32  ) void { self.pos.x = def.clampInXRange( self.pos.toVec2(), self.scale, minX,   maxX   ); }
  pub inline fn clampInYRange( self : *Entity, minY   : f32,  maxY   : f32  ) void { self.pos.y = def.clampInYRange( self.pos.toVec2(), self.scale, minY,   maxY   ); }
  pub inline fn clampInArea(   self : *Entity, minPos : Vec2, maxPos : Vec2 ) void { self.pos   = def.clampInArea(   self.pos.toVec2(), self.scale, minPos, maxPos ).toVecR( self.pos.r ); }

  pub inline fn clampInEntity( self : *Entity, other : *const Entity ) void { self.pos = def.clampInArea(  self.pos.toVec2(), self.scale, other.getTopLeft(), other.getBottomRight() ).toVecR( self.pos.r ); }
  pub inline fn clampOnEntity( self : *Entity, other : *const Entity ) void { self.pos = def.clampOnArea(  self.pos.toVec2(), self.scale, other.getTopLeft(), other.getBottomRight() ).toVecR( self.pos.r ); }

  // ================ COLLISION FUNCTIONS ================
  // Assumes AABB hitboxes for all shapes and orientations

  const nttCld = @import( "entityColide.zig" );

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

  const nttRdr = @import( "entityRender.zig" );

  pub inline fn isOnScreen(    self : *const Entity ) bool { return nttRdr.isOnScreen( self ); }
  pub inline fn clampInScreen( self :       *Entity ) void { nttRdr.clampInScreen( self ); }
  pub inline fn renderSelf(    self : *const Entity ) void { nttRdr.renderEntity( self ); }
};



