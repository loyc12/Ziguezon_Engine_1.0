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


pub const ShapeComp = struct // TODO : add LODs and implement minScreenScale
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  scale  : Vec2,
  shape  : def.Geom2D = .RECT,
  colour : def.Colour = .nWhite,

//minScale : Vec2 = .{},


  pub inline fn setscale( self : *HitboxComp, newScale : Vec2 ) void { self.sprite.scale = newScale; }
  pub inline fn getscale( self : *const HitboxComp     ) Vec2 { return self.sprite.scale; }

  pub inline fn getAABB( self : *const ShapeComp, selfPos : VecA ) Box2
  {
    if( self.shape != .RECT ){ return Box2.newPolyAABB( selfPos.toVec2(), self.scale, selfPos.a, self.shape.getEdgeCount() ); }
    else {                     return Box2.newRectAABB( selfPos.toVec2(), self.scale, selfPos.a ); }
  }

  pub fn render( self : *const ShapeComp, selfPos : VecA ) void
  {
    const p = selfPos.toVec2();
    const s = self.scale;
    const a = selfPos.a;
    const c = self.colour;

  if( self.shape == .RECT )
  {
    def.drawRect( p, s, a, c );
  }
  else if( self.shape.isStar() )
  {
    def.drawStar( p, s, a, c, self.shape.getEdgeCount(), self.shape.getSkipFactor() );
  }
  else // Lines can be handled by drawPoly()
  {
    def.drawPoly( p, s, a, c, self.shape.getEdgeCount() );
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