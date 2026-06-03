const utl = @import( "utils" );
const scr = @import( "screener.zig" );

const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const VecA  = utl.VecA;
const Angle = utl.Angle;


// ================================ CAMERA STRUCT ================================

// Generic 2D camera state. This struct intentionally does not import engine code
// or raylib camera types; engine/world rendering semantics live in WorldCam.

pub const Cam2 = struct
{
  pos   : VecA = .{}, // center of the camera + rotation
  zoom  : f64  = 1.0,
  view  : Vec2 = .{},


  // ================ GENERATION ================

  pub inline fn new( pos : utl.VecA, zoom : f64 ) Cam2
  {
    var tmp = Cam2{ .pos = pos, .zoom = zoom, .view = .{} };

    tmp.updateView();
    return tmp;
  }


  // ================ UPDATING ================

  pub inline fn updateView(  self : *Cam2 ) void { self.view = scr.getViewFromZoom( self.zoom ); }


  // ================ CONVERSION ================

  pub inline fn fromViewBox( vb : Box2 ) Cam2
  {
    return Cam2{
      .pos  = VecA{ .x = vb.center.x, .y = vb.center.y, .a = Angle{ .r = 0.0 } },
      .zoom = scr.getZoomFromView( vb.scale ),
      .view = vb.scale,
    };
  }
  pub inline fn toViewBox( self : *const Cam2 ) Box2
  {
    var tmp : Cam2 = self.*;
    tmp.updateView();

    return Box2{
      .center = tmp.pos.toVec2(),
      .scale  = tmp.view,
    };
  }


  // ================ ACCESSORS & MUTATORS ================

  pub inline fn getCenter( self : *const Cam2 ) Vec2  { return self.pos.toVec2(); }
  pub inline fn getRot(    self : *const Cam2 ) Angle { return self.pos.a; }
  pub inline fn getZoom(   self : *const Cam2 ) f64   { return self.zoom; }

  pub inline fn setCenter( self : *Cam2, pos  : Vec2  ) void { self.pos.x = pos.x; self.pos.y = pos.y; }
  pub inline fn setRot(    self : *Cam2, a    : Angle ) void { self.pos.a = a; }
  pub inline fn setZoom(   self : *Cam2, zoom : f64   ) void
  {
    self.zoom = zoom;

    self.updateView();
  }


  // ================ MOVEMENT ================

  pub inline fn moveBy(  self : *Cam2, offset       : Vec2 ) void { self.pos.x += offset.x; self.pos.y += offset.y; }
  pub inline fn moveByS( self : *Cam2, screenOffset : Vec2 ) void
  {
    self.updateView();
    self.pos = self.pos.add( screenOffset.mulVal( 1.0 / self.zoom ).toVecA( .{} ));
  }

  pub inline fn rotBy(  self : *Cam2, a      : Angle ) void { self.pos.a = self.pos.a.rot( a ); }
  pub inline fn zoomBy( self : *Cam2, factor : f64   ) void { self.setZoom( self.zoom * factor ); }

};
