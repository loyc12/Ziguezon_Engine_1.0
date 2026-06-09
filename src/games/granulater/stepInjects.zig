const std      = @import( "std" );
const eng      = @import( "engine" );
const utl = @import( "utils" );
const stateInj = @import( "stateInjects.zig" );

const Engine  = eng.Engine;

const Angle   = utl.Angle;
const Vec2    = utl.Vec2;
const VecA    = utl.VecA;
const Box2    = utl.Box2;
const Tile    = eng.Tile;
const TileMap = eng.Tilemap;

// ================================ GLOBAL GAME VARIABLES ================================

const TileData = stateInj.TileData;

var   TILEMAP_DATA = &stateInj.TILEMAP_DATA;
const NOISE_SCALE  = stateInj.NOISE_SCALE;
var   NOISE_GEN    = &stateInj.NOISE_GEN;


var SELECTED_TILE : ?*Tile = null;


fn getTileData( worldGrid : *TileMap, tile : *Tile ) ?*TileData
{
  const index = worldGrid.getTileIndex( tile.mapCoords ) orelse return null;
  return &TILEMAP_DATA[ index ];
}

// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnInputUpdate( ng : *eng.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w )){ eng.G_ENG.camera.moveByS( Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s )){ eng.G_ENG.camera.moveByS( Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a )){ eng.G_ENG.camera.moveByS( Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d )){ eng.G_ENG.camera.moveByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_ENG.camera.zoomBy( 1.1 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_ENG.camera.zoomBy( 0.9 ); }

  // Reset the camera zoom and position when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_ENG.camera.setZoom(   1.0 );
    eng.G_ENG.camera.cam.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reset" );
  }

  var worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Keep the camera over the world grid
  eng.G_ENG.camera.clampCenterInArea( worldGrid.getMapBoundingBox() );

  if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.left ))
  {
    const mouseWorldPos = eng.G_ENG.camera.getMouseWorldPos();

    const worldCoords = worldGrid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      utl.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      const clickedTile = worldGrid.getTile( worldCoords.? ) orelse
      {
        utl.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, worldGrid.id });
        return;
      };

      SELECTED_TILE = clickedTile;
    }
  }

  if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.right ))
  {
    SELECTED_TILE = null;
  }

  if( SELECTED_TILE )| tile |
  {
    var data = getTileData( worldGrid, tile ) orelse return;

    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.up ))
    {
      data.noiseVal = utl.clmp( data.noiseVal + 0.05, 0.0, 1.0 - utl.EPS );
    }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.down ))
    {
      data.noiseVal = utl.clmp( data.noiseVal - 0.05, 0.0, 1.0 - utl.EPS );
    }
  }

  // Reset the camera zoom and position when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.q ))
  {
    var min_noise : f32 = 1.0;
    var max_noise : f32 = 0.0;

    NOISE_GEN.seed = eng.G_ENG.rng.getInt( u64 );
    utl.log( .INFO, 0, @src(), "Reenerating world with seed '{}'", .{ NOISE_GEN.seed });

    for( 0 .. worldGrid.getTileCount() )| index |
    {
      const tile : *eng.Tile = &worldGrid.tileArray[ index ];

      const noise : f32 = NOISE_GEN.warpedFractalSample( tile.mapCoords.toVec2().mulVal( NOISE_SCALE ));

      if( noise < min_noise ){ min_noise = noise; }
      if( noise > max_noise ){ max_noise = noise; }

      TILEMAP_DATA[ index ] = .{ .noiseVal = noise };
    }
  }


}


pub fn OnTickUpdate( ng : *eng.Engine ) void
{
  const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const tileCount = worldGrid.getTileCount();

  _ = tileCount;
}


pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const tileCount = worldGrid.getTileCount();

  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray[ index ];

    const data : *TileData = &TILEMAP_DATA[ index ];

    const shade : u8 = @intFromFloat( 128 + @floor( 128 * utl.clmp( data.noiseVal, -1.0, 1.0 - utl.EPS )));

    tile.colour = .{ .r = shade, .g = shade, .b = shade, .a = 255 };

    if( data.noiseVal > 0.35 ) // ICE CAPS
    {
      // Do nothing for snow
    }
    else if( data.noiseVal > 0.25 ) // MOUNTAINS
    {
      tile.colour.r -= 64;
      tile.colour.g -= 64;
      tile.colour.b -= 64;
    }
    else if( data.noiseVal > 0.0 ) // GRASS
    {
      tile.colour.r -= 64;
      tile.colour.b -= 128;
    }
    else if( data.noiseVal > -0.05 ) // SAND
    {
      tile.colour.r += 64;
      tile.colour.g += 32;
    }
    else // SEA
    {
      tile.colour.b += 128;
    }
  }
}

pub fn OffRenderWorld( ng : *eng.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  const screenCenter = utl.getHalfScreenSize();

  utl.sDraw.rect( .{ .x = screenCenter.x, .y = 0 }, .{ .x = screenCenter.x, .y = 128 }, .{}, .{ .r = 0, .g = 0, .b = 0, .a = 64 });

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    utl.sDraw.textCenter( "Paused",                      .new( screenCenter.x, ( screenCenter.y * 2.0 ) - 96.0 ), 64.0, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press P or Enter to resume",  .new( screenCenter.x, ( screenCenter.y * 2.0 ) - 32.0 ), 32.0, utl.Colour.yellow );
  }
  utl.sDraw.textCenter( "Press Q to regenerate terrain", .new( screenCenter.x, 32.0 ), 24.0, utl.Colour.nWhite );

  if( SELECTED_TILE )| tile |
  {
    const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
    {
      utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
      return;
    };

    const data = getTileData( worldGrid, tile ) orelse return;

    var noiseValBuff = std.mem.zeroes([ 32:0 ]u8 );

    _ = std.fmt.bufPrint( &noiseValBuff, "Noise Value : {d}", .{ data.noiseVal }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format noiseVal : {}", .{ err });
      return;
    };

    utl.sDraw.textCenter( &noiseValBuff, .new( screenCenter.x, 96.0 ), 24.0, utl.Colour.nWhite );
  }
}
