const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Entity = def.Entity;
const Angle  = def.Angle;
const Vec2   = def.Vec2;
const VecA   = def.VecA;

// ================================ GLOBAL GAME VARIABLES ================================

var DRAW_TEST : bool = true; // Example input-toggled flag


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

  // Toggle the "DRAW_TEST" example flag if the T key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.t ))
  {
    DRAW_TEST = !DRAW_TEST;
    ng.playAudio( "hit_1" );
    def.log( .DEBUG, 0, @src(), "DRAW_TEST is now: {s}", .{ if( DRAW_TEST ) "true" else "false" });
  }

  var exampleTilemap = ng.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
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

      def.log( .INFO, 0, @src(), "Clicked on tile with coords {d}:{d} in tilemap {d}", .{ clickedTile.gridCoords.x, clickedTile.gridCoords.y, exampleTilemap.id });

      // Change the tile color to a random color
      clickedTile.colour = def.G_RNG.getColour();
    }
    else
    {
      def.log( .INFO, 0, @src(), "No tile found at mouse world position {d}:{d}", .{ mouseWorldPos.x, mouseWorldPos.y });
    }
  }
}

// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  var exampleEntity = ng.getEntity( stateInj.EXAMPLE_NTT_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Entity ) not found", .{ stateInj.EXAMPLE_NTT_ID });
    return;
  };

  exampleEntity.pos.a = exampleEntity.pos.a.rotDeg( exampleEntity.pos.a.cos() + 1.5 ); // Example of a simple variable rotation effect
  exampleEntity.pos.y  = 256  * exampleEntity.pos.a.sin();                             // Example of a simple variable vertical movement effect


  var exampleTilemap = ng.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  exampleTilemap.gridPos.a = exampleTilemap.gridPos.a.rotRad( 0.01 ); // Example of a simple variable rotation effect


  var exampleRLine = ng.getEntity( stateInj.EXAMPLE_RLIN_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Radius Line ) not found", .{ stateInj.EXAMPLE_RLIN_ID });
    return;
  };

  exampleRLine.pos.a = exampleTilemap.gridPos.a;


  var exampleDLine = ng.getEntity( stateInj.EXAMPLE_DLIN_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Diametre Line ) not found", .{ stateInj.EXAMPLE_DLIN_ID });
    return;
  };

  exampleDLine.pos.a = exampleTilemap.gridPos.a;


  var exampleTriangle = ng.getEntity( stateInj.EXAMPLE_TRIA_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Triangle ) not found", .{ stateInj.EXAMPLE_TRIA_ID });
    return;
  };

  exampleTriangle.pos.a = exampleTilemap.gridPos.a;


  var exampleRectangle = ng.getEntity( stateInj.EXAMPLE_RECT_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Rectangle ) not found", .{ stateInj.EXAMPLE_RECT_ID });
    return;
  };

  exampleRectangle.pos.a = exampleTilemap.gridPos.a;


  var exampleHexagon = ng.getEntity( stateInj.EXAMPLE_HEXA_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Hexagon ) not found", .{ stateInj.EXAMPLE_HEXA_ID });
    return;
  };

  exampleHexagon.pos.a = exampleTilemap.gridPos.a;


  var exampleEllipse = ng.getEntity( stateInj.EXAMPLE_ELLI_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Ellipse ) not found", .{ stateInj.EXAMPLE_ELLI_ID });
    return;
  };

  exampleEllipse.pos.a = exampleTilemap.gridPos.a;
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
  if( DRAW_TEST ) // Example of a flag toggled feature
  {
    def.drawCenteredText( "TEST", def.getHalfScreenWidth(), def.getHalfScreenHeight(), 64, def.Colour.green );
  }

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.coverScreenWith( def.Colour.init( 0, 0, 0, 128 ));
  }
}