const std      = @import( "std" );
const eng      = @import( "engine" );
const utl = @import( "utils" );
const stateInj = @import( "stateInjects.zig" );

const Engine = eng.Engine;
const Body = eng.Body;

const Angle  = utl.Angle;
const Vec2   = utl.Vec2;
const VecA   = utl.VecA;
const Box2   = utl.Box2;

// ================================ GLOBAL GAME VARIABLES ================================




// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnFrameUpdate( ng : *eng.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ eng.G_CAM.moveByS( Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ eng.G_CAM.moveByS( Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ eng.G_CAM.moveByS( Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ eng.G_CAM.moveByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_CAM.zoomBy( 11.0 / 10.0 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_CAM.zoomBy(  9.0 / 10.0 ); }

  // Reset the camera zoom and position when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_CAM.setZoom(   1.0 );
    eng.G_CAM.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reseted" );
  }

  var mazeMap = ng.tilemapManager.getTilemap( stateInj.MAZE_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Maze ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  // Keep the camera inside over the maze area
  eng.G_CAM.clampCenterInArea( mazeMap.getMapBoundingBox() );

  // Swap tilemap render style if the V key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.v ))
  {
    switch( mazeMap.tileShape )
    {
      .RECT =>
      {
        mazeMap.setTileShape( .DIAM );
        mazeMap.tileScale.y = mazeMap.tileScale.y * 0.5; // skews the map to get an isometric view
      },

      .DIAM =>
      {
        mazeMap.setTileShape( .HEX1 );
        mazeMap.tileScale.y = mazeMap.tileScale.y * 2.0; // unskews the map back to normal
      },

      .HEX1 => mazeMap.setTileShape( .HEX2 ),
      .HEX2 => mazeMap.setTileShape( .TRI1 ),

      .TRI1 => mazeMap.setTileShape( .TRI2 ),
      .TRI2 => mazeMap.setTileShape( .RECT ),
    }
  }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.q )){ mazeMap.mapPos.a = mazeMap.mapPos.a.subDeg( 1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.e )){ mazeMap.mapPos.a = mazeMap.mapPos.a.addDeg( 1 ); }


  const mouseWorldPos = utl.getMouseWorldPos();

  const worldCoords = mazeMap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

  // If left clicked on tile, colour its neighbours
  if( worldCoords != null and utl.ray.isMouseButtonPressed( utl.ray.MouseButton.left ))
  {
    utl.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

    var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
    {
      utl.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
      return;
    };

    // Change the colour of the clicked tile
    clickedTile.colour = eng.G_RNG.getColour();

    // Set the colour of all neighbouring tiles to their direction's debug colour
    for( utl.e_dir_2.arr )| dir |
    {
      const n = mazeMap.getNeighbourTile( clickedTile.mapCoords, dir ) orelse
      {
        utl.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d} : continuing", .{ @tagName( dir ), clickedTile.mapCoords.x, clickedTile.mapCoords.y });
        continue;
      };

      n.colour = dir.getDebugColour();
    }
  }

  // If right clicked on tile, set its type to T2
  if( worldCoords != null and utl.ray.isMouseButtonPressed( utl.ray.MouseButton.right ))
  {
    var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
    {
      utl.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
      return;
    };

    // Change the type and colour of the clicked tile
    clickedTile.tType  = .T2;
    clickedTile.colour = utl.Colour.mGray;
  }

  // If middle clicked on tile, floodFill T1 tiles with nWhite
  if( worldCoords != null and utl.ray.isMouseButtonPressed( utl.ray.MouseButton.middle ))
  {
    const clickedTile = mazeMap.getTile( worldCoords.? ) orelse
    {
      utl.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
      return;
    };

    mazeMap.floodFillWithColour( clickedTile, 256, .T1, .nWhite );
  }
}


pub fn OnTickUpdate( ng : *eng.Engine ) void
{
  const mazeMap = ng.tilemapManager.getTilemap( stateInj.MAZE_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  _ = mazeMap; // Prevent unused variable warning
}


pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  // NOTE : All active bodies are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *eng.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    const screenCenter = utl.getHalfScreenSize();

    utl.sDraw.coverScreenWithCol( .new( 0, 0, 0, 128 ));
    utl.sDraw.textCenter( "Paused",                      .new( screenCenter.x, screenCenter.y - 20.0 ), 40.0, utl.Colour.white );
    utl.sDraw.textCenter( "Press P or Enter to resume",  .new( screenCenter.x, screenCenter.y + 20.0 ), 20.0, utl.Colour.white );
    utl.sDraw.textCenter( "Press V to change view mode", .new( screenCenter.x, screenCenter.y + 60.0 ), 20.0, utl.Colour.white );
  }
}