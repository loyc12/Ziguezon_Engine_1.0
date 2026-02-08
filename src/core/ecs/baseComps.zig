const std = @import( "std" );
const def = @import( "defs" );

const Box2  = def.Box2;
const Vec2  = def.Vec2;
const VecA  = def.VecA;
const Angle = def.Angle;


// NOTE : This file contains a few predefined component types and their associated systems
//        All of this is optional, and needs to be user instanciated to be usable


// ================ TRANSFORM 2D ================

pub const TransComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  pos : VecA,
  vel : VecA = .{},
  acc : VecA = .{},


  // NOTE : Set sdt to 1.0 to apply the full expected movement
  pub fn updatePos( self : *TransComp, sdt : f32 ) void
  {
    const scaledHalfAcc = self.acc.mulVal( 0.5 * sdt );

    self.vel = self.vel.add( scaledHalfAcc );
    self.pos = self.pos.add( self.vel.mulVal( sdt ));
    self.vel = self.vel.add( scaledHalfAcc );

    self.acc.x = 0;
    self.acc.y = 0;
    self.acc.a = .{};
  }
};



// ================ SHAPE 2D ================

pub const ELLIPSE_SIDE_COUNT = 24;

pub const e_shape_2D = enum( u8 ) // TODO : move to utils
{
  RECT, // Square / Rectangle
  HSTR, // Triangle Star    ( two overlaping triangles, pointing along the X axis )
  DSTR, // Diamond Star     ( two overlaping diamond )
  ELLI, // Circle / Ellipse ( aproximated via a high facet count polygon )

  RLIN, // Radius Line      ( from center to forward )
  DLIN, // Diametre Line    ( from backard to forward )
  TRIA, // Triangle         ( equilateral, pointing towards +X ( right ))
  DIAM, // Square / Diamond ( rhombus )
  PENT, // Pentagon
  HEXA, // Hexagon
  HEPT, // Heptagon
  OCTA, // Octagon
  DECA, // Decagon
  DODE, // Dodecagon

  pub fn getSideCount( self : e_shape_2D ) u8
  {
    return switch( self )
    {
      .RECT => 4, // NOTE : do not render as Polygon, as it will show a diamond instead of a rectangle
      .HSTR => 6,
      .DSTR => 8,
      .ELLI => ELLIPSE_SIDE_COUNT,

      .RLIN => 1,
      .DLIN => 2,
      .TRIA => 3,
      .DIAM => 4,
      .PENT => 5,
      .HEXA => 6,
      .OCTA => 8,
      .HEPT => 7,
      .DECA => 10,
      .DODE => 12,
    };
  }
};


pub const ShapeComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  scale  : Vec2,
  shape  : e_shape_2D = .RECT,
  colour : def.Colour = .nWhite,


  pub inline fn setscale( self : *HitboxComp, newScale : Vec2 ) void { self.sprite.scale = newScale; }
  pub inline fn getscale( self : *const HitboxComp     ) Vec2 { return self.sprite.scale; }

  pub inline fn getAABB( self : *const ShapeComp, selfPos : VecA ) Box2
  {
    if( self.shape != .RECT ){ return Box2.newPolyAABB( selfPos.toVec2(), self.scale, selfPos.a, self.shape.getSideCount() ); }
    else {                     return Box2.newRectAABB( selfPos.toVec2(), self.scale, selfPos.a ); }
  }

  pub fn render( self : *const ShapeComp, selfPos : VecA ) void
  {
    const p = selfPos.toVec2();
    const s = self.scale;
    const a = selfPos.a;
    const c = self.colour;

    switch( self.shape )
    {
      .RECT => { def.drawRect( p, s, a, c ); },
      .HSTR => { def.drawHstr( p, s, a, c ); },
      .DSTR => { def.drawDstr( p, s, a, c ); },
      .ELLI => { def.drawElli( p, s, a, c ); },

      else  => { def.drawPoly( p, s, a, c, self.shape.getSideCount() ); },
    }
  }
};

// ================ Hitbox 2D ================

pub const HitboxComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  hitbox : Box2 = .{},


  pub inline fn setPos(   self : *HitboxComp, newPos   : VecA ) void { self.sprite.pos   = newPos;   }
  pub inline fn setscale( self : *HitboxComp, newScale : Vec2 ) void { self.sprite.scale = newScale; }

  pub inline fn getPos(   self : *const HitboxComp ) VecA { return self.sprite.pos;   }
  pub inline fn getscale( self : *const HitboxComp ) Vec2 { return self.sprite.scale; }

  pub inline fn isOverlaping( self : *const HitboxComp, other : *const HitboxComp ) bool
  {
    return self.hitbox.isOverlaping( other.hitbox );
  }

  pub inline fn getOverlap( self : *const HitboxComp, other : *const HitboxComp ) ?Vec2
  {
    return self.hitbox.getOverlap( other.hitbox );
  }
};



// ================ Sprite 2D ================

pub const SpriteComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  sprite      : def.Sprite,
  frameTime   : u32 = 1.0,  // How long to show each frame for
  frameElapse : u32 = 0.0,  // How long the current frame has been shown


  pub fn updateAnimation( self : *SpriteComp, frameStep : f32 ) void
  {
    self.frameElapse += frameStep;

    if( self.frameElapse >= self.frameTime )
    {
      self.frameElapse -= self.frameTime;

      self.sprite.tickAnimation();

      // Prevent major animation delay accumulation by capping it to frameTime
      if( self.frameElapse > self.frameTime )
      {
        self.frameElapse = self.frameTime;
      }
    }
  }

  pub inline fn setPos(   self : *SpriteComp, newPos   : VecA ) void { self.sprite.pos   = newPos;   }
  pub inline fn setscale( self : *SpriteComp, newScale : Vec2 ) void { self.sprite.scale = newScale; }
  pub inline fn render(   self : *const SpriteComp            ) void { self.sprite.drawSelf();       }
};