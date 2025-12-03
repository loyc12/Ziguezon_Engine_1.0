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

const TILE_MINE_1 = stateInj.TILE_MINE_1;
const TILE_MINE_2 = stateInj.TILE_MINE_2;
const TILE_MINE_3 = stateInj.TILE_MINE_3;
const TILE_HIDDEN = stateInj.TILE_HIDDEN;
const TILE_SHOWN  = stateInj.TILE_SHOWN;

const NUM_SIZE : f32 = 24;

var FLAG_COUNT : u32 = 0;
var LIFE_COUNT : i32 = 5;

var HAS_WON : bool = false;
var IS_INIT : bool = false;



// ================================ HELPER FUNCTIONS ================================

fn getNeighbourMineCount( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) u32
{
  _ = ng;

  var res : u32 = 0;

  for( def.e_dir_2.arr )| dir |
  {
    const n = grid.getNeighbourTile( tile.mapCoords, dir ) orelse
    {
      def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
      continue;
    };

    if( n.tType == TILE_MINE_1 ){ res += 1; }
    if( n.tType == TILE_MINE_2 ){ res += 2; }
    if( n.tType == TILE_MINE_3 ){ res += 3; }
  }
  return res;
}

fn getNeighbourFlagCount( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) u32
{
  _ = ng;

  var res : u32 = 0;

  for( def.e_dir_2.arr )| dir |
  {
    const n = grid.getNeighbourTile( tile.mapCoords, dir ) orelse
    {
      def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
      continue;
    };

    if( n.colour.isEq( .blue  ) or n.colour.isEq( .yellow )){ res += 1; }
    if( n.colour.isEq( .lBlue ) or n.colour.isEq( .orange )){ res += 2; }
    if( n.colour.isEq( .mBlue ) or n.colour.isEq( .red    )){ res += 3; }
  }
  return res;
}

fn initGrid( ng : *def.Engine, grid : *def.Tilemap, startTile : *def.Tile ) void
{
  _ = ng;

  IS_INIT = true;

  var remaingingMineCount = stateInj.MINE_COUNT;

  for( 0 .. grid.getTileCount() )| index |
  {
    const remaingingTileCount = grid.getTileCount() - index; // preemptively decrease the count to avoid duplicating code

    var tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    // Prevents having tiles at or around the first clicked cell
    if( tile.mapCoords.isEq( startTile.mapCoords )){ continue; }
    if( grid.areCoordsNeighbours( tile.mapCoords, startTile.mapCoords )){ continue; }

    tile.colour = .mGray;

    // getting a random value between 0.0 and 1.0
    const noiseVal = def.G_RNG.getFloat( f32 );

    // determining the odds of this tile being a mine
    var threshold : f32 = @floatFromInt( remaingingMineCount );
        threshold      /= @floatFromInt( remaingingTileCount );

    // if value > odds, tile is set as mine ( wall )
    if( remaingingMineCount > 0 and noiseVal < threshold )
    {
      remaingingMineCount -= 1;
      const mineTypeNoiseVal = def.G_RNG.getFloat( f32 );

      if(      mineTypeNoiseVal < 0.5 ){ tile.tType  = TILE_MINE_1; } //tile.colour = .lGreen; }
      else if( mineTypeNoiseVal < 0.8 ){ tile.tType  = TILE_MINE_2; } //tile.colour = .mGreen; }
      else{                              tile.tType  = TILE_MINE_3; } //tile.colour = .dGreen; }
    }
  }


  if( remaingingMineCount != 0 )
  {
    def.qlog( .ERROR, 0, @src(), "@ Failed to assign the proper amount of mines !" );
  }
  else
  {
    def.qlog( .INFO, 0, @src(), "$ Assigned all mines properly !" );
  }
}


// revealing a tile
fn leftCLickTile( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) void
{

  // Does nothing if a flagged tile was clicked
  if( tile.colour.isEq( .blue  )){  return; }
  if( tile.colour.isEq( .lBlue  )){ return; }
  if( tile.colour.isEq( .mBlue )){  return; }

  // Initialize the board on first click, so that no mine is struct first
  if( !IS_INIT ){ initGrid( ng, grid, tile ); }

  // Does nothing if an uncovered mine was clicked
  if( tile.colour.isEq( .yellow )){ return; }
  if( tile.colour.isEq( .orange )){ return; }
  if( tile.colour.isEq( .red    )){ return; }

  // Check if a mine was clicked
  if( tile.tType == TILE_MINE_1 )
  {
    tile.colour = .yellow;
    FLAG_COUNT += 1;
    LIFE_COUNT -= 1;

    def.log( .INFO, 0, @src(), "@ Clicked on a small mine at {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    return;
  }
  if( tile.tType == TILE_MINE_2 )
  {
    tile.colour = .orange;
    FLAG_COUNT += 1;
    LIFE_COUNT -= 2;

    def.log( .INFO, 0, @src(), "@ Clicked on a medium mine at {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    return;
  }
  if( tile.tType == TILE_MINE_3 )
  {
    tile.colour = .red;
    FLAG_COUNT += 1;
    LIFE_COUNT -= 3;

    def.log( .INFO, 0, @src(), "@ Clicked on a large mine at {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    return;
  }

  if( tile.tType == TILE_SHOWN )
  {
    const tileMineCount = getNeighbourMineCount( ng, grid, tile );
    const tileFlagCount = getNeighbourFlagCount( ng, grid, tile );

    if( tileFlagCount > 0 and tileFlagCount == tileMineCount )
    {
      for( def.e_dir_2.arr )| dir |
      {
        const n = grid.getNeighbourTile( tile.mapCoords, dir ) orelse
        {
          def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
          continue;
        };

        if( n.tType != TILE_SHOWN ){ leftCLickTile( ng, grid, n ); }
      }
    }
  }

  floodDiscoverCheck( ng, grid, tile );

  if( !HAS_WON and LIFE_COUNT > 0 )
  {
    HAS_WON = playerHasWon( ng, grid );
  }
}

// (un)flagging a tile
fn rightCLickTile( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) void
{
  _ = ng;
  _ = grid;

  if( !IS_INIT ){return; }

  // Does nothing if a uncovered tile was clicked
  if( tile.tType == TILE_SHOWN ){ return; }

  // Does nothing if a uncovered mine was clicked
  if( tile.colour.isEq( .yellow )
  or  tile.colour.isEq( .orange )
  or  tile.colour.isEq( .red    )){ return; }

  // Using current colour to check if flagged or not ( sketchy roundabout bullshit )
  if(      tile.colour.isEq( .blue  )){ tile.colour = .lBlue; }
  else if( tile.colour.isEq( .lBlue )){ tile.colour = .mBlue; }
  else if( tile.colour.isEq( .mBlue ))
  {
    def.log( .INFO, 0, @src(), "# Removing a flag on {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    FLAG_COUNT -= 1;
    tile.colour = .mGray;
  }
  else
  {
    def.log( .INFO, 0, @src(), "# Adding a flag on {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    tile.colour = .blue ;
    FLAG_COUNT += 1;
  }
}


fn floodDiscoverCheck( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) void
{
  // Recursion safety bound
  if( tile.tType != TILE_HIDDEN  ){ return; }

  // Setting the tile as discovered
  tile.tType = TILE_SHOWN;

  if( tile.colour.isEq( .blue  )
  or  tile.colour.isEq( .lBlue )
  or  tile.colour.isEq( .mBlue )){ FLAG_COUNT -= 1; }

  tile.colour = .lGray;
  // finding the tile's new colour
  const nMineCount = getNeighbourMineCount( ng, grid, tile );


  // Don't recursively call checks neighbour is there is any mines around
  if( nMineCount > 0 ){ return; }

  // Recursively check all neighbours
  for( def.e_dir_2.arr )| dir |
  {
    const n = grid.getNeighbourTile( tile.mapCoords, dir ) orelse
    {
      def.log( .TRACE, 0, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), tile.mapCoords.x, tile.mapCoords.y });
      continue;
    };

    // Don't call self on mines
    if( n.tType == TILE_MINE_1
    or  n.tType == TILE_MINE_2
    or  n.tType == TILE_MINE_3 ){ continue; }

    floodDiscoverCheck( ng, grid, n );
  }
}

fn playerHasWon( ng : *def.Engine, grid : *def.Tilemap ) bool
{
  _ = ng;

  for( 0 .. grid.getTileCount() )| index |
  {
    const tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    if( tile.tType == TILE_HIDDEN ){ return false; }
  }
  return true;
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

  if( HAS_WON or LIFE_COUNT <= 0 )
  {
    // prevent further action if game was won or lost
    return;
  }

  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ) or def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
  {
    const mouseScreenPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreenPos, ng.getCameraCpy().?.toRayCam() );

    const worldCoords = grid.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords == null ){ return; }

    def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

    const clickedTile = grid.getTile( worldCoords.? ) orelse
    {
      def.log( .WARN, 0, @src(), "No tile found at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });
      return;
    };

    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left  )){ leftCLickTile(  ng, grid, clickedTile ); }
    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.right )){ rightCLickTile( ng, grid, clickedTile ); }
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
  var lifeBuff : [ 16:0 ]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };


  const mineCountSlice = std.fmt.bufPrint( &mineBuff, "Mines : {d}", .{ stateInj.MINE_COUNT - FLAG_COUNT }) catch | err |
  {
      def.log( .ERROR, 0, @src(), "Failed to format mineCount : {}", .{ err });
      return;
  };
  const lifeCountSlice = std.fmt.bufPrint( &lifeBuff, "Lives : {d}", .{ LIFE_COUNT }) catch | err |
  {
      def.log( .ERROR, 0, @src(), "Failed to format lifeCount : {}", .{ err });
      return;
  };

  mineBuff[ mineCountSlice.len ] = 0;
  lifeBuff[ lifeCountSlice.len ] = 0;

  const cam = ng.getCameraCpy() orelse
  {
    def.qlog( .ERROR, 0, @src(), "No main camera initialized" );
    return;
  };
  const screenCenter = def.ray.getWorldToScreen2D( .{ .x = 0, .y = 0 }, cam.toRayCam() );

  def.drawCenteredText( &mineBuff, screenCenter.x - 256, 64, 32, def.Colour.red   );
  def.drawCenteredText( &lifeBuff, screenCenter.x + 256, 64, 32, def.Colour.green );


  var grid = ng.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  for( 0 .. grid.getTileCount() )| index |
  {
    const tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    const tileCenter = def.ray.getWorldToScreen2D( grid.getAbsTilePos( tile.mapCoords ).toRayVec2(), cam.toRayCam() );

    if(      tile.colour.isEq( .blue   )){ def.drawCenteredText( "1", tileCenter.x, tileCenter.y, NUM_SIZE, .white ); }
    else if( tile.colour.isEq( .lBlue  )){ def.drawCenteredText( "2", tileCenter.x, tileCenter.y, NUM_SIZE, .white ); }
    else if( tile.colour.isEq( .mBlue  )){ def.drawCenteredText( "3", tileCenter.x, tileCenter.y, NUM_SIZE, .white ); }

    else if( tile.colour.isEq( .yellow )){ def.drawCenteredText( "1", tileCenter.x, tileCenter.y, NUM_SIZE, .black ); }
    else if( tile.colour.isEq( .orange )){ def.drawCenteredText( "2", tileCenter.x, tileCenter.y, NUM_SIZE, .black ); }
    else if( tile.colour.isEq( .red    )){ def.drawCenteredText( "3", tileCenter.x, tileCenter.y, NUM_SIZE, .black ); }

    if( tile.tType != TILE_SHOWN ){ continue; }

    const nMineCount = getNeighbourMineCount( ng, grid, tile );
    if( nMineCount == 0 ){ continue; }

    var numBuff : [ 2:0 ]u8 = .{ 0, 0 };

    const numSlice = std.fmt.bufPrint( &numBuff, "{d}", .{ nMineCount }) catch | err |
    {
      def.log(.ERROR, 0, @src(), "Failed to format value : {}", .{ err });
      return;
    };

    numBuff[ numSlice.len ] = 0;

    const numCol = switch( nMineCount )
    {
      1    => def.Colour.cerul,
      2    => def.Colour.cyan,
      3    => def.Colour.green,
      4    => def.Colour.yellow,
      5    => def.Colour.gold,
      6    => def.Colour.orange,
      7    => def.Colour.red,
      8    => def.Colour.fuchsia,
      9    => def.Colour.purple,
      else => def.Colour.indigo,
    };

    def.drawCenteredText( &numBuff, tileCenter.x, tileCenter.y, NUM_SIZE, numCol );

  }

  if( LIFE_COUNT <= 0 )
  {
    def.coverScreenWithCol( def.Colour.new( 0, 0, 0, 128 ));
    def.drawCenteredText( "L + SKILL ISSUE + WOMP WOMP + LMFAO + STAY MAD", screenCenter.x, screenCenter.y, 50, .red );
  }
  else if( HAS_WON )
  {
    def.coverScreenWithCol( def.Colour.new( 0, 0, 0, 128 ));
    def.drawCenteredText( "W + SKILLFUL + HELL YEAH + ROFL + STAY GLAD", screenCenter.x, screenCenter.y, 50, .green );
  }
}