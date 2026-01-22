const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine  = def.Engine;
const Entity  = def.Entity;

const Angle   = def.Angle;
const Vec2    = def.Vec2;
const VecA    = def.VecA;
const Box2    = def.Box2;
const Tile    = def.Tile;
const TileMap = def.Tilemap;

// ================================ GLOBAL GAME VARIABLES ================================

const TileData = stateInj.TileData;

var TILEMAP_DATA = stateInj.TILEMAP_DATA;

var SELECTED_TILE : ?*Tile = null;



// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateInputs( ng : *def.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w )){ ng.moveCameraByS( Vec2.new(  0, -8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s )){ ng.moveCameraByS( Vec2.new(  0,  8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a )){ ng.moveCameraByS( Vec2.new( -8,  0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d )){ ng.moveCameraByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ ng.zoomCameraBy( 1.1 ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ ng.zoomCameraBy( 0.9 ); }

  // Reset the camera zoom and position when r is pressed
  if( def.ray.isKeyDown( def.ray.KeyboardKey.r ))
  {
    ng.setCameraZoom(   1.0 );
    ng.setCameraCenter( .{} );
    ng.setCameraRot(    .{} );
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }

  var worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Keep the camera over the world grid
  ng.clampCameraCenterInArea( worldGrid.getMapBoundingBox() );

  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    const mouseScreemPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreemPos, ng.getCameraCpy().?.toRayCam() );

    const worldCoords = worldGrid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      const clickedTile = worldGrid.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, worldGrid.id });
        return;
      };

      SELECTED_TILE = clickedTile;
    }
  }

  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
  {
    SELECTED_TILE = null;
  }

  if( SELECTED_TILE )| tile |
  {
    var data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.up ))
    {
      data.noiseVal = def.clmp( data.noiseVal + 0.01, 0.0, 1.0 - def.EPS );
    }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.down ))
    {
      data.noiseVal = def.clmp( data.noiseVal - 0.01, 0.0, 1.0 - def.EPS );
    }
  }

}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const tileCount = worldGrid.getTileCount();

  _ = tileCount;
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  const worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const tileCount = worldGrid.getTileCount();

  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    const shade : u8 = @intFromFloat( @floor( 256 * def.clmp( data.noiseVal, 0.0, 1.0 - def.EPS )));

    tile.colour = .{ .r = shade, .g = shade, .b = shade, .a = 255 };
  }
}

pub fn OffRenderWorld( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void
{
  const screenCenter = def.getHalfScreenSize();

  def.drw_u.drawRectanglePlus( .{ .x = screenCenter.x, .y = 0 }, .{ .x = screenCenter.x, .y = 128 }, .{}, .{ .r = 0, .g = 0, .b = 0, .a = 64 });

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.drawCenteredText( "Paused",                      screenCenter.x, ( screenCenter.y * 2 ) - 96, 64, def.Colour.yellow );
    def.drawCenteredText( "Press P or Enter to resume",  screenCenter.x, ( screenCenter.y * 2 ) - 32, 32, def.Colour.yellow );
    def.drawCenteredText( "Press V to change view mode", screenCenter.x, screenCenter.y + 60, 20, def.Colour.white );
  }

  if( SELECTED_TILE )| tile |
  {
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var noiseValBuff = std.mem.zeroes([ 32:0 ]u8 );

    _ = std.fmt.bufPrint( &noiseValBuff, "Nosie Value : {d}", .{ data.noiseVal }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format noiseVal : {}", .{ err });
      return;
    };

    def.drawCenteredText( &noiseValBuff,  screenCenter.x, 32, 24, def.Colour.nWhite );
  }
}