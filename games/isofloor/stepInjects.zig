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

const TileData = stateInj.TileData;

const TILEMAP_DATA = stateInj.TILEMAP_DATA;


// Defining the position index of each sprite

const LOGO_1_ID  : u32 = (  7 * 16 ) + 3;
const LOGO_2_ID  : u32 = (  7 * 16 ) + 4;

const FLOOR_ID  : u32 = (  6 * 16 ) + 0;
const ENTRY_ID  : u32 = ( 14 * 16 ) + 0;
const EXIT_1_ID : u32 = ( 15 * 16 ) + 3;
const EXIT_2_ID : u32 = ( 15 * 16 ) + 2; // Exit with player in

const WALL_ID   : u32 = (  8 * 16 ) + 0;
const DOOR_1_ID : u32 = (  0 * 16 ) + 5;
const KEY_1_ID  : u32 = (  8 * 16 ) + 5;

const PLAYER_ID : u32 = ( 15 * 16 ) + 1;
const ENEMY_ID  : u32 = (  7 * 16 ) + 1;


// Defining some graphical constants

const sScale  : f32 = 32 * 0.08839;
const sOffset : f32 = sScale / 4;


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnFrameUpdate( ng : *eng.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

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

  var worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Keep the camera looking over the map area
  eng.G_ENG.camera.clampCenterInArea( worldGrid.getMapBoundingBox() );

  const mouseWorldPos = eng.G_ENG.camera.getMouseWorldPos();

  const worldCoords = worldGrid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

  if( worldCoords != null )
  {
    const tile = worldGrid.getTile( worldCoords.? ) orelse
    {
      utl.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, worldGrid.id });
      return;
    };

    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.left ))
    {
      utl.log( .INFO, 0, @src(), "Left-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      data.ground = switch( data.ground )
      {
        .Empty => .Floor,
        .Floor => .Entry,
        .Entry => .Exit,
        .Exit  => .Empty,
      };

    }

    if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.right ))
    {
      utl.log( .INFO, 0, @src(), "Right-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      data.object = switch( data.object )
      {
        .Empty  => .Wall,
        .Wall   => .Door1,

        .Door1  => .Key1,
        .Key1   => .Enemy,

        .Enemy  => .Player,
        .Player => .Empty,
      };
    }
  }
}


pub fn OnTickUpdate( ng : *eng.Engine ) void
{
  const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.GRID_ID });
    return;
  };

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *eng.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));


    tile.colour.r = switch( data.ground )
    {
      .Empty => 0,
      .Floor => 85,
      .Entry => 190,
      .Exit  => 255,
    };

    tile.colour.b = switch( data.object )
    {
      .Empty  => 0,
      .Wall   => 51,

      .Door1  => 102,
      .Key1   => 153,

      .Enemy  => 204,
      .Player => 255,
    };
  }
}


pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  // NOTE : All active bodies are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}


pub fn OffRenderWorld( ng : *eng.Engine ) void
{
  const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Example Tilemap ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Draw base floor everywhere that isn't empty
  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *eng.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( data.ground == .Empty ){ continue; }

    var tilePos : VecA = tile.relPos.?.toVecA( .{} ).add( worldGrid.mapPos );

    tilePos.y -= worldGrid.tileScale.y * sOffset;

    ng.resourceManager.drawFromSprite( "cubes_1", FLOOR_ID, tilePos, .{ .x = sScale, .y = sScale }, .white );
  }

  // Draw non-floor ground tiles
  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *eng.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( data.ground == .Empty or data.ground == .Floor ){ continue; }

    const groundId = switch( data.ground )
    {
      .Entry => ENTRY_ID,
      .Exit  => EXIT_1_ID,

      else   => unreachable,
    };

    var tilePos : VecA = tile.relPos.?.toVecA( .{} ).add( worldGrid.mapPos );

    tilePos.y -= worldGrid.tileScale.y * sOffset;

    ng.resourceManager.drawFromSprite( "cubes_1", groundId, tilePos, .{ .x = sScale, .y = sScale }, .white );

  }

  // Draw objects onto floor
  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *eng.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( data.object == .Empty ){ continue; }

    var objectId = switch( data.object )
    {
      .Wall   => WALL_ID,

      .Door1  => DOOR_1_ID,
      .Key1   => KEY_1_ID,

      .Enemy  => ENEMY_ID,
      .Player => PLAYER_ID,

      else    => unreachable,
    };

    var tilePos : VecA = tile.relPos.?.toVecA( .{} ).add( worldGrid.mapPos );

    tilePos.y -= worldGrid.tileScale.y * sOffset;

  //if( data.ground == .Entry ){ tilePos.y -= worldGrid.tileScale.y * sOffset; } // raise objects onto entry podium
    if( data.ground == .Exit and objectId == PLAYER_ID ){ objectId = EXIT_2_ID; }

    ng.resourceManager.drawFromSprite( "cubes_1", objectId, tilePos, .{ .x = sScale, .y = sScale }, .white );
  }
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  const screenCenter = utl.getHalfScreenSize();

  ng.resourceManager.drawScreenFromSprite( "cubes_1", LOGO_1_ID, .{ .x = screenCenter.x - 64, .y = 64 }, .{ .x = 4, .y = 4 }, .white );
  ng.resourceManager.drawScreenFromSprite( "cubes_1", LOGO_2_ID, .{ .x = screenCenter.x + 64, .y = 64 }, .{ .x = 4, .y = 4 }, .white );

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    utl.sDraw.coverScreenWithCol( .new( 0, 0, 0, 128 ));
    utl.sDraw.textCenter( "Paused",                     .new( screenCenter.x, screenCenter.y - 20.0 ), 40.0, utl.Colour.white );
    utl.sDraw.textCenter( "Press P or Enter to resume", .new( screenCenter.x, screenCenter.y + 20.0 ), 20.0, utl.Colour.white );
  }
}