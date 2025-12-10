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
var MAX_POP_SEEN  : u32 = 0;

const POP_MAX_SIZE        : u32 = 1024 * 1024; // > 0
const POP_GROWTH_RATE     : f32 = 0.01; // > 1.0
const POP_RES_CONSUMPTION : f32 = 0.10; // < 1.0
const POP_MIGRATION_RATE  : f32 = 0.01; // < 0.1666
const POP_DEATH_RATE      : f32 = 0.02; // < 1.0

const RES_MAX_SIZE        : u32 = 1024; // > 0
const RES_GROWTH_BONUS    : u32 = 4;    // > 0 to avoid total resource collapse
const RES_GROWTH_RATE     : f32 = 0.05; // > 1.0


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
      var newPopCount : f32 = @floatFromInt( data.popCount );
          newPopCount      *= 1.1;
          newPopCount       = @ceil( newPopCount );

      data.popCount = @intFromFloat( newPopCount );
      data.popCount = def.clmp( data.popCount, 0, POP_MAX_SIZE );
    }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.down ))
    {
      var newPopCount : f32 = @floatFromInt( data.popCount );
          newPopCount      *= 0.9;
          newPopCount       = @ceil( newPopCount );

      data.popCount = @intFromFloat( newPopCount );
      data.popCount = def.clmp( data.popCount, 0, POP_MAX_SIZE );
    }

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.right ))
    {
      var newResCount : f32 = @floatFromInt( data.resCount );
          newResCount      *= 1.1;
          newResCount       = @ceil( newResCount );

      data.resCount = @intFromFloat( newResCount );
      data.resCount = def.clmp( data.resCount, 0, RES_MAX_SIZE );
    }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.left ))
    {
      var newResCount : f32 = @floatFromInt( data.resCount );
          newResCount      *= 0.9;
          newResCount       = @ceil( newResCount );

      data.resCount = @intFromFloat( newResCount );
      data.resCount = def.clmp( data.resCount, 0, RES_MAX_SIZE );
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

  // Reseting key tile values
  MAX_POP_SEEN = 0;

  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    var data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    data.nextPopCount = 0;
    data.nextResCount = 0;

    data.lastPopGrowth = 0;
    data.lastPopLoss   = 0;

    data.lastPopIn  = 0;
    data.lastPopOut = 0;

    data.lastResGrowth = 0;
    data.lastResLoss   = 0;
  }

  // Calculating next pop and resources for each tile
  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    var ownData : *TileData = @alignCast( @ptrCast( tile.script.data.? ));


    // Calculating tile resource availability
    var ownResPerPop : f32 = @floatFromInt( ownData.resCount );
        ownResPerPop      /= @floatFromInt( ownData.popCount );


    // Calculating size of migrant cohorts
    var migrationSize : f32 = @floatFromInt( ownData.popCount );
        migrationSize      *= POP_MIGRATION_RATE;
        migrationSize       = @ceil( migrationSize );


//    // Updating in-tile population growth
//    var basePopGrowth : f32 = @floatFromInt( ownData.popCount );
//
//        if( ownResPerPop > POP_RES_CONSUMPTION )
//        { basePopGrowth *= POP_GROWTH_RATE; }
//        else { basePopGrowth = 0; }
//
//        basePopGrowth = @ceil( basePopGrowth );
//
//    // Updating in-tile population growth
//    const basePop : f32 = @floatFromInt( ownData.popCount );
//    var popChange = basePop;
//
//        if( ownResPerPop > POP_RES_CONSUMPTION )
//        { popChange *= POP_GROWTH_RATE; }
//        else { popChange = 0; }
//
//        popChange = @ceil( popChange );
//
//    ownData.lastPopGrowth = @intFromFloat( popChange );
//    ownData.nextPopCount += ownData.lastPopGrowth;
//
//
//    // Updating in-tile population loss
//    if( ownResPerPop < POP_RES_CONSUMPTION )
//    {
//      var deadPop : f32 = @floatFromInt( ownData.nextPopCount );
//          deadPop      *= POP_DEATH_RATE;
//          deadPop       = @ceil( deadPop );
//
//      ownData.lastPopLoss   = @intFromFloat( deadPop );
//      ownData.nextPopCount -= ownData.lastPopLoss;
//
//      if( ownData.nextPopCount > MAX_POP_SEEN ){ MAX_POP_SEEN = ownData.nextPopCount; }
//    }


    // Updating in-tile population
    var popLoss : f32 = @floatFromInt( ownData.popCount );
        popLoss      *= POP_DEATH_RATE;

        if( ownResPerPop >= POP_RES_CONSUMPTION ){ popLoss = 0; }

    ownData.lastPopLoss = @intFromFloat( @ceil( popLoss ));


    var popGrowth : f32 = @floatFromInt( ownData.popCount );
        popGrowth      *= POP_GROWTH_RATE;

        if( ownResPerPop < POP_RES_CONSUMPTION ){ popGrowth = 0; }

    ownData.lastPopGrowth = @intFromFloat( @ceil( popGrowth ));


    var newPopCount : i32 = @intCast( ownData.popCount );
        newPopCount      -= @intCast( ownData.lastPopLoss );
        newPopCount      += @intCast( ownData.lastPopGrowth );
        newPopCount       = def.clmp( newPopCount, 0, @intCast( POP_MAX_SIZE ));

    ownData.nextPopCount += @intCast( newPopCount );


    // Updating in-tile resources
    var resLoss : f32 = @floatFromInt( ownData.popCount );
        resLoss      *= POP_RES_CONSUMPTION;

    ownData.lastResLoss = @intFromFloat( @ceil( resLoss ));


    var resGrowth : f32 = @floatFromInt( ownData.resCount );
        resGrowth      *= RES_GROWTH_RATE;
        resGrowth      += RES_GROWTH_BONUS;

    ownData.lastResGrowth = @intFromFloat( @ceil( resGrowth ));


    var newResCount : i32 = @intCast( ownData.resCount );
        newResCount      -= @intCast( ownData.lastResLoss );
        newResCount      += @intCast( ownData.lastResGrowth );
        newResCount       = def.clmp( newResCount, 0, @intCast( RES_MAX_SIZE ));

    ownData.nextResCount  = @intCast( newResCount );


    // Migrating populations to richer neighbours
    for( def.e_dir_2.arr )| dir |
    {
      const n = worldGrid.getNeighbourTile( tile.mapCoords, dir ) orelse
      {
        def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
        continue;
      };

      const nData : *TileData = @alignCast( @ptrCast( n.script.data.? ));

      // Calculating neighbour resource availability
      var nResPerPop : f32 = @floatFromInt( nData.resCount );
      if( nData.popCount > 1 ){ nResPerPop /= @floatFromInt( nData.popCount ); }

      // Migrating 1 cohort out if need be
      const migrantCount : u32 = @intFromFloat( migrationSize );

      if( nResPerPop > ownResPerPop and ownData.nextPopCount >= migrantCount )
      {
        ownData.lastPopOut   += migrantCount;
        ownData.nextPopCount -= migrantCount;

        nData.lastPopIn      += migrantCount;
        nData.nextPopCount   += migrantCount;
      }
    }
  }

  // Updating pop and resources for each tiles based on previous calculation
  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    var data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    MAX_POP_SEEN  = def.clmp( data.nextPopCount, 255, POP_MAX_SIZE );
    data.popCount = def.clmp( data.nextPopCount, 0, POP_MAX_SIZE );
    data.resCount = def.clmp( data.nextResCount, 0, RES_MAX_SIZE );

    var displayPop : f32 = @floatFromInt( data.popCount );
        displayPop      /= @floatFromInt( MAX_POP_SEEN );

    var displayRes : f32 = @floatFromInt( data.resCount );
        displayRes      /= @floatFromInt( RES_MAX_SIZE );

    const red  : f32 = @floor( 255.0 * def.lerp( 0.0, 1.0, displayPop ));
    const blue : f32 = @floor( 255.0 * def.lerp( 0.0, 1.0, displayRes ));

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
  const screenCenter = def.getHalfScreenSize();

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.drawCenteredText( "Paused",                     screenCenter.x, ( screenCenter.y * 2 ) - 96, 64, def.Colour.yellow );
    def.drawCenteredText( "Press P or Enter to resume", screenCenter.x, ( screenCenter.y * 2 ) - 32, 32, def.Colour.yellow );
  }

  if( SELECTED_TILE )| tile |
  {
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var popBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var resBuff  = std.mem.zeroes([ 32:0 ]u8 );

    var dPopBuff = std.mem.zeroes([ 32:0 ]u8 );
    var migBuff  = std.mem.zeroes([ 32:0 ]u8 );

    var dResBuff = std.mem.zeroes([ 32:0 ]u8 );

    _ = std.fmt.bufPrint( &popBuff, "PopCount : {d}", .{ data.popCount }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format pop count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &resBuff, "ResCount : {d}", .{ data.resCount }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format res count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dPopBuff, "PopDelta : +{d}, -{d}", .{ data.lastPopGrowth, data.lastPopLoss }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format pop delta counts : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &migBuff, "Migrants : +{d}, -{d}", .{ data.lastPopIn, data.lastPopOut }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format pop migration counts : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dResBuff, "ResDelta : +{d}, -{d}", .{ data.lastResGrowth, data.lastResLoss }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format res delta : {}", .{ err });
      return;
    };

    def.drawCenteredText( &popBuff,  screenCenter.x, 32, 32, def.Colour.yellow );
    def.drawCenteredText( &resBuff,  screenCenter.x, 64, 32, def.Colour.yellow );

    def.drawCenteredText( &dPopBuff, screenCenter.x, 96, 32, def.Colour.yellow );
    def.drawCenteredText( &migBuff,  screenCenter.x, 128, 32, def.Colour.yellow );

    def.drawCenteredText( &dResBuff, screenCenter.x, 160, 32, def.Colour.yellow );

  }
}