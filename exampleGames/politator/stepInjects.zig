const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine  = def.Engine;
const Body  = def.Body;

const Angle   = def.Angle;
const Vec2    = def.Vec2;
const VecA    = def.VecA;
const Box2    = def.Box2;
const Tile    = def.Tile;
const TileMap = def.Tilemap;

// ================================ GLOBAL GAME VARIABLES ================================

const TileData = stateInj.TileData;

var TILEMAP_DATA = stateInj.TILEMAP_DATA;

const dis_mode_e = enum( u2 )
{
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

  if( def.ray.isKeyPressed( def.ray.KeyboardKey.v ))
  {
    DISPLAY_MODE = switch( DISPLAY_MODE )
    {
      .ALL => .POP,
      .POP => .INF,
      .INF => .RES,
      .RES => .ALL,
    };
    def.log( .INFO, 0, @src(), "Swapped display mode to {s}", .{ @tagName( DISPLAY_MODE )});
  }

  var worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
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

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_add ))
    {
      var newInfCount : f32 = @floatFromInt( data.infCount );
          newInfCount      *= 1.1;
          newInfCount       = @ceil( newInfCount );

      data.infCount = @intFromFloat( newInfCount );
      data.infCount = def.clmp( data.infCount, 0, INF_MAX_SIZE );
    }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_subtract ))
    {
      var newInfCount : f32 = @floatFromInt( data.infCount );
          newInfCount      *= 0.9;
          newInfCount       = @ceil( newInfCount );

      data.infCount = @intFromFloat( newInfCount );
      data.infCount = def.clmp( data.infCount, 0, INF_MAX_SIZE );
    }
  }

}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
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
        newPopCount       = def.clmp( newPopCount, 0, @intCast( POP_MAX_SIZE ));

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
        newInfCount       = def.clmp( newInfCount, 0, @intCast( INF_MAX_SIZE ));

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
        newResCount       = def.clmp( newResCount, 0, @intCast( RES_MAX_SIZE ));

    ownData.nextResCount += @intCast( newResCount );


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

            migrantCount = def.clmp( migrantCount, 0, @intFromFloat( maxMigrantOut ));

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

    data.popCount = def.clmp( data.nextPopCount, 0, POP_MAX_SIZE );
    data.resCount = def.clmp( data.nextResCount, 0, RES_MAX_SIZE );
    data.infCount = def.clmp( data.nextInfCount, 0, INF_MAX_SIZE );
  }
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
   POP_MAX_SEEN = 0;

  const worldGrid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( World Grid ) not found", .{ stateInj.GRID_ID });
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

    const r : f32 = @floor( 255.0 * def.lerp( 0.0, 1.0, displayPop ));
    const g : f32 = @floor( 255.0 * def.lerp( 0.0, 1.0, displayRes ));
    const b : f32 = @floor( 255.0 * def.lerp( 0.0, 1.0, displayInf ));

    switch( DISPLAY_MODE )
    {
      .ALL => tile.colour = .{ .r = @intFromFloat( r ), .g = @intFromFloat( g ), .b = @intFromFloat( b ), .a = 255 },
      .POP => tile.colour = .{ .r = @intFromFloat( r ), .g = 0,                  .b = 0,                  .a = 255 },
      .INF => tile.colour = .{ .r = 0,                  .g = @intFromFloat( g ), .b = 0,                  .a = 255 },
      .RES => tile.colour = .{ .r = 0,                  .g = 0,                  .b = @intFromFloat( b ), .a = 255 },
    }
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

    var popBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var dPopBuff = std.mem.zeroes([ 32:0 ]u8 );
    var migBuff  = std.mem.zeroes([ 32:0 ]u8 );

    var resBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var dResBuff = std.mem.zeroes([ 32:0 ]u8 );

    var infBuff  = std.mem.zeroes([ 32:0 ]u8 );
    var dInfBuff = std.mem.zeroes([ 32:0 ]u8 );

    _ = std.fmt.bufPrint( &popBuff, "PopCount : {d}", .{ data.popCount }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format pop count : {}", .{ err });
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


    _ = std.fmt.bufPrint( &resBuff, "ResCount : {d}", .{ data.resCount }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format res count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dResBuff, "ResDelta : +{d}, -{d}", .{ data.lastResGrowth, data.lastResLoss }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format res delta : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &infBuff, "InfCount : {d}", .{ data.infCount }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format inf count : {}", .{ err });
      return;
    };

    _ = std.fmt.bufPrint( &dInfBuff, "InfDelta : +{d}, -{d}", .{ data.lastInfGrowth, data.lastInfLoss }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to format inf delta : {}", .{ err });
      return;
    };

    def.drawCenteredText( &popBuff,  screenCenter.x * 0.5, 32, 24, def.Colour.nWhite );
    def.drawCenteredText( &dPopBuff, screenCenter.x * 0.5, 64, 24, def.Colour.nWhite );
    def.drawCenteredText( &migBuff,  screenCenter.x * 0.5, 96, 24, def.Colour.nWhite );

    def.drawCenteredText( &resBuff,  screenCenter.x * 1.0, 32, 24, def.Colour.nWhite );
    def.drawCenteredText( &dResBuff, screenCenter.x * 1.0, 64, 24, def.Colour.nWhite );

    def.drawCenteredText( &infBuff,  screenCenter.x * 1.5, 32, 24, def.Colour.nWhite );
    def.drawCenteredText( &dInfBuff, screenCenter.x * 1.5, 64, 24, def.Colour.nWhite );
  }
}