const std    = @import( "std" );
const def    = @import( "defs" );

const bdyRdr = @import( "bodyRender.zig" );

const Angle  = def.Angle;
const Box2   = def.Box2;
const Vec2   = def.Vec2;
const VecA   = def.VecA;


pub const e_bdy_shape = enum( u8 ) // TODO : move to utils
{

  RECT, // Square / Rectangle

  HSTR, // Triangle Star ( two overlaping triangles, pointing along the X axis )
  DSTR, // Diamond Star  ( two overlaping diamong,   pointing along the X axis )

  RLIN, // Radius Line ( from center to forward, scaled )
  DLIN, // Diametre Line ( from backard to forward, scaled )

  TRIA, // Triangle ( equilateral, pointing towards +X ( right ))
  DIAM, // Square / Diamond ( rhombus )
  PENT, // Pentagon  ( regular )
  HEXA, // Hexagon   ( regular )
  OCTA, // Octagon   ( regular )
  DODE, // Dodecagon ( regular )
  ELLI, // Circle / Ellipse ( aproximated via a high facet count polygon )

  pub fn getSides( self : e_bdy_shape ) u8
  {
    return switch( self )
    {
      .RECT => 4, // NOTE : do not render as Polygon, as it will show a diamond instead of a rectangle

      .HSTR => 6,
      .DSTR => 8,

      .RLIN => 1,
      .DLIN => 2,

      .TRIA => 3,
      .DIAM => 4,
      .PENT => 5,
      .HEXA => 6,
      .OCTA => 8,
      .DODE => 12,
      .ELLI => 24,
    };
  }
};

pub const e_bdy_flags = enum( u8 )
{
  DELETE  = 0b10000000, // Body is marked for deletion ( will be cleaned up at the end of the frame )
  ACTIVE  = 0b01000000, // Body is active ( overrides the following flags if set to false )
  VISIBLE = 0b00100000, // Body will be rendered
  MOBILE  = 0b00010000, // Body can change position
  SOLID   = 0b00001000, // Body can collide with other bodies
//ROUND   = 0b00000100, // Body has a round hitbox ( no AABB rotation based rescaling )
//ANIMATE = 0b00000010, //
  DEBUG   = 0b00000001, // Body will be rendered with debug information

  DEFAULT = 0b01111000, // Default flags for default bodies ( active, visible, mobile, solid )
  TO_CPY  = 0b00111111, // Flags to copy when creating a new body from params
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};

pub const Body = struct
{
  // ================ PROPERTIES ================
  id     : u32           = 0,
  flags  : def.BitField8 = def.BitField8.new( e_bdy_flags.DEFAULT ),

  // ======== TRANSFORM DATA ========
  pos    : VecA = .{}, // subsequent position. will be applied to hitbox on update
  vel    : VecA = .{},
  acc    : VecA = .{},
  scale  : Vec2 = .{},

  // ======== COLLISION DATA ========
  hitbox : Box2 = .{}, // current hitbox position and scale ( after rotation ). will be changed on update ( or when clamping )

  // ======== RENDERING DATA ======== ( DEBUG )
  colour : def.Colour  = .nWhite,
  shape  : e_bdy_shape = .RECT,

  // ======== CUSTOM BEHAVIOUR ========
  script : def.Scripter = .{},


  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Body, flag : e_bdy_flags ) bool { return self.flags.hasFlag( @intFromEnum( flag )); }

  pub inline fn setAllFlags( self : *Body, flags : u8 )                      void { self.flags.bitField = flags; }
  pub inline fn setFlag(     self : *Body, flag  : e_bdy_flags, val : bool ) void { self.flags = self.flags.setFlag( @intFromEnum( flag ), val); }
  pub inline fn addFlag(     self : *Body, flag  : e_bdy_flags )             void { self.flags = self.flags.addFlag( @intFromEnum( flag )); }
  pub inline fn delFlag(     self : *Body, flag  : e_bdy_flags )             void { self.flags = self.flags.delFlag( @intFromEnum( flag )); }

  pub inline fn canBeDel(  self : *const Body ) bool { return self.hasFlag( e_bdy_flags.DELETE  ); }
  pub inline fn isActive(  self : *const Body ) bool { return self.hasFlag( e_bdy_flags.ACTIVE  ); }
  pub inline fn isMobile(  self : *const Body ) bool { return self.hasFlag( e_bdy_flags.MOBILE  ); }
  pub inline fn isSolid(   self : *const Body ) bool { return self.hasFlag( e_bdy_flags.SOLID   ); }
  pub inline fn isVisible( self : *const Body ) bool { return self.hasFlag( e_bdy_flags.VISIBLE ); }
//pub inline fn isRound(   self : *const Body ) bool { return self.hasFlag( e_bdy_flags.ROUND   ); }
//pub inline fn isAnimate( self : *const Body ) bool { return self.hasFlag( e_bdy_flags.ANIMATE ); }
  pub inline fn viewDBG(   self : *const Body ) bool { return self.hasFlag( e_bdy_flags.DEBUG   ); }


  // ================ INITIALIZATION ================

  pub fn createBodyFromParams( params : Body ) ?Body
  {
    if( params.canBeDel() ){ def.qlog( .WARN, 0, @src(), "Params should not be a deleted body"); }

    const tmp = Body{
      .flags  = params.flags.filterField( e_bdy_flags.TO_CPY ),
      .pos    = params.pos,
      .vel    = params.vel,
      .acc    = params.acc,
      .scale  = params.scale,
      .hitbox = params.hitbox,
      .colour = params.colour,
      .shape  = params.shape,
    };

    // NOTE : init stuff here if we ever need to

    return tmp;
  }

  pub fn createBodyFromFile( filePath : []const u8 ) ?Body
  {
    _ = filePath;
    // TODO : implement me

    def.qlog( .ERROR, 0, @src(), "Body loading from file is not yet implemented");
    return null;
  }


  // ================ POSITION FUNCTIONS ================

  inline fn updatePos( self : *Body, sdt : f32 ) void
  {
    // NOTE : using velocity verlet integration ( splitting updated in two halves around the position update )
    // in order to improve stability and accuracy when using variable sdt steps

    const accX = self.acc.x * sdt;
    const accY = self.acc.y * sdt;

    self.vel.x += accX * 0.5;
    self.pos.x += self.vel.x * sdt;
    self.vel.x += accX * 0.5;

    self.vel.y += accY * 0.5;
    self.pos.y += self.vel.y * sdt;
    self.vel.y += accY * 0.5;

    self.vel.a = self.vel.a.rot( self.acc.a.mulVal( sdt ));
    self.pos.a = self.pos.a.rot( self.vel.a.mulVal( sdt ));

    self.acc.x = 0;
    self.acc.y = 0;
    self.acc.a = .{};
  }

  inline fn updatePosFromHitbox( self : *Body ) void
  {
    self.pos.x = self.hitbox.center.x;
    self.pos.y = self.hitbox.center.y;
  }
  inline fn updateHitbox( self : *Body ) void
  {
    if( self.shape != .RECT ){ self.hitbox = Box2.newPolyAABB( self.pos.toVec2(), self.scale, self.pos.a, self.shape.getSides() ); }
    else {                     self.hitbox = Box2.newRectAABB( self.pos.toVec2(), self.scale, self.pos.a                        ); }
  }

  pub fn moveSelf( self : *Body, sdt : f32 ) void
  {
    if( !self.isMobile() )
    {
      def.log( .TRACE, self.id, @src(), "Body {d} is not mobile and cannot be moved", .{ self.id });
      return;
    }
    def.log( .TRACE, self.id, @src(), "Moving Body {d} by velocity {d}:{d} with acceleration {d}:{d} over time {d}", .{ self.id, self.vel.x, self.vel.y, self.acc.x, self.acc.y, sdt });

    self.updatePos( sdt );
    self.updateHitbox();
  }


  // ======== POSITION ACCESSORS & MUTATORS ========

  pub inline fn getCenter( self : *const Body ) Vec2  { return self.pos.toVec2(); }
  pub inline fn getRot(    self : *const Body ) Angle { return self.pos.a; }

  pub inline fn setCenter( self : *Body, newPos : Vec2 ) void { self.pos = newPos.toVecA( self.pos.a ); }
  pub inline fn setRot(    self : *Body, newRot : f32  ) void { self.pos.a = newRot; }


  // ======== POS CLAMPER ( VIA HITBOX ) ========

  pub inline fn clampOnLeftX(   self : *Body, thresholdX : f32 ) void { self.hitbox.clampOnLeftX(   thresholdX ); self.updatePosFromHitbox(); }
  pub inline fn clampOnRightX(  self : *Body, thresholdX : f32 ) void { self.hitbox.clampOnRightX(  thresholdX ); self.updatePosFromHitbox(); }
  pub inline fn clampOnTopY(    self : *Body, thresholdY : f32 ) void { self.hitbox.clampOnTopY(    thresholdY ); self.updatePosFromHitbox(); }
  pub inline fn clampOnBottomY( self : *Body, thresholdY : f32 ) void { self.hitbox.clampOnBottomY( thresholdY ); self.updatePosFromHitbox(); }

  pub inline fn clampOnX(     self : *Body, xVal : f32  ) void { self.hitbox.clampOnX(  xVal ); self.updatePosFromHitbox(); }
  pub inline fn clampOnY(     self : *Body, yVal : f32  ) void { self.hitbox.clampOnY(  yVal ); self.updatePosFromHitbox(); }
  pub inline fn clampOnPoint( self : *Body, p    : Vec2 ) void { self.hitbox.clampOnPoint( p ); self.updatePosFromHitbox(); }

  pub inline fn clampOnXRange( self : *Body, xMin : f32,  xMax : f32  ) void { self.hitbox.clampOnXRange( xMin, xMax ); self.updatePosFromHitbox(); }
  pub inline fn clampOnYRange( self : *Body, yMin : f32,  yMax : f32  ) void { self.hitbox.clampOnYRange( yMin, yMax ); self.updatePosFromHitbox(); }
  pub inline fn clampOnArea(   self : *Body, pMin : Vec2, pMax : Vec2 ) void { self.hitbox.clampOnArea(   pMin, pMax ); self.updatePosFromHitbox(); }

  pub inline fn clampNotInXRange( self : *Body, xMin : f32,  xMax : f32  ) void { self.hitbox.clampNotInXRange( xMin, xMax ); self.updatePosFromHitbox(); }
  pub inline fn clampNotInYRange( self : *Body, yMin : f32,  yMax : f32  ) void { self.hitbox.clampNotInYRange( yMin, yMax ); self.updatePosFromHitbox(); }
  pub inline fn clampNotInArea(   self : *Body, pMin : Vec2, pMax : Vec2 ) void { self.hitbox.clampNotInArea(   pMin, pMax ); self.updatePosFromHitbox(); }


  pub inline fn clampInLeftX(   self : *Body, thresholdX : f32 ) void { self.hitbox.clampInLeftX(   thresholdX ); self.updatePosFromHitbox(); }
  pub inline fn clampInRightX(  self : *Body, thresholdX : f32 ) void { self.hitbox.clampInRightX(  thresholdX ); self.updatePosFromHitbox(); }
  pub inline fn clampInTopY(    self : *Body, thresholdY : f32 ) void { self.hitbox.clampInTopY(    thresholdY ); self.updatePosFromHitbox(); }
  pub inline fn clampInBottomY( self : *Body, thresholdY : f32 ) void { self.hitbox.clampInBottomY( thresholdY ); self.updatePosFromHitbox(); }

  pub inline fn clampNotOnX(     self : *Body, xVal : f32  ) void { self.hitbox.clampNotOnX(  xVal ); self.updatePosFromHitbox(); }
  pub inline fn clampNotOnY(     self : *Body, yVal : f32  ) void { self.hitbox.clampNotOnY(  yVal ); self.updatePosFromHitbox(); }
  pub inline fn clampNotOnPoint( self : *Body, p    : Vec2 ) void { self.hitbox.clampNotOnPoint( p ); self.updatePosFromHitbox(); }

  pub inline fn clampInXRange( self : *Body, xMin : f32,  xMax : f32  ) void { self.hitbox.clampInXRange( xMin, xMax ); self.updatePosFromHitbox(); }
  pub inline fn clampInYRange( self : *Body, yMin : f32,  yMax : f32  ) void { self.hitbox.clampInYRange( yMin, yMax ); self.updatePosFromHitbox(); }
  pub inline fn clampInArea(   self : *Body, pMin : Vec2, pMax : Vec2 ) void { self.hitbox.clampInArea(   pMin, pMax ); self.updatePosFromHitbox(); }

  pub inline fn clampNotOnXRange( self : *Body, xMin : f32,  xMax : f32  ) void { self.hitbox.clampNotOnXRange( xMin, xMax ); self.updatePosFromHitbox(); }
  pub inline fn clampNotOnYRange( self : *Body, yMin : f32,  yMax : f32  ) void { self.hitbox.clampNotOnYRange( yMin, yMax ); self.updatePosFromHitbox(); }
  pub inline fn clampNotOnArea(   self : *Body, pMin : Vec2, pMax : Vec2 ) void { self.hitbox.clampNotOnArea(   pMin, pMax ); self.updatePosFromHitbox(); }


  // ======== HITBOX ACCESSORS & MUTATORS ========

  pub inline fn getLeftX(   self : *const Body ) f32 { return self.hitbox.getLeftX();   }
  pub inline fn getRightX(  self : *const Body ) f32 { return self.hitbox.getRightX();  }
  pub inline fn getTopY(    self : *const Body ) f32 { return self.hitbox.getTopY();    }
  pub inline fn getBottomY( self : *const Body ) f32 { return self.hitbox.getBottomY(); }

  pub inline fn getTopLeft(     self : *const Body ) Vec2 { return self.hitbox.getTopLeft();     }
  pub inline fn getTopRight(    self : *const Body ) Vec2 { return self.hitbox.getTopRight();    }
  pub inline fn getBottomLeft(  self : *const Body ) Vec2 { return self.hitbox.getBottomLeft();  }
  pub inline fn getBottomRight( self : *const Body ) Vec2 { return self.hitbox.getBottomRight(); }


  pub inline fn setLeftX(   self : *Body, leftX   : f32 ) void { self.hitbox.center.x = def.getCenterXFromLeftX(   leftX,   self.hitbox.scale ); }
  pub inline fn setRightX(  self : *Body, rightX  : f32 ) void { self.hitbox.center.x = def.getCenterXFromRightX(  rightX,  self.hitbox.scale ); }
  pub inline fn setTopY(    self : *Body, topY    : f32 ) void { self.hitbox.center.y = def.getCenterYFromTopY(    topY,    self.hitbox.scale ); }
  pub inline fn setBottomY( self : *Body, bottomY : f32 ) void { self.hitbox.center.y = def.getCenterYFromBottomY( bottomY, self.hitbox.scale ); }

  pub inline fn setTopLeft(     self : *Body, topLeftPos     : Vec2 ) void { self.hitbox.center = def.getCenterFromTopLeft(     topLeftPos,     self.hitbox.scale ); }
  pub inline fn setTopRight(    self : *Body, topRightPos    : Vec2 ) void { self.hitbox.center = def.getCenterFromTopRight(    topRightPos,    self.hitbox.scale ); }
  pub inline fn setBottomLeft(  self : *Body, bottomLeftPos  : Vec2 ) void { self.hitbox.center = def.getCenterFromBottomLeft(  bottomLeftPos,  self.hitbox.scale ); }
  pub inline fn setBottomRight( self : *Body, bottomRightPos : Vec2 ) void { self.hitbox.center = def.getCenterFromBottomRight( bottomRightPos, self.hitbox.scale ); }


  // ======== HITBOX CHECKERS ========

  pub inline fn goesLeftOf(  self : *const Body, thresholdX : f32 ) bool { return self.hitbox.goesLeftOf(  thresholdX ); }
  pub inline fn goesRightOf( self : *const Body, thresholdX : f32 ) bool { return self.hitbox.goesRightOf( thresholdX ); }
  pub inline fn goesAbove(   self : *const Body, thresholdY : f32 ) bool { return self.hitbox.goesAbove(   thresholdY ); }
  pub inline fn goesBelow(   self : *const Body, thresholdY : f32 ) bool { return self.hitbox.goesBelow(   thresholdY ); }

  pub inline fn isOnX(      self : *const Body, xVal  : f32  ) bool { return self.hitbox.isOnX( xVal ); }
  pub inline fn isOnY(      self : *const Body, yVal  : f32  ) bool { return self.hitbox.isOnY( yVal ); }
  pub inline fn isOnPoint(  self : *const Body, p : Vec2 ) bool { return self.hitbox.isOnPoint( p ); }

  pub inline fn isOnXRange( self : *const Body, xMin : f32,  xMax : f32  ) bool { return self.hitbox.isOnXRange( xMin, xMax ); }
  pub inline fn isOnYRange( self : *const Body, yMin : f32,  yMax : f32  ) bool { return self.hitbox.isOnYRange( yMin, yMax ); }
  pub inline fn isOnArea(   self : *const Body, pMin : Vec2, pMax : Vec2 ) bool { return self.hitbox.isOnArea(   pMin, pMax ); }


  pub inline fn isLeftOf(   self : *const Body, thresholdX : f32 ) bool { return self.hitbox.isLeftOf(  thresholdX ); }
  pub inline fn isRightOf(  self : *const Body, thresholdX : f32 ) bool { return self.hitbox.isRightOf( thresholdX ); }
  pub inline fn isAbove(    self : *const Body, thresholdY : f32 ) bool { return self.hitbox.isAbove(   thresholdY ); }
  pub inline fn isBelow(    self : *const Body, thresholdY : f32 ) bool { return self.hitbox.isBelow(   thresholdY ); }

  pub inline fn isInXRange( self : *const Body, xMin : f32,  xMax : f32  ) bool { return self.hitbox.isInXRange( xMin, xMax ); }
  pub inline fn isInYRange( self : *const Body, yMin : f32,  yMax : f32  ) bool { return self.hitbox.isInYRange( yMin, yMax ); }
  pub inline fn isInArea(   self : *const Body, pMin : Vec2, pMax : Vec2 ) bool { return self.hitbox.isInArea(   pMin, pMax ); }


  // ======== HITBOX DISTANCE FUNCTIONS ========

  pub inline fn getDist(    self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getDist(    other.hitbox.center ); }
  pub inline fn getDistSqr( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getDistSqr( other.hitbox.center ); }

  pub inline fn getDistM( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getDistM( other.hitbox.center ); }
  pub inline fn getDistX( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getDistX( other.hitbox.center ); }
  pub inline fn getDistY( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getDistY( other.hitbox.center ); }

  pub inline fn getMaxLinDist( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getMaxLinDist( other.hitbox.center ); }
  pub inline fn getMinLinDist( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getMinLinDist( other.hitbox.center ); }
  pub inline fn getAvgLinDist( self : *const Body, other : *const Body ) f32 { return self.hitbox.center.getAvgLinDist( other.hitbox.center ); }


  // ================ HITBOX COLLISION FUNCTIONS ================
  // Assumes AABB hitboxes for all shapes and orientations

  const bdyCld = @import( "bodyColide.zig" );

  // COLLISION FUNCTIONS

  pub inline fn isOverlapping( self : *const Body, other : *const Body ) bool  { return bdyCld.isOverlapping( self, other ); }
  pub inline fn getOverlap(    self : *const Body, other : *const Body ) ?Vec2 { return bdyCld.getOverlap(    self, other ); }
  pub inline fn collideWith(   self :       *Body, other :       *Body ) bool  { return bdyCld.collideWith(   self, other ); }

  // ================ RENDER FUNCTIONS ================

  pub inline fn isOnScreen(    self : *const Body ) bool { return bdyRdr.isOnScreen( self ); }
  pub inline fn clampInScreen( self :       *Body ) void { bdyRdr.clampInScreen(     self ); }
  pub inline fn renderSelf(    self : *const Body ) void { bdyRdr.renderBody(        self ); }
};



