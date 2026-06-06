const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const VecA  = utl.VecA;
const Angle = utl.Angle;


// NOTE : This file contains a few predefined component types and their associated systems
//        All of this is optional, and needs to be user instanciated to be usable


// ================ TRANSFORM 2D ================

pub const TransComp = struct
{
  pub const storeType : eng.CompStorePolicy = .DENSE;

  pub inline fn StoreType() type { return eng.CompStoreFactory( @This() ); }

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
  pub const storeType : eng.CompStorePolicy = .DENSE;

  pub inline fn StoreType() type { return eng.CompStoreFactory( @This() ); }

  scale   : Vec2,
  minSize : Vec2        = .{}, // Minimum screen-space size, inactive if 0
  shape   : utl.Shape2D = .RECT,
  colour  : utl.Colour  = .nWhite,

//minScale : Vec2 = .{},


  pub inline fn setScale( self : *ShapeComp, newScale : Vec2 ) void { self.scale = newScale; }
  pub inline fn getScale( self : *const ShapeComp     ) Vec2 { return self.scale; }

  // Returns the effective render scale, clamping to minSize in screen space if set
  inline fn getRenderScale( self : *const ShapeComp ) Vec2
  {
    const zoom = eng.G_ENG.camera.getZoom(); // fetch current zoom factor

    var renderScale = self.scale.mulVal( zoom );

    if( self.minSize.x > utl.EPS ) { renderScale.x = @max( renderScale.x, self.minSize.x ); }
    if( self.minSize.y > utl.EPS ) { renderScale.y = @max( renderScale.y, self.minSize.y ); }

    // Convert back to world-space scale for the draw calls
    return renderScale.mulVal( 1.0 / zoom );
  }

  pub inline fn getAABB( self : *const ShapeComp, selfPos : VecA ) Box2
  {
    if( self.shape != .RECT ){ return Box2.newPolyAABB( selfPos.toVec2(), self.scale, selfPos.a, self.shape.getEdgeCount() ); }
    else {                     return Box2.newRectAABB( selfPos.toVec2(), self.scale, selfPos.a ); }
  }

  pub fn render( self : *const ShapeComp, selfPos : VecA ) void
  {
    const p = selfPos.toVec2();
    const s = self.getRenderScale();
    const a = selfPos.a;
    const c = self.colour;

    if( self.shape == .RECT )
    {
      eng.wDraw.rect( p, s, a, c );
    }
    else if( self.shape.isStar() )
    {
      eng.wDraw.star( p, s, a, c, self.shape.getEdgeCount(), self.shape.getSkipFactor() );
    }
    else // Lines can be handled by drawPoly()
    {
      eng.wDraw.poly( p, s, a, c, self.shape.getEdgeCount() );
    }
  }
};

// ================ Hitbox 2D ================

pub const HitboxComp = struct
{
  pub const storeType : eng.CompStorePolicy = .DENSE;

  pub inline fn StoreType() type { return eng.CompStoreFactory( @This() ); }

  hitbox : Box2 = .{},


  pub inline fn setPos(   self : *HitboxComp, newPos   : VecA ) void { self.hitbox.center = newPos.toVec2(); }
  pub inline fn setScale( self : *HitboxComp, newScale : Vec2 ) void { self.hitbox.scale  = newScale;         }

  pub inline fn getPos(   self : *const HitboxComp ) VecA { return self.hitbox.center.toVecA( .{} ); }
  pub inline fn getScale( self : *const HitboxComp ) Vec2 { return self.hitbox.scale;                }

  pub inline fn isOverlapping( self : *const HitboxComp, other : *const HitboxComp ) bool
  {
    return self.hitbox.doesOverlap( other.hitbox );
  }

  pub inline fn getOverlap( self : *const HitboxComp, other : *const HitboxComp ) ?Vec2
  {
    return self.hitbox.getOverlap( other.hitbox );
  }
};


// ================ Sprite 2D ================

pub const SpriteComp = struct
{
  pub const storeType : eng.CompStorePolicy = .DENSE;

  pub inline fn StoreType() type { return eng.CompStoreFactory( @This() ); }

  sprite      : utl.Sprite,
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
  pub inline fn setScale( self : *SpriteComp, newScale : Vec2 ) void { self.sprite.scale = newScale; }
  pub inline fn render(   self : *const SpriteComp            ) void { eng.wSprite.drawSprite( &self.sprite ); }
};
