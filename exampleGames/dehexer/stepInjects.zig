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

const TILE_HIDDEN = def.e_tile_type.T1;
const TILE_SHOWN  = def.e_tile_type.T2;
const TILE_MINE   = def.e_tile_type.T3;

var FLAG_COUNT : u32 = 0;
var EXPLODED   : bool = false;


// ================================ HELPER FUNCTIONS ================================

fn getNeighbourMineCount( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) u32
{
  _ = ng;

  var res : u32 = 0;

  for( def.e_dir_2.arr )| dir |
  {
    const nCoords = grid.getNeighbourCoords( tile.gridCoords, dir ) orelse
    {
      def.log( .TRACE, 0, @src(), "No northern neighbour in direcetion {s} found for tile at {d}:{d} in tilemap {d}",
              .{ @tagName( dir ), tile.gridCoords.x, tile.gridCoords.y, grid.id });
      continue;
    };

    const n = grid.getTile( nCoords ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ nCoords.x, nCoords.y, grid.id });
      continue;
    };

    if( n.tType == TILE_MINE ){ res += 1; }
  }

  return res;
}


fn floodDiscoverCheck( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) void
{
  // Recursion safety bound
  if( tile.tType == TILE_MINE or tile.tType == TILE_SHOWN ){ return; }

  // Setting the tile as discovered
  tile.tType  = TILE_SHOWN;

  // finding the tile's new colour
  const nMineCount = getNeighbourMineCount( ng, grid, tile );

  tile.colour = .pGray;

  // Don't recursively call checks neighbour is there is any mines around
  if( nMineCount > 0 ){ return; }

  // Recursively check all neighbours
  for( def.e_dir_2.arr )| dir |
  {
    const nCoords = grid.getNeighbourCoords( tile.gridCoords, dir ) orelse
    {
      def.log( .TRACE, 0, @src(), "No northern neighbour in direcetion {s} found for tile at {d}:{d}",
              .{ @tagName( dir ), tile.gridCoords.x, tile.gridCoords.y});
      continue;
    };

    const n = grid.getTile( nCoords ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d}", .{ nCoords.x, nCoords.y });
      continue;
    };

    // Don't call self on mines
    if( n.tType == TILE_MINE ){ continue; }

    floodDiscoverCheck( ng, grid, n );
  }
}


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnLoopStart( ng : *def.Engine ) void
{
  _ = ng;
  //ng.changeState( .PLAYING ); // force the game to unpause on start
}


pub fn OnUpdateInputs( ng : *def.Engine ) void
{
  var grid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // If left clicked, try to uncover the tile
  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    const mouseScreenPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreenPos, ng.getCameraCpy().?.toRayCam() );

    const worldCoords = grid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = grid.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });
        return;
      };

      // Does nothing if a flagged tile was clicked
      if( clickedTile.colour.isEq( .blue )){ return; }

      // Check if a mine was clicked
      if( clickedTile.tType == TILE_MINE )
      {
        clickedTile.colour = .red;
        EXPLODED = true;

        def.log( .INFO, 0, @src(), "@ Clicked on a mine at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });
        return;
      }

      floodDiscoverCheck( ng, grid, clickedTile );
    }
  }

  // If right clicked, mark the tile as flagged
  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
  {
    const mouseScreenPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreenPos, ng.getCameraCpy().?.toRayCam() );

    const worldCoords = grid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = grid.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });
        return;
      };

      // Does nothing if a uncovered tile was clicked
      if( clickedTile.tType == TILE_SHOWN ){ return; }

      // Does nothing if a uncovered mine was clicked
      if( clickedTile.colour.isEq( .red )){ return; }

      // Using current colour to check if flagged or not ( sketchy roundabout bullshit )
      if( clickedTile.colour.isEq( .blue ))
      {
        clickedTile.colour = .lGray;
        FLAG_COUNT -= 1;
      }
      else
      {
        clickedTile.colour = .blue;
        FLAG_COUNT += 1;
      }
    }
  }
}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const grid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  _ = grid; // Prevent unused variable warning
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
  var mineBuff : [ 16:0 ]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
  var flagBuff : [ 16:0 ]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

  const mineCountSlice = std.fmt.bufPrint( &mineBuff, "Mines : {d}", .{ stateInj.MINE_COUNT }) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format mineCount : {}", .{err});
      return;
  };
  const flagCountSlice = std.fmt.bufPrint( &flagBuff, "Flags : {d}", .{ FLAG_COUNT }) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format flagCount : {}", .{err});
      return;
  };

  mineBuff[ mineCountSlice.len ] = 0;
  flagBuff[ flagCountSlice.len ] = 0;


  const cam = ng.getCameraCpy() orelse
  {
    def.qlog( .ERROR, 0, @src(), "No main camera initialized" );
    return;
  };
  const screenCenter = def.ray.getWorldToScreen2D( .{ .x = 0, .y = 0 }, cam.toRayCam() ).x;

  def.drawCenteredText( &mineBuff, screenCenter - 256, 64, 32, def.Colour.red );
  def.drawCenteredText( &flagBuff, screenCenter + 256, 64, 32, def.Colour.red );



  var grid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  for( 0 .. grid.getTileCount() )| index |
  {
    const tile : *def.Tile = &grid.tileArray.items.ptr[ index ];
    if( tile.tType != TILE_SHOWN ){ continue; }

    const nMineCount = getNeighbourMineCount( ng, grid, tile );
    if( nMineCount == 0 ){ continue; }

    var numBuff : [ 1:0 ]u8 = .{ 0 };

    const numSlice = std.fmt.bufPrint( &numBuff, "{d}", .{ nMineCount }) catch | err |
    {
      def.log(.ERROR, 0, @src(), "Failed to format value : {}", .{ err });
      return;
    };

    numBuff[ numSlice.len ] = 0;

    const numCol = switch( nMineCount )
    {
      1    => def.Colour.cerul,
      2    => def.Colour.green,
      3    => def.Colour.yellow,
      4    => def.Colour.orange,
      5    => def.Colour.red,
      6    => def.Colour.magenta,
      else => def.Colour.red,
    };

    const tileCenter = def.ray.getWorldToScreen2D( grid.getAbsTilePos( tile.gridCoords ).toRayVec2(), cam.toRayCam() );

    def.drawCenteredText( &numBuff, tileCenter.x, tileCenter.y, 20, numCol );
  }
}