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

    self.vel.x += scaledHalfAcc.x * 0.5;
    self.pos.x += self.vel.x * sdt;
    self.vel.x += scaledHalfAcc.x * 0.5;

    self.vel.y += scaledHalfAcc.y * 0.5;
    self.pos.y += self.vel.y * sdt;
    self.vel.y += scaledHalfAcc.y * 0.5;

    self.vel.a = self.vel.a.rot( self.acc.a.mulVal( sdt ));
    self.pos.a = self.pos.a.rot( self.vel.a.mulVal( sdt ));

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

  baseScale : Vec2,
  hitbox    : Box2 = .{},
  angle     : Angle = .{},

  shape  : e_shape_2D = .RECT,
  colour : def.Colour = .nWhite,


  pub inline fn updateHitbox( self : *ShapeComp, newCenter : Vec2 ) void
  {
    if( self.shape != .RECT ){ self.hitbox = Box2.newPolyAABB( newCenter, self.baseScale, self.angle, self.shape.getSideCount() ); }
    else {                     self.hitbox = Box2.newRectAABB( newCenter, self.baseScale, self.angle ); }
  }

  pub inline fn getPos( self : *const ShapeComp ) VecA
  {
    return VecA.new( self.hitbox.center.x, self.hitbox.center.y, self.angle );
  }

  pub fn render( self : *const ShapeComp ) void
  {
    const p = self.hitbox.center;
    const s = self.baseScale;
    const r = self.angle;
    const c = self.colour;

    switch( self.shape )
    {
      .RECT => { def.drawRect( p, s, r, c ); },
      .HSTR => { def.drawHstr( p, s, r, c ); },
      .DSTR => { def.drawDstr( p, s, r, c ); },
      .ELLI => { def.drawElli( p, s, r, c ); },

      .RLIN => { def.drawPoly( p, s, r, c,  1 ); },
      .DLIN => { def.drawPoly( p, s, r, c,  2 ); },
      .TRIA => { def.drawPoly( p, s, r, c,  3 ); },
      .DIAM => { def.drawPoly( p, s, r, c,  4 ); },
      .PENT => { def.drawPoly( p, s, r, c,  5 ); },
      .HEXA => { def.drawPoly( p, s, r, c,  6 ); },
      .HEPT => { def.drawPoly( p, s, r, c,  7 ); },
      .OCTA => { def.drawPoly( p, s, r, c,  8 ); },
      .DECA => { def.drawPoly( p, s, r, c, 10 ); },
      .DODE => { def.drawPoly( p, s, r, c, 12 ); },
    }
  }
};



// ================ SHAPE 2D ================

pub const SpriteComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  sprite      : def.Sprite,
  frameTime   : u32 = 1.0,  // How long to show each frame for
  frameElapse : u32 = 0.0,  // How long the current frame has been shown


  pub fn updateSprite( self : *SpriteComp, frameStep : f32 ) void
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

  pub inline fn render( self : *const SpriteComp ) void
  {
    self.sprite.drawSelf();
  }
};