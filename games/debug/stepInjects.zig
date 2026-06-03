const std      = @import( "std" );
const eng      = @import( "engine" );
const utl = @import( "utils" );
const stateInj = @import( "stateInjects.zig" );

const Engine = eng.Engine;
const Body = eng.Body;
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
var sprite_r : f32 = 0;

const SHOW_INTERFACE = true;

var ui : utl.Interface2D = .{ .pos = .new( 256, 512, .{ .r = 0 }), .scale = .new( 128, 256 ), .edgeWidth = 32, .lineWidth = 4 };

// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnFrameUpdate( ng : *eng.Engine ) void
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

    utl.log( .INFO, 0, @src(), "Shake Offset : {}:{}:{} ({}s)", .{ offset.x, offset.y, offset.a.r, s_time });
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
    utl.qlog( .INFO, 0, @src(), "Camera reseted" );
  }


  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.c ))
  {
    var newShape : usize = @intFromEnum( ui.shape );
        newShape = @mod( newShape + 1, utl.InterfaceShape.count );

    ui.setShape( @enumFromInt( newShape ));
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.v ))
  {
    const s = ui.bevelStrength[ 0 ] + 0.1;
    const n = utl.InterfaceShape.maxCornerCount;

    for( 0..n )| i |
    {
       ui.setBevelStrength( i, s );
    }
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.b ))
  {
    const s = ui.bevelStrength[ 0 ] - 0.1;
    const n = utl.InterfaceShape.maxCornerCount;

    for( 0..n )| i |
    {
      ui.setBevelStrength( i, s );
    }
  }


  var exampleTilemap = ng.tilemapManager.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  // Swap tilemap shape if the V key is pressed

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.c ))
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
    utl.log( .INFO, 0, @src(), "Example tilemap shape changed to {}", .{ exampleTilemap.tileShape });
  }

  // If left clicked, check if a tile was clicked on the example tilemap
  if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.left ))
  {
    const mouseScreenPos = utl.getMouseScreenPos();
    const mouseWorldPos  = eng.G_ENG.camera.getMouseWorldPos();

    utl.log( .INFO, 0, @src(), "Mouse clicked at screen pos {d}:{d}, world pos {d}:{d}", .{ mouseScreenPos.x, mouseScreenPos.y, mouseWorldPos.x, mouseWorldPos.y });

    const worldCoords = exampleTilemap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      utl.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = exampleTilemap.getTile( worldCoords.? ) orelse
      {
        utl.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, exampleTilemap.id });
        return;
      };

      utl.log( .INFO, 0, @src(), "Clicked on tile with coords {d}:{d} in tilemap {d}", .{ clickedTile.mapCoords.x, clickedTile.mapCoords.y, exampleTilemap.id });

      // Change the tile color to a random color
      clickedTile.colour = eng.G_ENG.rng.getColour();
    }
    else
    {
      utl.log( .INFO, 0, @src(), "No tile found at mouse world position {d}:{d}", .{ mouseWorldPos.x, mouseWorldPos.y });
    }
  }
}


pub fn OnTickUpdate( ng : *eng.Engine ) void
{
  var exampleBody = ng.bodyManager.getBody( stateInj.EXAMPLE_BDY_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Body ) not found", .{ stateInj.EXAMPLE_BDY_ID });
    return;
  };

  exampleBody.pos.a = exampleBody.pos.a.rotDeg( exampleBody.pos.a.cos() + 1.5 ); // Example of a simple variable rotation effect
  exampleBody.pos.y = 256  * exampleBody.pos.a.sin();                              // Example of a simple variable vertical movement effect


  var exampleTilemap = ng.tilemapManager.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  exampleTilemap.mapPos.a = exampleTilemap.mapPos.a.rotRad( 0.01 ); // Example of a simple variable rotation effect


  var exampleRLine = ng.bodyManager.getBody( stateInj.EXAMPLE_RLIN_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Radius Line ) not found", .{ stateInj.EXAMPLE_RLIN_ID });
    return;
  };

  exampleRLine.pos.a = exampleTilemap.mapPos.a;


  var exampleDLine = ng.bodyManager.getBody( stateInj.EXAMPLE_DLIN_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Diametre Line ) not found", .{ stateInj.EXAMPLE_DLIN_ID });
    return;
  };

  exampleDLine.pos.a = exampleTilemap.mapPos.a;


  var exampleTriangle = ng.bodyManager.getBody( stateInj.EXAMPLE_TRIA_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Triangle ) not found", .{ stateInj.EXAMPLE_TRIA_ID });
    return;
  };

  exampleTriangle.pos.a = exampleTilemap.mapPos.a;


  var exampleRectangle = ng.bodyManager.getBody( stateInj.EXAMPLE_RECT_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Rectangle ) not found", .{ stateInj.EXAMPLE_RECT_ID });
    return;
  };

  exampleRectangle.pos.a = exampleTilemap.mapPos.a;


  var exampleHexagon = ng.bodyManager.getBody( stateInj.EXAMPLE_HEXA_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Hexagon ) not found", .{ stateInj.EXAMPLE_HEXA_ID });
    return;
  };

  exampleHexagon.pos.a = exampleTilemap.mapPos.a;


  var exampleEllipse = ng.bodyManager.getBody( stateInj.EXAMPLE_ELLI_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Body with Id {d} ( Example Ellipse ) not found", .{ stateInj.EXAMPLE_ELLI_ID });
    return;
  };

  exampleEllipse.pos.a = exampleTilemap.mapPos.a;

  sprite_r = @mod( sprite_r + ( utl.TAU / ( 60.0 * 4.0 )), utl.TAU );
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
    ng.resourceManager.drawScreenFromSprite( "cubes_1", @intCast( sprite_i ), .{ .x = width / 2, .y = height / 2, .a = .{ .r = sprite_r }}, .{ .x = 4.0, .y = 4.0 }, .white );
  }

  if( SHOW_INTERFACE )
  {
    ui.drawSelf();
  }

  if( SHOW_SHAKE_GRAPHS )
  {

    utl.sDraw.basicLine( .{ .x = 0, .y = height * 0.125 }, .{ .x = width, .y = height * 0.125 }, .nBlack, 4 );
    utl.sDraw.basicLine( .{ .x = 0, .y = height * 0.375 }, .{ .x = width, .y = height * 0.375 }, .nBlack, 4 );
    utl.sDraw.basicLine( .{ .x = 0, .y = height * 0.625 }, .{ .x = width, .y = height * 0.625 }, .nBlack, 4 );
    utl.sDraw.basicLine( .{ .x = 0, .y = height * 0.875 }, .{ .x = width, .y = height * 0.875 }, .nBlack, 4 );

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
}