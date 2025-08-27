const std = @import( "std" );
const def = @import( "defs" );

const Box2    = def.Box2;
const Vec2   = def.Vec2;
const Camera = def.Camera;

// ================================ DEFINITIONS ================================

pub const MIN_ZOOM : f32 = 0.5; // Closest zoom factor for the camera
pub const MAX_ZOOM : f32 = 8.0; // Furthest zoom factor for the camera

// ================================ HELPER FUNCTIONS ================================

pub inline fn getScreenWidth()  f32 { return @floatFromInt( def.ray.getScreenWidth()  ); }
pub inline fn getScreenHeight() f32 { return @floatFromInt( def.ray.getScreenHeight() ); }
pub inline fn getScreenSize() Vec2
{
  return Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), };
}

pub inline fn getHalfScreenWidth()  f32 { return getScreenWidth()  * 0.5; }
pub inline fn getHalfScreenHeight() f32 { return getScreenHeight() * 0.5; }
pub inline fn getHalfScreenSize() Vec2
{
  return Vec2{ .x = getHalfScreenWidth(), .y = getHalfScreenHeight(), };
}

pub inline fn getMouseScreenPos() Vec2 { return def.ray.getMousePosition(); }
pub inline fn getMouseWorldPos()  Vec2
{
  return def.ray.getScreenToWorld2D( getMouseScreenPos(), def.ng.camera );
}

// ================================ SCREEN MANAGER ================================

pub const ViewManager = struct
{
  isInit : bool       = false,
  camera : Camera = undefined,

  pub fn init( self : *ViewManager, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing screen manager..." );

    _ = alloc; // Unused for now

    if( !self.isInit  )
    {
      self.camera = Camera{
        .target = def.zeroRayVec2,
        .offset = def.DEF_SCREEN_DIMS.divVal( 2.0 ).?.toRayVec2(),
        .rotation = 0.0,
        .zoom = 1.0,
      };

      self.isInit = true;
      def.log( .INFO, 0, @src(), "Initialized main camera with size {d}x{d}", .{ getScreenWidth(), getScreenHeight() });
    }

    def.qlog( .INFO, 0, @src(), "Screen manager initialized\n" );
  }
  pub fn deinit( self : *ViewManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing screen manager..." );

    if( self.isInit )
    {
      self.camera = undefined;
      def.qlog( .INFO, 0, @src(), "Main camera deinitialized." );
    }

    def.qlog( .INFO, 0, @src(), "Screen manager deinitialized." );
  }

  // ================ CAMERA ACCESSORS / MUTATORS ================

  pub fn getCameraCpy( self : *const ViewManager ) ?Camera
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return null;
    }
    return self.camera;
  }

  pub fn setCameraOffset( self : *ViewManager, offset : Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.offset = offset.toRayVec2();
  }
  pub fn setCameraTarget( self : *ViewManager, target : Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.target = target.toRayVec2();
  }
  pub fn setCameraRotation( self : *ViewManager, a : def.Angle ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.rotation = a;
  }
  pub fn setCameraZoom( self : *ViewManager, zoom : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.zoom = zoom;
  }
  pub fn getCameraViewBox( self : *const ViewManager ) ?Box2
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return null;
    }

    const camView : Box2 = Box2{
      .center = Vec2{ .x = self.camera.target.x, .y = self.camera.target.y },
      .scale  = getScreenSize().divVal( 2.0 * self.camera.zoom ).?,
    };
    return camView;
  }

  pub fn moveCameraBy( self : *ViewManager, offset : Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.target = .{ .x = self.camera.target.x + offset.x, .y = self.camera.target.y + offset.y };
  }
  pub fn zoomCameraBy( self : *ViewManager, factor : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.zoom = def.clmp( self.camera.zoom * factor, MIN_ZOOM, MAX_ZOOM );
  }

  pub fn clampCameraOnArea( self : *ViewManager, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping camera on area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    var camView = self.getCameraViewBox() orelse
    {
      def.qlog( .WARN, 0, @src(), "Cannot clamp camera without a valid view box" );
      return;
    };

    camView.clampOnArea( area.getTopLeft(), area.getBottomRight() );
    self.camera.target = camView.center.toRayVec2();
  }
  pub fn clampCameraInArea( self : *ViewManager, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping camera in area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    var camView = self.getCameraViewBox() orelse
    {
      def.qlog( .WARN, 0, @src(), "Cannot clamp camera without a valid view box" );
      return;
    };

    camView.clampInArea( area.getTopLeft(), area.getBottomRight() );
    self.camera.target = camView.center.toRayVec2();
  }
};