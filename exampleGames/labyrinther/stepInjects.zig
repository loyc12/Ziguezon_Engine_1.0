const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Body = def.Body;

const Angle  = def.Angle;
const Vec2   = def.Vec2;
const VecA   = def.VecA;
const Box2   = def.Box2;

// ================================ GLOBAL GAME VARIABLES ================================




// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateInputs( ng : *def.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ ng.camera.moveByS( Vec2.new(  0, -8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ ng.camera.moveByS( Vec2.new(  0,  8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ ng.camera.moveByS( Vec2.new( -8,  0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ ng.camera.moveByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ ng.camera.zoomBy( 11.0 / 10.0 ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ ng.camera.zoomBy(  9.0 / 10.0 ); }

  // Reset the camera zoom and position when r is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.r ))
  {
    ng.camera.setZoom(   1.0 );
    ng.camera.pos = .{};
    def.qlog( .INFO, 0, @src(), "Camera reseted" );
  }

  var mazeMap = ng.tilemapManager.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Maze ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  // Keep the camera inside over the maze area
  ng.camera.clampCenterInArea( mazeMap.getMapBoundingBox() );

  // Swap tilemap render style if the V key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.v ))
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
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.q )){ mazeMap.mapPos.a = mazeMap.mapPos.a.subDeg( 1 ); }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.e )){ mazeMap.mapPos.a = mazeMap.mapPos.a.addDeg( 1 ); }


  const mouseScreemPos = def.ray.getMousePosition();
  const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreemPos, ng.camera.toRayCam() );

  const worldCoords = mazeMap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

  // If left clicked on tile, colour its neighbours
  if( worldCoords != null and def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

    var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
      return;
    };

    // Change the colour of the clicked tile
    clickedTile.colour = def.G_RNG.getColour();

    // Set the colour of all neighbouring tiles to their direction's debug colour
    for( def.e_dir_2.arr )| dir |
    {
      const n = mazeMap.getNeighbourTile( clickedTile.mapCoords, dir ) orelse
      {
        def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d} : continuing", .{ @tagName( dir ), clickedTile.mapCoords.x, clickedTile.mapCoords.y });
        continue;
      };

      n.colour = dir.getDebugColour();
    }
  }

  // If right clicked on tile, set its type to T2
  if( worldCoords != null and def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
  {
    var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
      return;
    };

    // Change the type and colour of the clicked tile
    clickedTile.tType  = .T2;
    clickedTile.colour = def.Colour.mGray;
  }

  // If middle clicked on tile, floodFill T1 tiles with nWhite
  if( worldCoords != null and def.ray.isMouseButtonPressed( def.ray.MouseButton.middle ))
  {
    const clickedTile = mazeMap.getTile( worldCoords.? ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
      return;
    };

    mazeMap.floodFillWithColour( clickedTile, 256, .T1, .nWhite );
  }
}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const mazeMap = ng.tilemapManager.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  _ = mazeMap; // Prevent unused variable warning
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  // NOTE : All active bodies are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void
{
  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    const screenCenter = def.getHalfScreenSize();

    def.coverScreenWithCol( .new( 0, 0, 0, 128 ));
    def.drawCenteredText( "Paused",                      screenCenter.x, screenCenter.y - 20, 40, def.Colour.white );
    def.drawCenteredText( "Press P or Enter to resume",  screenCenter.x, screenCenter.y + 20, 20, def.Colour.white );
    def.drawCenteredText( "Press V to change view mode", screenCenter.x, screenCenter.y + 60, 20, def.Colour.white );
  }
}