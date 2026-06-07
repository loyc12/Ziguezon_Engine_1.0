const utl = @import( "utils" );

const Box2  = utl.Box2;
const Vec2  = utl.Vec2;
const Angle = utl.Angle;
const RayCam = utl.RayCam;



// ================================ WORLD CAMERA ================================

// Engine-owned wrapper around the generic Cam2 primitive. WorldCam is the place
// where camera state becomes world-relative and where engine zoom limits apply.

pub const WorldCam = struct
{
  cam     : utl.Cam2 = .{},
  zoomMin : f64       = 0.1,
  zoomMax : f64       = 10.0,


  // ================ CONFIGURATION ================

  pub inline fn configZoom( self : *WorldCam, zoomMin : f64, zoomMax : f64, zoomInit : f64 ) void
  {
    self.zoomMin = zoomMin;
    self.zoomMax = zoomMax;

    self.setZoom( zoomInit );
  }


  // ================ UPDATING ================

  pub inline fn updateView( self : *WorldCam ) void { self.cam.updateView(); }


  // ================ CONVERSION ================

  // Used by world drawers while raylib handles zoom, offset, and rotation.
  // The position subtraction stays in f64 before conversion to avoid large-world
  // precision loss when coordinates are eventually cast into raylib values.
  pub inline fn worldToRender( self : *const WorldCam, worldPos : Vec2 ) Vec2
  {
    return worldPos.sub( self.cam.pos.toVec2() );
  }

  // Used when a true screen-space coordinate is needed, such as UI overlays,
  // debug labels, or hit detection against world objects.
  pub inline fn worldToScreen( self : *const WorldCam, worldPos : Vec2 ) Vec2
  {
    return worldPos
      .sub( self.cam.pos.toVec2()   )  // make camera-relative
      .rot( self.cam.pos.a          )  // apply rotation around camera center
      .mulVal( self.cam.zoom        )  // apply zoom
      .add( utl.getHalfScreenSize() ); // apply screen offset
  }
  pub inline fn screenToWorld( self : *const WorldCam, screenPos : Vec2 ) Vec2
  {
    return screenPos
      .sub( utl.getHalfScreenSize() )  // undo screen offset
      .mulVal( 1.0 / self.cam.zoom  )  // undo zoom
      .rot( self.cam.pos.a.neg()    )  // undo rotation around camera center
      .add( self.cam.pos.toVec2()   ); // restore world position
  }

  pub inline fn toRayCam( self : *const WorldCam ) RayCam
  {
    var tmp : utl.Cam2 = self.cam;
    tmp.updateView();

    const rayCam = RayCam{
    //.target   = tmp.pos.toRayVec2(),
      .target   = .{ .x = 0.0, .y = 0.0 }, // Always zero - world offset is handled before worldRender casts to ray values.
      .offset   = utl.getHalfScreenSize().toRayVec2(),
      .rotation = @floatCast( tmp.pos.a.toDeg() ),
      .zoom     = @floatCast( tmp.zoom ),
    };

  return rayCam;
  }

  pub inline fn fromViewBox( vb : Box2 ) WorldCam
  {
    return WorldCam{ .cam = utl.Cam2.fromViewBox( vb ) };
  }
  pub inline fn toViewBox( self : *const WorldCam ) Box2
  {
    return self.cam.toViewBox();
  }

  pub inline fn getMouseWorldPos( self : *const WorldCam ) Vec2
  {
    return self.screenToWorld( utl.getMouseScreenPos() );
  }


  // ================ ACCESSORS & MUTATORS ================

  pub inline fn getCenter( self : *const WorldCam ) Vec2  { return self.cam.getCenter(); }
  pub inline fn getRot(    self : *const WorldCam ) Angle { return self.cam.getRot();    }
  pub inline fn getZoom(   self : *const WorldCam ) f64   { return self.cam.getZoom();   }

  pub inline fn setCenter( self : *WorldCam, worldPos : Vec2  ) void { self.cam.setCenter( worldPos ); }
  pub inline fn setRot(    self : *WorldCam, a        : Angle ) void { self.cam.setRot( a ); }
  pub inline fn setZoom(   self : *WorldCam, zoom     : f64   ) void
  {
    self.cam.setZoom( utl.clmp( zoom, self.zoomMin, self.zoomMax ) );
  }

  pub inline fn setMouseRelZoom( self : *WorldCam, z : f64 ) void
  {
    self.setWorldRelZoom( z, self.getMouseWorldPos() );
  }
  pub inline fn setScreenRelZoom( self : *WorldCam, z : f64, screenPos : Vec2 ) void
  {
    self.setWorldRelZoom( z, self.screenToWorld( screenPos ) );
  }
  pub fn setWorldRelZoom( self : *WorldCam, z : f64, worldPos : Vec2 ) void
  {
    const newZoom = utl.clmp( z, self.zoomMin, self.zoomMax );
    const ratio   = self.cam.zoom / newZoom;

    // Vector from anchor point to current camera center, scaled by zoom ratio.
    // This keeps worldPos at the same screen-space position after the zoom.
    const oldCenter = self.cam.pos.toVec2();
    const newCenter = worldPos.add( oldCenter.sub( worldPos ).mulVal( ratio ) );

    self.cam.zoom  = newZoom;
    self.cam.pos.x = newCenter.x;
    self.cam.pos.y = newCenter.y;

    self.updateView();
  }


  // ================ MOVEMENT ================

  pub inline fn moveBy(  self : *WorldCam, offset       : Vec2 ) void { self.cam.moveBy(  offset       ); }
  pub inline fn moveByS( self : *WorldCam, screenOffset : Vec2 ) void { self.cam.moveByS( screenOffset ); }

  pub inline fn rotBy(  self : *WorldCam, a      : Angle ) void { self.cam.rotBy( a ); }
  pub inline fn zoomBy( self : *WorldCam, factor : f64   ) void { self.setZoom( self.cam.zoom * factor ); }

  pub inline fn zoomOnMouseBy( self : *WorldCam, factor : f64 ) void
  {
    self.setMouseRelZoom( self.cam.zoom * factor );
  }


  // ================ CLAMPING ================

  pub fn clampOnArea( self : *WorldCam, area : Box2 ) void
  {
    utl.log( .TRACE, 0, @src(), "Clamping WorldCam on area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    var viewBox = self.toViewBox();
    viewBox.clampOnArea( area.getTopLeft(), area.getBottomRight() );

    self.cam.pos.x = viewBox.center.x;
    self.cam.pos.y = viewBox.center.y;
  }
  pub fn clampInArea( self : *WorldCam, area : Box2 ) void
  {
    utl.log( .TRACE, 0, @src(), "Clamping WorldCam in area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    var viewBox = self.toViewBox();
    viewBox.clampInArea( area.getTopLeft(), area.getBottomRight() );

    self.cam.pos.x = viewBox.center.x;
    self.cam.pos.y = viewBox.center.y;
  }
  pub fn clampOnPoint( self : *WorldCam, point : Vec2 ) void
  {
    utl.log( .TRACE, 0, @src(), "Clamping WorldCam on point ( {d}:{d} )", .{ point.x, point.y });

    var viewBox = self.toViewBox();
    viewBox.clampOnPoint( point );

    self.cam.pos.x = viewBox.center.x;
    self.cam.pos.y = viewBox.center.y;
  }
  pub fn clampCenterInArea( self : *WorldCam, area : Box2 ) void
  {
    utl.log( .TRACE, 0, @src(), "Clamping WorldCam center in area ( from {d}:{d} to {d}:{d} )", .{ area.getTopLeft().x, area.getTopLeft().y, area.getBottomRight().x, area.getBottomRight().y });

    self.cam.pos.x = utl.clmp( self.cam.pos.x, area.getMinX(), area.getMaxX() );
    self.cam.pos.y = utl.clmp( self.cam.pos.y, area.getMinY(), area.getMaxY() );
  }

};
