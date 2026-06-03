const std      = @import( "std" );
const eng      = @import( "engine" );
const utl = @import( "utils" );
const stateInj = @import( "stateInjects.zig" );

const Engine  = eng.Engine;
const Body  = eng.Body;

const Angle   = utl.Angle;
const Vec2    = utl.Vec2;
const VecA    = utl.VecA;
const Box2    = utl.Box2;
const Tile    = eng.Tile;
const TileMap = eng.Tilemap;

// ================================ GLOBAL GAME VARIABLES ================================

const TileData = stateInj.TileData;

var TILEMAP_DATA = stateInj.TILEMAP_DATA;

const dis_mode_e = enum( u2 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  ALL,
  POP,
  INF,
  RES,
};

var DISPLAY_MODE  : dis_mode_e = .ALL;
var SELECTED_TILE : ?*Tile = null;
var POP_MAX_SEEN  : u32 = 0;

const POP_MAX_SIZE        : u32 = 1024 * 1024; // > 0
const POP_GROWTH_RATE     : f32 = 0.01; // < 1
const POP_MIGRATION_RATE  : f32 = 0.01; // < 1/6
const POP_DEATH_RATE      : f32 = 0.03; // < 1

const POP_RES_CONSUMPTION : f32 = 0.10; // > 0
const POP_INF_PRODUCTION  : f32 = 0.02; // > 0

const INF_MAX_SIZE        : u32 = 1024; // > 256
const INF_DECAY_RATE      : f32 = 0.01; // < 1
const INF_POP_DEMAND      : f32 = 1.00; // > 0
const INF_RES_PRODUCTION  : f32 = 0.10; // > 0

const RES_MAX_SIZE        : u32 = 1024; // > 256
const RES_GROWTH_RATE     : f32 = 0.04; // > 0
const RES_GROWTH_BONUS    : f32 = 4.00; // > 0 to avoid total resource collapse



// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateFrame( ng : *eng.Engine ) void
{
  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w )){ eng.G_CAM.moveByS( Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s )){ eng.G_CAM.moveByS( Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a )){ eng.G_CAM.moveByS( Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d )){ eng.G_CAM.moveByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_CAM.zoomBy( 1.1 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_CAM.zoomBy( 0.9 ); }

  // Reset the camera zoom and position when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_CAM.setZoom(   1.0 );
    eng.G_CAM.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reset" );
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.v ))
  {
    DISPLAY_MODE = switch( DISPLAY_MODE )
    {
      .ALL => .POP,
      .POP => .INF,
      .INF => .RES,
      .RES => .ALL,
    };
    utl.log( .INFO, 0, @src(), "Swapped display mode to {s}", .{ @tagName( DISPLAY_MODE )});
  }

  var worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Keep the camera over the world grid
  eng.G_CAM.clampCenterInArea( worldGrid.getMapBoundingBox() );

  if( utl.ray.isMouseButtonPressed( utl.ray.MouseButton.left ))
  {
    const mouseWorldPos = utl.getMouseWorldPos();

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
    var data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.up ))
    {
      var newPopCount : f32 = @floatFromInt( data.popCount );
          newPopCount      *= 1.1;
          newPopCount       = @ceil( newPopCount );

      data.popCount = @intFromFloat( newPopCount );
      data.popCount = utl.clmp( data.popCount, 0, POP_MAX_SIZE );
    }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.down ))
    {
      var newPopCount : f32 = @floatFromInt( data.popCount );
          newPopCount      *= 0.9;
          newPopCount       = @ceil( newPopCount );

      data.popCount = @intFromFloat( newPopCount );
      data.popCount = utl.clmp( data.popCount, 0, POP_MAX_SIZE );
    }

    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.right ))
    {
      var newResCount : f32 = @floatFromInt( data.resCount );
          newResCount      *= 1.1;
          newResCount       = @ceil( newResCount );

      data.resCount = @intFromFloat( newResCount );
      data.resCount = utl.clmp( data.resCount, 0, RES_MAX_SIZE );
    }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.left ))
    {
      var newResCount : f32 = @floatFromInt( data.resCount );
          newResCount      *= 0.9;
          newResCount       = @ceil( newResCount );

      data.resCount = @intFromFloat( newResCount );
      data.resCount = utl.clmp( data.resCount, 0, RES_MAX_SIZE );
    }

    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_add ))
    {
      var newInfCount : f32 = @floatFromInt( data.infCount );
          newInfCount      *= 1.1;
          newInfCount       = @ceil( newInfCount );

      data.infCount = @intFromFloat( newInfCount );
      data.infCount = utl.clmp( data.infCount, 0, INF_MAX_SIZE );
    }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_subtract ))
    {
      var newInfCount : f32 = @floatFromInt( data.infCount );
          newInfCount      *= 0.9;
          newInfCount       = @ceil( newInfCount );

      data.infCount = @intFromFloat( newInfCount );
      data.infCount = utl.clmp( data.infCount, 0, INF_MAX_SIZE );
    }
  }

}


pub fn OnTickWorld( ng : *eng.Engine ) void
{
  const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const tileCount = worldGrid.getTileCount();

  // Reseting key tile values
  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    var data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    data.nextPopCount = 0;
    data.nextResCount = 0;
    data.nextInfCount = 0;

    data.lastPopGrowth = 0;
    data.lastPopLoss   = 0;

    data.lastPopIn  = 0;
    data.lastPopOut = 0;

    data.lastResGrowth = 0;
    data.lastResLoss   = 0;

    data.lastInfGrowth = 0;
    data.lastInfLoss   = 0;
  }

  // Calculating next pop and resources for each tile
  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    var ownData : *TileData = @alignCast( @ptrCast( tile.script.data.? ));


    // Calculating tile resource & population availability
    var ownPopResAccess : f32 = @floatFromInt( ownData.resCount );

        if( ownData.popCount > 1 ){ ownPopResAccess /= @floatFromInt( ownData.popCount ); }

        ownPopResAccess      /= POP_RES_CONSUMPTION;

    var ownInfPopAccess : f32 = @floatFromInt( ownData.popCount );

        if( ownData.infCount > 1 ){ ownInfPopAccess /= @floatFromInt( ownData.infCount ); }

        ownInfPopAccess      /= INF_POP_DEMAND;


    // Calculating size of migrant cohorts
    var maxMigrationSize : f32 = @floatFromInt( ownData.popCount );
        maxMigrationSize      *= POP_MIGRATION_RATE;
        maxMigrationSize       = @ceil( maxMigrationSize );


    // Updating in-tile population

    var popLoss : f32 = @floatFromInt( ownData.popCount );
        popLoss      *= POP_DEATH_RATE;
        popLoss      *= 1.0 - ownPopResAccess;

        if( ownPopResAccess >= 1.0 ){ popLoss = 0; }

    ownData.lastPopLoss += @intFromFloat( @ceil( popLoss ));


    var popGrowth : f32 = @floatFromInt( ownData.popCount );
        popGrowth      *= POP_GROWTH_RATE;

        if( ownPopResAccess < 1.0 ){ popGrowth = 0; }

    ownData.lastPopGrowth += @intFromFloat( @ceil( popGrowth ));


    var newPopCount : i32 = @intCast( ownData.popCount );
        newPopCount      -= @intCast( ownData.lastPopLoss );
        newPopCount      += @intCast( ownData.lastPopGrowth );
        newPopCount       = utl.clmp( newPopCount, 0, @as( i32, @intCast( POP_MAX_SIZE )));

    ownData.nextPopCount += @intCast( newPopCount );


    // Updating in-tile infrastructure

    var infLoss : f32 = @floatFromInt( ownData.infCount );
        infLoss      *= INF_DECAY_RATE;
        infLoss      *= 1.0 - ownInfPopAccess;

        if( ownInfPopAccess >= 1.0 ){ infLoss = 0; }

    ownData.lastInfLoss += @intFromFloat( @ceil( infLoss ));


    var infGrowth : f32 = @floatFromInt( ownData.popCount );
        infGrowth      *= POP_INF_PRODUCTION;

        if( ownInfPopAccess < 1.0 ){ infGrowth = 0; }

    ownData.lastInfGrowth += @intFromFloat( @ceil( infGrowth ));


    var newInfCount : i32 = @intCast( ownData.infCount );
        newInfCount      -= @intCast( ownData.lastInfLoss );
        newInfCount      += @intCast( ownData.lastInfGrowth );
        newInfCount       = utl.clmp( newInfCount, 0, @as( i32, @intCast( INF_MAX_SIZE )));

    ownData.nextInfCount += @intCast( newInfCount );


    // Updating in-tile resources

    var resPopLoss : f32 = @floatFromInt( ownData.popCount );
        resPopLoss      *= POP_RES_CONSUMPTION;

    ownData.lastResLoss = @intFromFloat( @ceil( resPopLoss ));


    var resNatGrowth : f32 = @floatFromInt( ownData.resCount );
        resNatGrowth      *= RES_GROWTH_RATE;
        resNatGrowth      += RES_GROWTH_BONUS;

    ownData.lastResGrowth += @intFromFloat( @ceil( resNatGrowth ));


    var resInfGrowth : f32 = @floatFromInt( ownData.infCount );
        resInfGrowth      *= INF_RES_PRODUCTION;

        if( ownInfPopAccess < 1.0 ){ resInfGrowth *= ownInfPopAccess; }

    ownData.lastResGrowth += @intFromFloat( @ceil( resInfGrowth ));


    var newResCount : i32 = @intCast( ownData.resCount );
        newResCount      -= @intCast( ownData.lastResLoss );
        newResCount      += @intCast( ownData.lastResGrowth );
        newResCount       = utl.clmp( newResCount, 0, @as( i32, @intCast( RES_MAX_SIZE )));

    ownData.nextResCount += @intCast( newResCount );


    // Migrating populations to richer neighbours

    for( utl.e_dir_2.arr )| dir |
    {
      const n = worldGrid.getNeighbourTile( tile.mapCoords, dir ) orelse
      {
        utl.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
        continue;
      };

      const nData : *TileData = @alignCast( @ptrCast( n.script.data.? ));

      // Calculating neighbour resource availability
      var nPopResAccess : f32 = @floatFromInt( nData.resCount );

      if( nData.popCount > 1 ){ nPopResAccess /= @floatFromInt( nData.popCount ); }

          nPopResAccess /= POP_RES_CONSUMPTION;

      // Migrating 1 cohort out if need be

      if( nPopResAccess > ownPopResAccess )
      {
        var migrantCount : u32 = @intFromFloat( @ceil( maxMigrationSize * ownPopResAccess / nPopResAccess ));

        var maxMigrantOut : f32 = @floatFromInt( ownData.nextPopCount );
            maxMigrantOut      /= 6.0;
            maxMigrantOut       = @floor( maxMigrantOut );

            migrantCount = utl.clmp( migrantCount, 0, @as( u32, @intFromFloat( maxMigrantOut )));

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

    data.popCount = utl.clmp( data.nextPopCount, 0, POP_MAX_SIZE );
    data.resCount = utl.clmp( data.nextResCount, 0, RES_MAX_SIZE );
    data.infCount = utl.clmp( data.nextInfCount, 0, INF_MAX_SIZE );
  }
}


pub fn OnRenderWorld( ng : *eng.Engine ) void
{
   POP_MAX_SEEN = 0;

  const worldGrid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    utl.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const tileCount = worldGrid.getTileCount();

  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    if( data.popCount > POP_MAX_SEEN ){ POP_MAX_SEEN = data.popCount; }
  }

  for( 0 .. tileCount )| index |
  {
    const tile : *Tile = &worldGrid.tileArray.items.ptr[ index ];

    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var displayPop : f32 = @floatFromInt( data.popCount );
        displayPop      /= @floatFromInt( POP_MAX_SEEN );

    var displayRes : f32 = @floatFromInt( data.resCount );
        displayRes      /= @floatFromInt( RES_MAX_SIZE );

    var displayInf : f32 = @floatFromInt( data.infCount );
        displayInf      /= @floatFromInt( INF_MAX_SIZE );

    const r : f32 = @floor( 255.0 * utl.lerp( 0.0, 1.0, displayPop ));
    const g : f32 = @floor( 255.0 * utl.lerp( 0.0, 1.0, displayRes ));
    const b : f32 = @floor( 255.0 * utl.lerp( 0.0, 1.0, displayInf ));

    switch( DISPLAY_MODE )
    {
      .ALL => tile.colour = .{ .r = @intFromFloat( r ), .g = @intFromFloat( g ), .b = @intFromFloat( b ), .a = 255 },
      .POP => tile.colour = .{ .r = @intFromFloat( r ), .g = 0,                  .b = 0,                  .a = 255 },
      .INF => tile.colour = .{ .r = 0,                  .g = @intFromFloat( g ), .b = 0,                  .a = 255 },
      .RES => tile.colour = .{ .r = 0,                  .g = 0,                  .b = @intFromFloat( b ), .a = 255 },
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
    utl.sDraw.textCenter( "Paused",                      .new( screenCenter.x, ( screenCenter.y * 2.0 ) - 96.0 ), 64, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press P or Enter to resume",  .new( screenCenter.x, ( screenCenter.y * 2.0 ) - 32.0 ), 32, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press V to change view mode", .new( screenCenter.x,   screenCenter.y + 60.0         ), 20, utl.Colour.white );
  }

  if( SELECTED_TILE )| tile |
  {
    const data : *TileData = @alignCast( @ptrCast( tile.script.data.? ));

    var popBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var dPopBuff = std.mem.zeroes([ 32:0 ]u8 );
    var migBuff  = std.mem.zeroes([ 32:0 ]u8 );

    var resBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var dResBuff = std.mem.zeroes([ 32:0 ]u8 );

    var infBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var dInfBuff = std.mem.zeroes([ 32:0 ]u8 );

    _ = std.fmt.bufPrint( &popBuff, "PopCount : {d}", .{ data.popCount }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format pop count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dPopBuff, "PopDelta : +{d}, -{d}", .{ data.lastPopGrowth, data.lastPopLoss }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format pop delta counts : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &migBuff, "Migrants : +{d}, -{d}", .{ data.lastPopIn, data.lastPopOut }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format pop migration counts : {}", .{ err });
      return;
    };


    _ = std.fmt.bufPrint( &resBuff, "ResCount : {d}", .{ data.resCount }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format res count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dResBuff, "ResDelta : +{d}, -{d}", .{ data.lastResGrowth, data.lastResLoss }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format res delta : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &infBuff, "InfCount : {d}", .{ data.infCount }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format inf count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dInfBuff, "InfDelta : +{d}, -{d}", .{ data.lastInfGrowth, data.lastInfLoss }) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to format inf delta : {}", .{ err });
      return;
    };

    utl.sDraw.textCenter( &popBuff,  .new( screenCenter.x * 0.5, 32.0 ), 24, utl.Colour.nWhite );
    utl.sDraw.textCenter( &dPopBuff, .new( screenCenter.x * 0.5, 64.0 ), 24, utl.Colour.nWhite );
    utl.sDraw.textCenter( &migBuff,  .new( screenCenter.x * 0.5, 96.0 ), 24, utl.Colour.nWhite );

    utl.sDraw.textCenter( &resBuff,  .new( screenCenter.x * 1.0, 32.0 ), 24, utl.Colour.nWhite );
    utl.sDraw.textCenter( &dResBuff, .new( screenCenter.x * 1.0, 64.0 ), 24, utl.Colour.nWhite );

    utl.sDraw.textCenter( &infBuff,  .new( screenCenter.x * 1.5, 32.0 ), 24, utl.Colour.nWhite );
    utl.sDraw.textCenter( &dInfBuff, .new( screenCenter.x * 1.5, 64.0 ), 24, utl.Colour.nWhite );
  }
}