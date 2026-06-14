const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const VecA  = utl.VecA;
const Angle = utl.Angle;


// NOTE : This file contains a few predefined component types and their associated systems
//        All of this is optional, and needs to be user instanciated to be usable


/// Basic transform component for 2D position, velocity, and acceleration.
/// `pos` uses x/y plus angle; systems should mutate this rather than storing position elsewhere.
pub const TransComp = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  pos : VecA,
  vel : VecA = .{},
  acc : VecA = .{},


  /// Integrates acceleration and velocity into position.
  /// Set `sdt` to 1.0 to apply the full expected movement for the current step.
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


/// Axis-aligned hitbox component for broad collision and overlap checks.
pub const HitboxComp = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  hitbox : Box2 = .{},


  pub inline fn setPos(   self : *HitboxComp, newPos   : VecA ) void { self.hitbox.center = newPos.toVec2(); }
  pub inline fn setScale( self : *HitboxComp, newScale : Vec2 ) void { self.hitbox.scale  = newScale;         }

  pub inline fn getPos(   self : *const HitboxComp ) VecA { return self.hitbox.center.toVecA( .{} ); }
  pub inline fn getScale( self : *const HitboxComp ) Vec2 { return self.hitbox.scale;                }

  /// Returns true when this hitbox overlaps another hitbox.
  pub inline fn isOverlapping( self : *const HitboxComp, other : *const HitboxComp ) bool
  {
    return self.hitbox.doesOverlap( other.hitbox );
  }

  /// Returns the overlap vector when two hitboxes overlap.
  pub inline fn getOverlap( self : *const HitboxComp, other : *const HitboxComp ) ?Vec2
  {
    return self.hitbox.getOverlap( other.hitbox );
  }
};


/// Render component for simple engine-drawn geometric shapes.
/// `minSize` is a screen-space clamp so distant objects can remain visible.
pub const ShapeComp = struct // TODO : add LODs and implement minScale
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  scale   : Vec2,
  minSize : Vec2        = .{}, // Minimum screen-space size, inactive if 0
  shape   : utl.Shape2D = .RECT,
  colour  : utl.Colour  = .nWhite,

//minScale : Vec2 = .{},

  pub inline fn setScale( self : *ShapeComp, newScale : Vec2 ) void { self.scale = newScale; }
  pub inline fn getScale( self : *const ShapeComp     ) Vec2 { return self.scale; }

  /// Returns the effective render scale, clamping to minSize in screen space if set.
  inline fn getRenderScale( self : *const ShapeComp ) Vec2
  {
    const zoom = eng.G_ENG.camera.getZoom(); // fetch current zoom factor

    var renderScale = self.scale.mulVal( zoom );

    if( self.minSize.x > utl.EPS ) { renderScale.x = @max( renderScale.x, self.minSize.x ); }
    if( self.minSize.y > utl.EPS ) { renderScale.y = @max( renderScale.y, self.minSize.y ); }

    // Convert back to world-space scale for the draw calls
    return renderScale.mulVal( 1.0 / zoom );
  }

  /// Builds a world-space AABB for broad-phase checks or culling.
  pub inline fn getAABB( self : *const ShapeComp, selfPos : VecA ) Box2
  {
    if( self.shape != .RECT ){ return Box2.newPolyAABB( selfPos.toVec2(), self.scale, selfPos.a, self.shape.getEdgeCount() ); }
    else {                     return Box2.newRectAABB( selfPos.toVec2(), self.scale, selfPos.a ); }
  }

  /// Draws the shape using the current engine world drawer.
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
      eng.wDraw.polyStar( p, s, a, c, self.shape.getEdgeCount(), self.shape.getSkipFactor() );
    }
    else // Lines can be handled by drawPoly()
    {
      eng.wDraw.poly( p, s, a, c, self.shape.getEdgeCount() );
    }
  }
};


/// Sprite render component with simple frame-time animation state.
pub const SpriteComp = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  sprite      : utl.Sprite,
  frameTime   : u32 = 1.0,  // How long to show each frame for
  frameElapse : u32 = 0.0,  // How long the current frame has been shown


  /// Advances animation by `frameStep` frame-time units.
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


/// Allows the parametrize emission of particles from the entity
pub const EmmiterComp = struct
{
  // TODO : implement me once the particle system exists
};
