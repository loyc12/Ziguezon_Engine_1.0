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

      data.ground = switch( data.ground )
      {
        .Empty => .Floor,
        .Floor => .Wall,
        .Wall  => .Door1,
        .Door1 => .Empty,
      };

    }

    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.middle ))
    {
      def.log( .INFO, 0, @src(), "Middle-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      data.object = switch( data.object )
      {
        .Empty => .Entry,
        .Entry => .Exit,
        .Exit  => .Key1,
        .Key1  => .Empty,
      };
    }

    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
    {
      def.log( .INFO, 0, @src(), "Right-clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      data.mobile = switch( data.mobile )
      {
        .Empty  => .Player,
        .Player => .Enemy,
        .Enemy  => .Empty,
      };
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

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    tile.colour.r = switch( data.mobile )
    {
      .Empty  => 0,
      .Player => 128,
      .Enemy  => 255,
    };

    tile.colour.g = switch( data.object )
    {
      .Empty => 0,
      .Entry => 85,
      .Exit  => 190,
      .Key1  => 255,
    };

    tile.colour.b = switch( data.ground )
    {
      .Empty => 0,
      .Floor => 85,
      .Wall  => 190,
      .Door1 => 255,
    };
  }
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

const FLOOR_ID  : u32 = (  7 * 16 ) + 1;
const WALL_ID   : u32 = (  0 * 16 ) + 0;

const ENTRY_ID  : u32 = ( 11 * 16 ) + 0;
const EXIT_1_ID : u32 = ( 15 * 16 ) + 3;
const EXIT_2_ID : u32 = ( 15 * 16 ) + 2;

const KEY_1_ID  : u32 = (  0 * 16 ) + 5;
const DOOR_1_ID : u32 = (  8 * 16 ) + 5;

const PLAYER_ID : u32 = ( 15 * 16 ) + 1;
const ENEMY_ID  : u32 = (  4 * 16 ) + 0;

const sScale  : f32 = 32 * 0.08839;
const sOffset : f32 = sScale / 4;

pub fn OffRenderWorld( ng : *def.Engine ) void
{
  const worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.GRID_ID });
    return;
  };

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var groundID : ?u32 = null;

    groundID = switch( data.ground )
    {
      .Empty => null,
      .Floor => FLOOR_ID,
      .Wall  => WALL_ID,
      .Door1 => DOOR_1_ID,
    };


    var tilePos : VecA = tile.relPos.?.toVecA( .{} ).add( worldGrid.mapPos );

    tilePos.y -= worldGrid.tileScale.y * sOffset;

    if( groundID )| spriteID |
    {
      ng.drawFromSprite( "cubes_1", spriteID, tilePos, .{ .x = sScale, .y = sScale }, .white );
    }
  }

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var objectID : ?u32 = null;

    objectID = switch( data.object )
    {
      .Empty => null,
      .Entry => ENTRY_ID,
      .Exit  => EXIT_1_ID,
      .Key1  => KEY_1_ID,
    };


    var tilePos : VecA = tile.relPos.?.toVecA( .{} ).add( worldGrid.mapPos );

    tilePos.y -= worldGrid.tileScale.y * sOffset;

    if( objectID )| spriteID |
    {
      ng.drawFromSprite( "cubes_1", spriteID, tilePos, .{ .x = sScale, .y = sScale }, .white );
    }
  }

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var mobileID : ?u32 = null;

    mobileID = switch( data.mobile )
    {
      .Empty  => null,
      .Player => PLAYER_ID,
      .Enemy  => ENEMY_ID,
    };

    var tilePos : VecA = tile.relPos.?.toVecA( .{} ).add( worldGrid.mapPos );

    tilePos.y -= worldGrid.tileScale.y * sOffset;

    if( data.object == .Entry ){ tilePos.y -= worldGrid.tileScale.y * sOffset; }
    if( data.object == .Exit and mobileID == PLAYER_ID ){ mobileID = EXIT_2_ID; }

    if( mobileID )| spriteID |
    {
      ng.drawFromSprite( "cubes_1", spriteID, tilePos, .{ .x = sScale, .y = sScale }, .white );
    }
  }
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