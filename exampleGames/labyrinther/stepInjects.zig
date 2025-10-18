const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Entity = def.Entity;

const Angle  = def.Angle;
const Vec2   = def.Vec2;
const VecA   = def.VecA;
const Box2   = def.Box2;

// ================================ GLOBAL GAME VARIABLES ================================




// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopCycle( ng : *def.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdateInputs( ng : *def.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

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

  var mazeMap = ng.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Maze ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  // Keep the camera inside over the maze area
  ng.clampCameraCenterInArea( mazeMap.getMapBoundingBox() );

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
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.q )){ mazeMap.gridPos.a = mazeMap.gridPos.a.subDeg( 1 ); }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.e )){ mazeMap.gridPos.a = mazeMap.gridPos.a.addDeg( 1 ); }

  // If left clicked, check if a tile was clicked on the example tilemap
  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    const mouseScreemPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreemPos, ng.getCameraCpy().?.toRayCam() );

    const worldCoords = mazeMap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
        return;
      };

      // Change the color of the clicked tile
      clickedTile.colour = def.G_RNG.getColour();

      // Change the color of all neighbouring tiles to their direction color
      const dirArray = [_]def.e_dir_2{ .NO, .NE, .EA, .SE, .SO, .SW, .WE, .NW };
      for( dirArray )| dir |
      {

        const n_coords = mazeMap.getNeighbourCoords( clickedTile.gridCoords, dir ) orelse
        {
          def.log( .TRACE, 0, @src(), "No northern neighbour in direcetion {s} found for tile at {d}:{d} in tilemap {d}",
                  .{ @tagName( dir ), clickedTile.gridCoords.x, clickedTile.gridCoords.y, mazeMap.id });
          continue;
        };

        var n_tile = mazeMap.getTile( n_coords ) orelse
        {
          def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ n_coords.x, n_coords.y, mazeMap.id });
          continue;
        };

        n_tile.colour = dir.getDebugColour();
      }
    }
  }
}

// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  const mazeMap = ng.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  _ = mazeMap; // Prevent unused variable warning
}

pub fn OffTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    const screenCenter = def.getHalfScreenSize();

    def.coverScreenWith( def.Colour.init( 0, 0, 0, 128 ));
    def.drawCenteredText( "Paused", screenCenter.x, screenCenter.y - 20, 40, def.Colour.white );
    def.drawCenteredText( "Press P or Enter to resume", screenCenter.x, screenCenter.y + 20, 20, def.Colour.white );
  }
}