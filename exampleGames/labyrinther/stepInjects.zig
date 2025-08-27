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
  // Toggle pause if the P key is pressed // TODO: Use pause to show options
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  if( ng.isPlaying() )
  {
    // Move the camera with the WASD or arrow keys
    if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ ng.moveCameraBy( Vec2.new(  0, -8 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ ng.moveCameraBy( Vec2.new(  0,  8 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ ng.moveCameraBy( Vec2.new( -8,  0 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ ng.moveCameraBy( Vec2.new(  8,  0 )); }


    // Zoom in and out with the mouse wheel
    if( def.ray.getMouseWheelMove() > 0.0 ){ ng.zoomCameraBy( 11.0 / 10.0 ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ ng.zoomCameraBy(  9.0 / 10.0 ); }

    // Reset the camera zoom and position when r is pressed
    if( def.ray.isKeyDown( def.ray.KeyboardKey.r ))
    {
      ng.setCameraZoom( 1.0 );
      ng.setCameraTarget( .{} );
      def.qlog( .INFO, 0, @src(), "Camera reseted" );
    }
  }

  var mazeMap = ng.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Maze ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  // Clamp the camera to the maze area
  var viewableScale = mazeMap.gridSize.toVec2().mul( mazeMap.tileScale ).mulVal( 0.5 );

  if( mazeMap.tileShape == .DIAM ){ viewableScale = viewableScale.mulVal( @sqrt( 2.0 ));
  }
  viewableScale = viewableScale.add( ng.getCameraViewBox().?.scale );

  ng.clampCameraInArea( Box2.new( .{}, viewableScale ));

  // Swap tilemap render style if the V key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.v ))
  {
    switch( mazeMap.tileShape )
    {
      .RECT =>
      {
        mazeMap.tileShape = .DIAM;
        mazeMap.tileScale.y = mazeMap.tileScale.x * 0.5;
      },

      .DIAM =>
      {
        mazeMap.tileShape = .RECT;
        mazeMap.tileScale.y = mazeMap.tileScale.x;
      },
      else  => mazeMap.tileShape = .RECT, // Default case
    }
    def.log( .INFO, 0, @src(), "Maze tilemap shape changed to {s}", .{ @tagName( mazeMap.tileShape )});
  }

  // If left clicked, check if a tile was clicked on the example tilemap
  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    const mouseScreemPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreemPos, ng.getCameraCpy().? );

    const worldCoords = mazeMap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
        return;
      };

      // Change the tile color to a random color
      clickedTile.colour = def.G_RNG.getColour();
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


// NOTE : This is where you should render all background effects ( sky, etc. )
pub fn OnRenderBackground( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning

  def.ray.clearBackground( def.Colour.black ); // Clear the screen with a black color
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