const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Body = def.Body;
const Angle  = def.Angle;
const Vec2   = def.Vec2;
const VecA   = def.VecA;

// ================================ GLOBAL GAME VARIABLES ================================

const SHOW_SHAKE_GRAPHS = true;

var s_time : f32 = 0.0;

const shaker : def.Shaker2D = .{
  .beg_lenght    = 0.03,
  .mid_lenght    = 0.04,
  .end_lenght    = 0.03,
};


const SHOW_SPRITE_ANIM = true;

var sprite_i : i32 = 0;
var sprite_r : f32 = 0;


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnLoopStart( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  ng.changeState( .PLAYING ); // force the game to unpause on start
}


pub fn OnUpdateInputs( ng : *def.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Play a shake animation the camera when H is held
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.j )){ s_time   = 0.0; }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.i )){ sprite_i = @mod( sprite_i + 1, 256 ); }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.o )){ sprite_i = @mod( sprite_i - 1, 256 ); }
  if( def.ray.isKeyDown(    def.ray.KeyboardKey.h ))
  {
    var cam = ng.getCamera() catch
    {
      def.qlog( .WARN, 0, @src(), "Failed to optain main camera" );
      return;
    };

    const offset = shaker.getOffsetAtTime( s_time );

    cam.pos = .{ .x = offset.x * 32, .y = offset.y * 32, .a = .{ .r = offset.a.r * 4, }};
    s_time += ( 1.0 / 120.0 );

    def.log( .WARN, 0, @src(), "Shake Offset : {}:{}:{} ({}s)", .{ offset.x, offset.y, offset.a.r, s_time });
  }


  // Move the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ ng.moveCameraByS( Vec2.new(  0, -8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ ng.moveCameraByS( Vec2.new(  0,  8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ ng.moveCameraByS( Vec2.new( -8,  0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ ng.moveCameraByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ ng.zoomCameraBy( 11.0 / 10.0 ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ ng.zoomCameraBy(  9.0 / 10.0 ); }

  // Reset the camera zoom and position when r is pressed
  if( def.ray.isKeyDown( def.ray.KeyboardKey.r ))
  {
    ng.setCameraZoom(   1.0 );
    ng.setCameraCenter( .{} );
    ng.setCameraRot(    .{} );
    def.qlog( .INFO, 0, @src(), "Camera reseted" );
  }

  var exampleTilemap = ng.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  // Swap tilemap shape if the V key is pressed

  if( def.ray.isKeyPressed( def.ray.KeyboardKey.v ))
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
    def.log( .INFO, 0, @src(), "Example tilemap shape changed to {}", .{ exampleTilemap.tileShape });
  }

  // If left clicked, check if a tile was clicked on the example tilemap
  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    const mouseScreemPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreemPos, ng.getCameraCpy().?.toRayCam() );

    def.log( .INFO, 0, @src(), "Mouse clicked at screen pos {d}:{d}, world pos {d}:{d}", .{ mouseScreemPos.x, mouseScreemPos.y, mouseWorldPos.x, mouseWorldPos.y });

    const worldCoords = exampleTilemap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = exampleTilemap.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, exampleTilemap.id });
        return;
      };

      def.log( .INFO, 0, @src(), "Clicked on tile with coords {d}:{d} in tilemap {d}", .{ clickedTile.mapCoords.x, clickedTile.mapCoords.y, exampleTilemap.id });

      // Change the tile color to a random color
      clickedTile.colour = def.G_RNG.getColour();
    }
    else
    {
      def.log( .INFO, 0, @src(), "No tile found at mouse world position {d}:{d}", .{ mouseWorldPos.x, mouseWorldPos.y });
    }
  }
}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  var exampleBody = ng.getBody( stateInj.EXAMPLE_BDY_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Body ) not found", .{ stateInj.EXAMPLE_BDY_ID });
    return;
  };

  exampleBody.pos.a = exampleBody.pos.a.rotDeg( exampleBody.pos.a.cos() + 1.5 ); // Example of a simple variable rotation effect
  exampleBody.pos.y = 256  * exampleBody.pos.a.sin();                              // Example of a simple variable vertical movement effect


  var exampleTilemap = ng.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  exampleTilemap.mapPos.a = exampleTilemap.mapPos.a.rotRad( 0.01 ); // Example of a simple variable rotation effect


  var exampleRLine = ng.getBody( stateInj.EXAMPLE_RLIN_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Radius Line ) not found", .{ stateInj.EXAMPLE_RLIN_ID });
    return;
  };

  exampleRLine.pos.a = exampleTilemap.mapPos.a;


  var exampleDLine = ng.getBody( stateInj.EXAMPLE_DLIN_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Diametre Line ) not found", .{ stateInj.EXAMPLE_DLIN_ID });
    return;
  };

  exampleDLine.pos.a = exampleTilemap.mapPos.a;


  var exampleTriangle = ng.getBody( stateInj.EXAMPLE_TRIA_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Triangle ) not found", .{ stateInj.EXAMPLE_TRIA_ID });
    return;
  };

  exampleTriangle.pos.a = exampleTilemap.mapPos.a;


  var exampleRectangle = ng.getBody( stateInj.EXAMPLE_RECT_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Rectangle ) not found", .{ stateInj.EXAMPLE_RECT_ID });
    return;
  };

  exampleRectangle.pos.a = exampleTilemap.mapPos.a;


  var exampleHexagon = ng.getBody( stateInj.EXAMPLE_HEXA_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Hexagon ) not found", .{ stateInj.EXAMPLE_HEXA_ID });
    return;
  };

  exampleHexagon.pos.a = exampleTilemap.mapPos.a;


  var exampleEllipse = ng.getBody( stateInj.EXAMPLE_ELLI_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Body with Id {d} ( Example Ellipse ) not found", .{ stateInj.EXAMPLE_ELLI_ID });
    return;
  };

  exampleEllipse.pos.a = exampleTilemap.mapPos.a;

  sprite_r = @mod( sprite_r + ( def.TAU / ( 60.0 * 4.0 )), def.TAU );
}


pub fn OnRenderOverlay( ng : *def.Engine ) void
{
  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.coverScreenWithCol( .new( 0, 0, 0, 128 ));
  }

  const width  = def.getScreenWidth();
  const height = def.getScreenHeight();

  if( SHOW_SPRITE_ANIM )
  {
    ng.drawFromSprite( "cubes_1", @intCast( sprite_i ), .{ .x = width / 2, .y = height / 2, .a = .{ .r = sprite_r }}, .{ .x = 4.0, .y = 4.0 }, .white );
  }

  if( SHOW_SHAKE_GRAPHS )
  {

    def.drawLine( .{ .x = 0, .y = height * 0.25 }, .{ .x = width, .y = height * 0.25 }, .nBlack, 4 );
    def.drawLine( .{ .x = 0, .y = height * 0.50 }, .{ .x = width, .y = height * 0.50 }, .nBlack, 4 );
    def.drawLine( .{ .x = 0, .y = height * 0.75 }, .{ .x = width, .y = height * 0.75 }, .nBlack, 4 );

    const l1 = width *           shaker.beg_lenght / shaker.getTotalLenght();
    const l2 = width * ( 1.0 - ( shaker.end_lenght / shaker.getTotalLenght() ));

    def.drawLine( .{ .x = l1, .y = 0 }, .{ .x = l1, .y = height }, .nBlack, 4 );
    def.drawLine( .{ .x = l2, .y = 0 }, .{ .x = l2, .y = height }, .nBlack, 4 );

    for( 0 .. @intFromFloat( width ))| pos |
    {
      const x : f32 = @floatFromInt( pos );
      const offset  = shaker.getOffsetAtProg( x / width );


      var hx : f32 = height * 0.25;
      var hy : f32 = height * 0.50;
      var hr : f32 = height * 0.75;

      hx += offset.x   * 128;
      hy += offset.y   * 128;
      hr += offset.a.r * 128;

      def.drawCenteredText( "|", x , hx, 12, .red );
      def.drawCenteredText( "|", x , hy, 12, .green );
      def.drawCenteredText( "|", x , hr, 12, .blue );
    }
  }
}