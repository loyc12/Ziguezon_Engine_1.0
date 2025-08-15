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
  return def.ray.getScreenToWorld2D( getMouseScreenPos(), def.ng.camera );
}

// ================================ SCREEN MANAGER ================================

pub const ViewManager = struct
{
  isInit : bool       = false,
  camera : def.Camera = undefined,

  pub fn init( self : *ViewManager, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing screen manager..." );

    _ = alloc; // Unused for now

    if( !self.isInit  )
    {
      self.camera = def.Camera{
        .target = def.Vec2{ .x = 0.0, .y = 0.0 },
        .offset = def.divVec2ByVal( def.DEF_SCREEN_DIMS, 2.0 ) orelse def.Vec2{ .x = 0.0, .y = 0.0 },
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

  pub fn getCameraCpy( self : *const ViewManager ) ?def.Camera
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return null;
    }
    return self.camera;
  }

  pub fn setCameraOffset( self : *ViewManager, offset : def.Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.offset = offset;
    def.log( .DEBUG, 0, @src(), "Main camera offset set to {d}:{d}", .{ offset.x, offset.y });
  }
  pub fn setCameraTarget( self : *ViewManager, target : def.Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.target = target;
    def.log( .DEBUG, 0, @src(), "Main camera target set to {d}:{d}", .{ target.x, target.y });
  }
  pub fn setCameraRotation( self : *ViewManager, rotation : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.rotation = rotation;
    def.log( .DEBUG, 0, @src(), "Main camera rotation set to {d}", .{ rotation });
  }
  pub fn setCameraZoom( self : *ViewManager, zoom : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.zoom = zoom;
    def.log( .DEBUG, 0, @src(), "Main camera zoom set to {d}", .{ zoom });
  }

  pub fn moveBy( self : *ViewManager, offset : def.Vec2 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.target = def.addVec2( self.camera.target, offset );
    def.log( .DEBUG, 0, @src(), "Main camera moved by {d}:{d}", .{ offset.x, offset.y });
  }
  pub fn zoomBy( self : *ViewManager, factor : f32 ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "No main camera initialized" );
      return;
    }
    self.camera.zoom = def.clmp( self.camera.zoom * factor, MIN_ZOOM, MAX_ZOOM );

    def.log( .DEBUG, 0, @src(), "Main camera zoom changed by {d}", .{ factor });
  }

};