const std  = @import( "std" );
const def  = @import( "defs" );

const Box2   = def.Box2;
const Vec2   = def.Vec2;
const VecA   = def.VecA;
const Angle  = def.Angle;

const MAX_ZOOM = 5.0;
const MIN_ZOOM = 0.2;

pub const RayCam = def.ray.Camera2D;

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

inline fn getViewFromZoom( zoom : f32  ) Vec2 { return getHalfScreenSize().mulVal( 1.0 / zoom ); }
inline fn getZoomFromView( view : Vec2 ) f32  { return getHalfScreenWidth() / ( view.x ); }


// ================================ CAMERA STRUCT ================================

pub const Cam2D = struct
{
  pos   : VecA,                // center of the camera + rotation
  zoom  : f32 = 1.0,
  view  : Vec2,

  track : ?*def.Entity = null, // entity to track ( if any )


  // ================ GENERATION ================

  pub inline fn new( pos : def.VecA, zoom : f32 ) Cam2D
  {
    var tmp = Cam2D{ .pos = pos, .zoom = zoom, .view = .{} };

    tmp.updateView();
    return tmp;
  }


  // ================ CONVERSION ================

  pub inline fn fromRayCam( rc : RayCam ) Cam2D
  {
    var tmp = Cam2D{
      .pos  = VecA{ .x = rc.target.x, .y = rc.target.y, .a = Angle{ .r = rc.rotation }},
      .zoom = rc.zoom,
      .view = .{},
    };

    tmp.updateView();
    return tmp;
  }
  pub inline fn toRayCam( self : *const Cam2D ) RayCam
  {
    var tmp : Cam2D = self.*;
    tmp.updateView();

    //def.log( .DEBUG, 0, @src(), "Converting from Cam2D ( pos: {d}:{d}, rot: {d}, zoom: {d}, view: {d}:{d} )", .{ tmp.pos.x, tmp.pos.y, tmp.pos.a.r, tmp.zoom, tmp.view.x, tmp.view.y });

    const res = RayCam{
      .target   = tmp.pos.toRayVec2(),
      .offset   = getHalfScreenSize().toRayVec2(),
      .rotation = tmp.pos.a.r,
      .zoom     = tmp.zoom,
    };

    //def.log( .DEBUG, 0, @src(), "Converted to RayCam ( target: {d}:{d}, offset: {d}:{d}, rot: {d}, zoom: {d} )", .{ res.target.x, res.target.y, res.offset.x, res.offset.y, res.rotation, res.zoom });
    return res;
  }

  pub inline fn fromViewBox( vb : Box2 ) Cam2D
  {
    return Cam2D{
      .pos  = VecA{ .x = vb.center.x, .y = vb.center.y, .a = Angle{ .r = 0.0 } },
      .zoom = getZoomFromView( vb.scale ),
      .view = vb,
    };
  }
  pub inline fn toViewBox( self : *const Cam2D ) Box2
  {
    if( !self.pos.a.isZero() ){ def.qlog( .WARN, 0, @src(), "Camera is rotated, viewbox will be inaccurate" ); }

    var tmp : Cam2D = self.*;
    tmp.updateView();

    return Box2{
      .center = tmp.pos.toVec2(),
      .scale  = tmp.view,
    };
  }

  // ================ ACCESSORS & MUTATORS ================

  pub inline fn getCenter( self : *const Cam2D ) Vec2  { return self.pos.toVec2(); }
  pub inline fn getRot(    self : *const Cam2D ) Angle { return self.pos.a; }
  pub inline fn getZoom(   self : *const Cam2D ) f32   { return self.zoom; }

  pub inline fn setCenter( self : *Cam2D, p : Vec2  ) void { self.pos.x = p.x; self.pos.y = p.y; }
  pub inline fn setRot(    self : *Cam2D, a : Angle ) void { self.pos.a = a; }
  pub inline fn setZoom(   self : *Cam2D, z : f32   ) void
  {
    self.zoom = z;

    if( self.zoom < MIN_ZOOM ) { self.zoom = MIN_ZOOM; }
    if( self.zoom > MAX_ZOOM ) { self.zoom = MAX_ZOOM; }

    self.updateView();
  }

  // ================ UPDATING ================

  pub inline fn updateView(  self : *Cam2D ) void { self.view = getViewFromZoom( self.zoom ); }
  pub inline fn updateTrack( self : *Cam2D ) void
  {
    if( self.track )| *e |
    {
      if( !e.isActive() or e.canBeDel() )
      {
        def.qlog( .WARN, 0, @src(), "Tracked entity ( ID: {d} ) either inactive or deleted : stopping tracking", .{ e.id });
        self.track = null;
        return;
      }
      self.pos = e.pos;
    }
  }

  // ================ MOVEMENT ================

  pub inline fn moveBy(  self : *Cam2D, offset       : Vec2 ) void { self.pos.x += offset.x; self.pos.y += offset.y; }
  pub inline fn moveByS( self : *Cam2D, screenOffset : Vec2 ) void
  {
    self.updateView();
    self.pos = self.pos.add( screenOffset.mulVal( 1.0 / self.zoom ).toVecA( .{} ));
  }

  pub inline fn rotBy(  self : *Cam2D, a      : Angle ) void { self.pos.a.rot( a ); }
  pub inline fn zoomBy( self : *Cam2D, factor : f32   ) void { self.setZoom( self.zoom * factor ); }

  pub fn clampOnArea( self : *Cam2D, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping Cam2D on area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    var viewBox = self.toViewBox();
    viewBox.clampOnArea( area.getTopLeft(), area.getBottomRight() );

    self.pos.x = viewBox.center.x;
    self.pos.y = viewBox.center.y;
  }
  pub fn clampInArea( self : *Cam2D, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping Cam2D in area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    var viewBox = self.toViewBox();
    viewBox.clampInArea( area.getTopLeft(), area.getBottomRight() );

    self.pos.x = viewBox.center.x;
    self.pos.y = viewBox.center.y;
  }
  pub fn clampOnPoint( self : *Cam2D, point : Vec2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping Cam2D on point ( {d}:{d} )", .{ point.x, point.y });

    var viewBox = self.toViewBox();
    viewBox.clampOnPoint( point );

    self.pos.x = viewBox.center.x;
    self.pos.y = viewBox.center.y;
  }
  pub fn clampCenterInArea( self : *Cam2D, area : Box2 ) void
  {
    def.log( .TRACE, 0, @src(), "Clamping Cam2D center in area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    self.pos.x = def.clmp( self.pos.x, area.getLeftX(), area.getRightX() );
    self.pos.y = def.clmp( self.pos.y, area.getTopY(), area.getBottomY() );
  }

};
