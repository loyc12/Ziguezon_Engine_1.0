const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const cmp = @import( "gameComps.zig" );


pub fn updateCameraLogic( ng : *def.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ ng.camera.moveByS( def.Vec2.new(  0, -8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ ng.camera.moveByS( def.Vec2.new(  0,  8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ ng.camera.moveByS( def.Vec2.new( -8,  0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ ng.camera.moveByS( def.Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ ng.camera.zoomBy( 1.1 ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ ng.camera.zoomBy( 0.9 ); }

  // Reset the camera zoom and position when r is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.r ))
  {
    ng.camera.setZoom(   1.0 );
    ng.camera.pos = .{};
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }
}