const std = @import( "std" );
const def = @import( "defs" );

const Box2    = def.Box2;
const Vec2   = def.Vec2;
const Cam2D = def.Cam2D;


// ================================ HELPER FUNCTIONS ================================

pub inline fn getScreenWidth()  f32 { return @floatFromInt( def.ray.getScreenWidth()  ); }
pub inline fn getScreenHeight() f32 { return @floatFromInt( def.ray.getScreenHeight() ); }
pub inline fn getScreenSize()  Vec2
{
  return Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), };
}

pub inline fn getHalfScreenWidth()  f32 { return getScreenWidth()  * 0.5; }
pub inline fn getHalfScreenHeight() f32 { return getScreenHeight() * 0.5; }
pub inline fn getHalfScreenSize()  Vec2
{
  return Vec2{ .x = getHalfScreenWidth(), .y = getHalfScreenHeight(), };
}

pub inline fn getMouseScreenPos() Vec2 { return def.ray.getMousePosition(); }
pub inline fn getMouseWorldPos()  Vec2
{
  return def.ray.getScreenToWorld2D( getMouseScreenPos(), def.ng.Cam2D );
}

// ================================ SCREEN MANAGER ================================

pub const ViewManager = struct
{
  isInit : bool       = false,
  Cam2D : Cam2D = undefined,

  pub fn init( self : *ViewManager, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing screen manager..." );

    _ = alloc; // Unused for now

    if( !self.isInit  )
    {
      self.Cam2D = Cam2D{
        .target = def.zeroRayVec2,
        .offset = def.DEF_SCREEN_DIMS.mulVal( 0.5 ).toRayVec2(),
        .rotation = 0.0,
        .zoom = 1.0,
      };

      self.isInit = true;
      def.log( .INFO, 0, @src(), "Initialized main Cam2D with size {d}x{d}", .{ getScreenWidth(), getScreenHeight() });
    }

    def.qlog( .INFO, 0, @src(), "Screen manager initialized\n" );
  }
  pub fn deinit( self : *ViewManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing screen manager..." );

    if( self.isInit )
    {
      self.Cam2D = undefined;
      def.qlog( .INFO, 0, @src(), "Main Cam2D deinitialized." );
    }

    def.qlog( .INFO, 0, @src(), "Screen manager deinitialized." );
  }

  // ================ Cam2D ACCESSORS / MUTATORS ================

  pub fn getCam2DCpy( self : *const ViewManager ) ?Cam2D
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return null;
    }
    return self.Cam2D;
  }

  pub fn setCam2DOffset( self : *ViewManager, offset : Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    self.Cam2D.offset = offset.toRayVec2();
  }
  pub fn setCam2DTarget( self : *ViewManager, target : Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    self.Cam2D.target = target.toRayVec2();
  }
  pub fn setCam2DRotation( self : *ViewManager, a : def.Angle ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    self.Cam2D.rotation = a;
  }
  pub fn setCam2DZoom( self : *ViewManager, zoom : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    self.Cam2D.zoom = zoom;
  }
  pub fn getCam2DViewBox( self : *const ViewManager ) ?Box2
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return null;
    }

    const camView : Box2 = Box2{
      .center = Vec2{ .x = self.Cam2D.target.x, .y = self.Cam2D.target.y },
      .scale  = getScreenSize().divVal( 2.0 * self.Cam2D.zoom ).?,
    };
    return camView;
  }

  pub fn moveCam2DBy( self : *ViewManager, offset : Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    self.Cam2D.target = .{ .x = self.Cam2D.target.x + offset.x, .y = self.Cam2D.target.y + offset.y };
  }
  pub fn zoomCam2DBy( self : *ViewManager, factor : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    self.Cam2D.zoom = def.clmp( self.Cam2D.zoom * factor, 1.0, 10.0 );
  }

  pub fn clampCam2DOnArea( self : *ViewManager, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping Cam2D on area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    var camView = self.getCam2DViewBox() orelse
    {
      def.qlog( .WARN, 0, @src(), "Cannot clamp Cam2D without a valid view box" );
      return;
    };

    camView.clampOnArea( area.getTopLeft(), area.getBottomRight() );
    self.Cam2D.target = camView.center.toRayVec2();
  }
  pub fn clampCam2DInArea( self : *ViewManager, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping Cam2D in area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main Cam2D initialized" );
      return;
    }
    var camView = self.getCam2DViewBox() orelse
    {
      def.qlog( .WARN, 0, @src(), "Cannot clamp Cam2D without a valid view box" );
      return;
    };

    camView.clampInArea( area.getTopLeft(), area.getBottomRight() );
    self.Cam2D.target = camView.center.toRayVec2();
  }
};