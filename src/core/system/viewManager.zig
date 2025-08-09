const std = @import( "std" );
const def = @import( "defs" );

// ================================ DEFINITIONS ================================

pub const MIN_ZOOM : f32 = 0.5; // Closest zoom factor for the camera
pub const MAX_ZOOM : f32 = 8.0; // Furthest zoom factor for the camera

// ================================ HELPER FUNCTIONS ================================

pub inline fn getScreenWidth()  f32 { return @floatFromInt( def.ray.getScreenWidth()  ); }
pub inline fn getScreenHeight() f32 { return @floatFromInt( def.ray.getScreenHeight() ); }
pub inline fn getScreenSize() def.Vec2
{
  return def.Vec2{ .x = getScreenWidth(), .y = getScreenHeight(), };
}

pub inline fn getHalfScreenWidth()  f32 { return getScreenWidth()  / 2.0; }
pub inline fn getHalfScreenHeight() f32 { return getScreenHeight() / 2.0; }
pub inline fn getHalfScreenSize() def.Vec2
{
  return def.Vec2{ .x = getHalfScreenWidth(), .y = getHalfScreenHeight(), };
}

pub inline fn getMouseScreenPos() def.Vec2 { return def.ray.getMousePosition(); }
pub inline fn getMouseWorldPos()  def.Vec2
{
  return def.ray.getScreenToWorld2D( getMouseScreenPos(), def.ngn.mainCamera );
}

// ================================ SCREEN MANAGER ================================

pub const viewManager = struct
{
  hasCamera : bool = false,
  mainCamera : def.ray.Camera2D = undefined,

  pub fn init( self : *viewManager, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing screen manager..." );

    _ = alloc; // Unused for now

    if( !self.hasCamera  )
    {
      self.mainCamera = def.ray.Camera2D{
        .target = def.Vec2{ .x = 0, .y = 0 },
        .offset = def.divVec2ByVal( def.DEF_SCREEN_DIMS, 2.0 ) orelse def.Vec2{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
      };

      self.hasCamera = true;
      def.log( .INFO, 0, @src(), "Initialized main camera with size {d}x{d}\n", .{ getScreenWidth(), getScreenHeight() });
    }

    def.qlog( .INFO, 0, @src(), "Screen manager initialized." );
  }
  pub fn deinit( self : *viewManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing screen manager..." );

    if( self.hasCamera )
    {
      self.mainCamera = undefined;
      def.qlog( .INFO, 0, @src(), "Main camera deinitialized." );
    }

    def.qlog( .INFO, 0, @src(), "Screen manager deinitialized." );
  }

  // ================ CAMERA ACCESSORS / MUTATORS ================

  pub fn getMainCamera( self : *const viewManager ) ?def.ray.Camera2D
  {
    if( !self.hasCamera )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return null;
    }
    return self.mainCamera;
  }

  pub fn setMainCameraZoom( self : *viewManager, zoom : f32 ) void
  {
    if( !self.hasCamera )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.mainCamera.zoom = zoom;
    def.log( .DEBUG, 0, @src(), "Main camera zoom set to {d}", .{ zoom });
  }

  pub fn setMainCameraTarget( self : *viewManager, target : def.Vec2 ) void
  {
    if( !self.hasCamera )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.mainCamera.target = target;
    def.log( .DEBUG, 0, @src(), "Main camera target set to {d}:{d}", .{ target.x, target.y });
  }

  pub fn setMainCameraOffset( self : *viewManager, offset : def.Vec2 ) void
  {
    if( !self.hasCamera )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.mainCamera.offset = offset;
    def.log( .DEBUG, 0, @src(), "Main camera offset set to {d}:{d}", .{ offset.x, offset.y });
  }

  pub fn setMainCameraRotation( self : *viewManager, rotation : f32 ) void
  {
    if( !self.hasCamera )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.mainCamera.rotation = rotation;
    def.log( .DEBUG, 0, @src(), "Main camera rotation set to {d}", .{ rotation });
  }

  pub fn zoomBy( self : *viewManager, factor : f32 ) void
  {
    if( !self.hasCamera )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.mainCamera.zoom = def.clmp( self.mainCamera.zoom * factor, MIN_ZOOM, MAX_ZOOM );

    def.log( .DEBUG, 0, @src(), "Main camera zoom changed by {d}", .{ factor });
  }
};