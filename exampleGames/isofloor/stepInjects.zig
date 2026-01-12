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

const TileData = stateInj.TileData;

var TILEMAP_DATA = stateInj.TILEMAP_DATA;


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateInputs( ng : *def.Engine ) void
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

  var worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( World ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Keep the camera inside over the map area
  ng.clampCameraCenterInArea( worldGrid.getMapBoundingBox() );


  const mouseScreenPos = def.ray.getMousePosition();
  const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreenPos, ng.getCameraCpy().?.toRayCam() );

  const worldCoords = worldGrid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

  if( worldCoords != null )
  {
    const tile = worldGrid.getTile( worldCoords.? ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, worldGrid.id });
      return;
    };

    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
    {
      def.log( .INFO, 0, @src(), "Left-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      _ = data;
    }

    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.middle ))
    {
      def.log( .INFO, 0, @src(), "Middle-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      _ = data;
    }

    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
    {
      def.log( .INFO, 0, @src(), "Right-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      _ = data;
    }
  }

}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.GRID_ID });
    return;
  };

  _ = worldGrid; // Prevent unused variable warning
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

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
  }
}