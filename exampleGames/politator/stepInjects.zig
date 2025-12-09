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

var TILEMAP_DATA      = stateInj.TILEMAP_DATA;

const POP_BASE_GROWTH_RATE  : f32 = 1.01; // > 1.0
const POP_RES_CONSUMPTION   : f32 = 0.05; // < 1.0
const POP_MIGRATION_RATE    : f32 = 0.03; // < 0.1666

const RES_BASE_GROWTH_RATE  : f32 = 1.05; // > 1.0
const RES_BASE_GROWTH_BONUS : u32 = 1;

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

      _ = clickedTile;
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

  // Calculating next pop and resources for each tile
  for( 0 .. tileCount )| index |
  {
    const tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];

    var ownData : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    // Calculating tile ressource availability
    var ownResPerPop : f32 = @floatFromInt( ownData.popCount );
        ownResPerPop      /= @floatFromInt( ownData.resCount );

    // Calculating size of migrant cohorts
    var migrationSize : f32 = @floatFromInt( ownData.popCount );
        migrationSize      *= POP_MIGRATION_RATE;
        migrationSize       = @floor( migrationSize );

    // Updating in-tile population
    var basePopGrowth : f32 = @floatFromInt( ownData.popCount );
        basePopGrowth      *= POP_BASE_GROWTH_RATE;
        basePopGrowth       = @ceil( basePopGrowth );

    ownData.nextPopCount += @intFromFloat( basePopGrowth );


    // Updating ressources
    var popConsumption : f32 = @floatFromInt( ownData.nextPopCount );
        popConsumption      *= POP_RES_CONSUMPTION;

    var newResCount : f32 = @floatFromInt( ownData.resCount );
        newResCount      *= RES_BASE_GROWTH_RATE;

        if( newResCount > popConsumption ){ newResCount -= popConsumption; }
        else { newResCount = 0.0; }

        newResCount = @ceil( newResCount );

    ownData.nextResCount = @intFromFloat( newResCount );
    ownData.nextResCount += RES_BASE_GROWTH_BONUS;


    // Migrating populations to richer neighbours
    for( def.e_dir_2.arr )| dir |
    {
      const n = worldGrid.getNeighbourTile( tile.mapCoords, dir ) orelse
      {
        def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
        continue;
      };

      const nData : *TileData = @alignCast( @ptrCast( n.script.data.? ));


      // Calculating neighbour ressource availability
      var nResPerPop : f32 = @floatFromInt( nData.resCount );

      if( nData.popCount > 1 ){ nResPerPop /= @floatFromInt( nData.popCount ); }

      // Migrating 1 cohort if need be
      if( nResPerPop > ownResPerPop )
      {
        ownData.nextPopCount -= @intFromFloat( migrationSize );
        nData.nextPopCount   += @intFromFloat( migrationSize );
      }
    }
  }

  // Updating pop and ressources for each tiles based on previous calculation
  for( 0 .. tileCount )| index |
  {
    const tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];

    var ownData : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    ownData.popCount = def.clmp( ownData.nextPopCount, 0.0, 1024.0 );
    ownData.resCount = def.clmp( ownData.nextResCount, 0.0, 1024.0 );

    ownData.nextPopCount = 0;
    ownData.nextResCount = 0;

    const red  : f32 = @floor( 255.0 * @as( f32, @floatFromInt( def.clmp( ownData.popCount / 1024, 0.0, 1.0 ))));
    const blue : f32 = @floor( 255.0 * @as( f32, @floatFromInt( def.clmp( ownData.resCount / 1024, 0.0, 1.0 ))));

    tile.colour = .{ .r = @intFromFloat( red ), .g = 0, .b = @intFromFloat( blue ), .a = 255 };
  }
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

    def.coverScreenWithCol( .new( 0, 0, 0, 64 ));
    def.drawCenteredText( "Paused",                     screenCenter.x, screenCenter.y - 20, 40, def.Colour.yellow );
    def.drawCenteredText( "Press P or Enter to resume", screenCenter.x, screenCenter.y + 20, 20, def.Colour.yellow );
  }
}