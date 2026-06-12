const std      = @import( "std" );
const eng      = @import( "engine" );
const utl      = @import( "utils" );
const stateInj = @import( "stateInjects.zig" );

const Engine = eng.Engine;
const Angle  = utl.Angle;
const Vec2   = utl.Vec2;
const VecA   = utl.VecA;

// ================================ GLOBAL GAME VARIABLES ================================

const SHOW_SHAKE_GRAPHS = true;

var s_time : f32 = 0.0;

const shaker : utl.Shake2D = .{
  .beg_length    = 0.03,
  .mid_length    = 0.04,
  .end_length    = 0.03,
};


const SHOW_SPRITE_ANIM = true;

var sprite_i : i32 = 0;


const SHOW_INTERFACE = true;

var interface : utl.Interface2D = .{ .pos = .new( 256, 512, .{ .r = 0 }), .scale = .new( 128, 256 ), .edgeWidth = 32, .lineWidth = 4 };


const SHOW_STARS = true;

var angle : Angle = .newRad( 0 );
var val1  : u16   = 0;

// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnInputUpdate( ng : *eng.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }


  // Play a shake animation the camera when Q is held
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.i )){ sprite_i = @mod( sprite_i + 1, 256 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.o )){ sprite_i = @mod( sprite_i - 1, 256 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.e )){ s_time   = 0.0; }
  if( utl.ray.isKeyDown(    utl.ray.KeyboardKey.q ))
  {
    const offset = shaker.getOffsetAtTime( s_time );

    eng.G_ENG.camera.cam.pos = .{ .x = offset.x * 32, .y = offset.y * 32, .a = .{ .r = offset.a.r * 0.2, }};
    s_time += ( 1.0 / 120.0 );

    utl.log( .INFO, @src(), "Shake Offset : {}:{}:{} ({}s)", .{ offset.x, offset.y, offset.a.r, s_time });
  }


  // Move the camera with the WASD or arrow keys
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ eng.G_ENG.camera.moveByS( Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ eng.G_ENG.camera.moveByS( Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ eng.G_ENG.camera.moveByS( Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ eng.G_ENG.camera.moveByS( Vec2.new(  8,  0 )); }


  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_ENG.camera.zoomBy( 11.0 / 10.0 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_ENG.camera.zoomBy(  9.0 / 10.0 ); }


  // Reset the camera zoom and position when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_ENG.camera.setZoom(   1.0 );
    eng.G_ENG.camera.cam.pos = .{};
    utl.qlog( .INFO, @src(), "Camera reseted" );
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.v ))
  {
    const s = interface.bevelStrength[ 0 ] + 0.1;
    const n = utl.InterfaceShape.maxCornerCount;

    for( 0..n )| i |
    {
       interface.setBevelStrength( i, s );
    }
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.b ))
  {
    const s = interface.bevelStrength[ 0 ] - 0.1;
    const n = utl.InterfaceShape.maxCornerCount;

    for( 0..n )| i |
    {
      interface.setBevelStrength( i, s );
    }
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.k ))
  {
    val1 = ( val1 + 1 ) % 99;

    const newShape = val1 % utl.InterfaceShape.count;
    interface.setShape( @enumFromInt( newShape ));
  }


  var exampleTilemap = ng.tilemapManager.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    utl.log( .WARN, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  // Swap tilemap shape if the V key is pressed

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.h ))
  {
    switch( exampleTilemap.tileShape )
    {
      .RECT => exampleTilemap.setTileShape( .DIAM ),
      .DIAM => exampleTilemap.setTileShape( .HEX1 ),
      .HEX1 => exampleTilemap.setTileShape( .HEX2 ),
      .HEX2 => exampleTilemap.setTileShape( .TRI1 ),
      .TRI1 => exampleTilemap.setTileShape( .TRI2 ),
      .TRI2 => exampleTilemap.setTileShape( .RECT ),
    }
    utl.log( .INFO, @src(), "Example tilemap shape changed to {}", .{ exampleTilemap.tileShape });
  }

  // If left clicked, check if a tile was clicked on the example tilemap
  if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.left ))
  {
    const mouseScreenPos = utl.getMouseScreenPos();
    const mouseWorldPos  = eng.G_ENG.camera.getMouseWorldPos();

    utl.log( .INFO, @src(), "Mouse clicked at screen pos {d}:{d}, world pos {d}:{d}", .{ mouseScreenPos.x, mouseScreenPos.y, mouseWorldPos.x, mouseWorldPos.y });

    const worldCoords = exampleTilemap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      utl.log( .INFO, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = exampleTilemap.getTile( worldCoords.? ) orelse
      {
        utl.log( .WARN, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, exampleTilemap.id });
        return;
      };

      utl.log( .INFO, @src(), "Clicked on tile with coords {d}:{d} in tilemap {d}", .{ clickedTile.mapCoords.x, clickedTile.mapCoords.y, exampleTilemap.id });

      // Change the tile color to a random color
      clickedTile.colour = eng.G_ENG.rng.getColour();
    }
    else
    {
      utl.log( .INFO, @src(), "No tile found at mouse world position {d}:{d}", .{ mouseWorldPos.x, mouseWorldPos.y });
    }
  }
}


pub fn OnTickUpdate( ng : *eng.Engine ) void
{
  var exampleTilemap = ng.tilemapManager.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    utl.log( .WARN, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };


  angle = angle.rotDeg( 1 );

  exampleTilemap.mapPos.a = angle;
}


pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    utl.sDraw.coverScreenWithCol( .new( 0, 0, 0, 128 ));
  }

  const width  = utl.getScreenWidth();
  const height = utl.getScreenHeight();

  if( SHOW_SPRITE_ANIM )
  {
    ng.resourceManager.drawScreenFromSprite( "cubes_1", @intCast( sprite_i ), .{ .x = width / 2, .y = height / 2, .a = angle }, .{ .x = 4.0, .y = 4.0 }, .white );
  }

  if( SHOW_INTERFACE )
  {
    interface.drawSelf();
  }

  if( SHOW_SHAKE_GRAPHS )
  {

    utl.sDraw.basicLine( .new( 0, height * 0.125 ), .new( width, height * 0.125 ), .nBlack, 4 );
    utl.sDraw.basicLine( .new( 0, height * 0.375 ), .new( width, height * 0.375 ), .nBlack, 4 );
    utl.sDraw.basicLine( .new( 0, height * 0.625 ), .new( width, height * 0.625 ), .nBlack, 4 );
    utl.sDraw.basicLine( .new( 0, height * 0.875 ), .new( width, height * 0.875 ), .nBlack, 4 );

    const l1 = width *           shaker.beg_length / shaker.getTotalLength();
    const l2 = width * ( 1.0 - ( shaker.end_length / shaker.getTotalLength() ));

    // Vertical phase divider lines
    utl.sDraw.basicLine( .{ .x = l1, .y = 0 }, .{ .x = l1, .y = height }, .nBlack, 4 );
    utl.sDraw.basicLine( .{ .x = l2, .y = 0 }, .{ .x = l2, .y = height }, .nBlack, 4 );

    // Shake graph
    for( 0 .. @intFromFloat( width ))| pos |
    {
      const x : f64 = @floatFromInt( pos );
      const offset  = shaker.getOffsetAtProg( @floatCast( x / width ));

      var hx : f64 = height * 0.25;
      var hy : f64 = height * 0.50;
      var hr : f64 = height * 0.75;

      hx += offset.x   * 128;
      hy += offset.y   * 128;
      hr += offset.a.r * 128;

      utl.sDraw.textCenter( "|", .new( x, hx ), 12.0, .red );
      utl.sDraw.textCenter( "|", .new( x, hy ), 12.0, .green );
      utl.sDraw.textCenter( "|", .new( x, hr ), 12.0, .blue );
    }
  }

  if( SHOW_SHAKE_GRAPHS )
  {
    utl.sDraw.polyStar(      .new( width * 0.75, height * 0.25 ), .new( 64, 48 ), angle, .green, 7,  ( val1 % 6  ) + 1 );
    utl.sDraw.polyStarPerim( .new( width * 0.75, height * 0.50 ), .new( 64, 64 ), angle, .blue,  11, ( val1 % 10 ) + 1, 2.0 );
    utl.sDraw.polySpokes(    .new( width * 0.75, height * 0.75 ), .new( 64, 80 ), angle, .red,       ( val1 % 12 ) + 1, 2.0 );
  }
}
