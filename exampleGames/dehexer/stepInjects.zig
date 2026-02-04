const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Body = def.Body;

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

//const NUM_SIZE : f32 = 24;

var DIFFICULTY : f32 = 20.0; // baby = 12% easy = 16%, normal == 20%, hard = 24%, insane = 28%
var MINE_COUNT : u32 = 250;  // baby = 150 easy = 200, normal == 250, hard = 300, insane = 350

var LIFE_COUNT : i32 = 5;
var FLAG_COUNT : u32 = 0;

var HAS_WON    : bool = false;
var IS_INIT    : bool = false;

var shake_prog  : f32 = 0.0;
var shake_force : f32 = 0.0;

var end_text_scale : f32 = 0;

const shaker : def.Shaker2D = .{
  .beg_lenght = 0.03,
  .mid_lenght = 0.04,
  .end_lenght = 0.03,
};



// ================================ HELPER FUNCTIONS ================================

fn setMinecolour( tile : *def.Tile ) void
{
  switch( tile.tType )
  {
    TILE_MINE_1 => tile.colour = .yellow,
    TILE_MINE_2 => tile.colour = .orange,
    TILE_MINE_3 => tile.colour = .red,
    else => {},
  }
}


fn blowUpMine( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile, damage : u32 ) void
{
  FLAG_COUNT += 1;
  shake_prog  = 0.0;
  shake_force = @floatFromInt( damage );

  _ = ng;

  switch( damage )
  {
    0 => return,
    1 =>
    {
      LIFE_COUNT -= 1;
      def.log( .INFO, 0, @src(), "@ Clicked on a small mine at {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    },
    2 =>
    {
      LIFE_COUNT -= 2;
      def.log( .INFO, 0, @src(), "@ Clicked on a medium mine at {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    },
    else =>
    {
      LIFE_COUNT -= 3;
      def.log( .INFO, 0, @src(), "@ Clicked on a large mine at {d}:{d}", .{ tile.mapCoords.x, tile.mapCoords.y });
    },
  }

  setMinecolour( tile );

  // Reveal remaining mines if player died
  if( LIFE_COUNT <= 0 )
  {
    for( 0 .. grid.getTileCount() )| index |
    {
      const iTile : *def.Tile = &grid.tileArray.items.ptr[ index ];

      setMinecolour( iTile );
    }
  }
}

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

  const tileCount : u32 = grid.getTileCount();

  var initMineCount  = DIFFICULTY * 0.01;
      initMineCount *= @floatFromInt( tileCount );

  MINE_COUNT = @intFromFloat( @floor( initMineCount ));
  FLAG_COUNT = 0;

  var remaingingMineCount = MINE_COUNT;

  for( 0 .. tileCount )| index |
  {
    const remaingingTileCount = tileCount - index; // preemptively decrease the count to avoid duplicating code

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

  IS_INIT = true;
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
  if( tile.tType == TILE_MINE_1 ){ return blowUpMine( ng, grid, tile, 1 ); }
  if( tile.tType == TILE_MINE_2 ){ return blowUpMine( ng, grid, tile, 2 ); }
  if( tile.tType == TILE_MINE_3 ){ return blowUpMine( ng, grid, tile, 3 ); }

  // Autoclick neighbouring tiles when number matched flagged + revealed
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

  if( !HAS_WON and LIFE_COUNT > 0 ){ HAS_WON = playerHasWon( ng, grid ); }

}

// (un)flagging a tile
fn rightCLickTile( ng : *def.Engine, grid : *def.Tilemap, tile : *def.Tile ) void
{
  _ = ng;
  _ = grid;

  if( !IS_INIT ){ return; }

  // Does nothing if an uncovered tile was clicked
  if( tile.tType == TILE_SHOWN ){ return; }

  // Does nothing if an uncovered mine was clicked
  if( tile.colour.isEq( .yellow )
  or  tile.colour.isEq( .orange )
  or  tile.colour.isEq( .red    )){ return; }

  // Using current colour to check if flagged or not ( sketchy roundabout bullshit way )
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
  var grid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  // Shake the screen on mine explosion
  if( shake_prog < 0.2 )
  {
    const offset = shaker.getOffsetAtTime( shake_prog );

    ng.camera.pos = .{ .x = offset.x * shake_force * 16, .y = offset.y * shake_force * 16, .a = .{ .r = offset.a.r * shake_force * 2, }};

    shake_prog += ( 1.0 / 120.0 );
  }


  // Restarting Logic
  if( HAS_WON or LIFE_COUNT <= 0 )
  {
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.kp_enter ))
    {
      HAS_WON = false;
      IS_INIT = false;

      LIFE_COUNT    = 5;
      end_text_scale = 0.0;

      grid.fillWithType( TILE_HIDDEN );
      grid.fillWithColour( .mGray );
    }


    return; // NOTE : Prevents further action if game was won or lost
  }

  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ) or def.ray.isMouseButtonPressed( def.ray.MouseButton.right ))
  {
    const mouseScreenPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreenPos, ng.camera.toRayCam() );

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

  if( !IS_INIT )
  {
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.up ))
    {
      DIFFICULTY = def.clmp( DIFFICULTY + 2.0, 2.0, 32.0 );
    //DIFFICULTY = @min( @max( DIFFICULTY + 2.0, 10.0 ), 30.0 );
    }
    else if( def.ray.isKeyPressed( def.ray.KeyboardKey.down ))
    {
      DIFFICULTY = def.clmp( DIFFICULTY - 2.0, 2.0, 32.0 );
    //DIFFICULTY = @min( @max( DIFFICULTY - 2.0, 10.0 ), 30.0 );
    }

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.left ))
    {
      LIFE_COUNT = def.clmp( LIFE_COUNT - 1, 1, 12 );
    }
    else if( def.ray.isKeyPressed( def.ray.KeyboardKey.right ))
    {
      LIFE_COUNT = def.clmp( LIFE_COUNT + 1, 1, 12 );
    }
  }

}

pub fn OnTickWorld( ng : *def.Engine ) void
{
  const grid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  _ = grid; // Prevent unused variable warning
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  // NOTE : All active bodies are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void
{
  var mineBuff = std.mem.zeroes([ 32:0 ]u8 );
  var lifeBuff = std.mem.zeroes([ 32:0 ]u8 );

  // This shit ugly af, no cap
  const diffName =
    if      ( DIFFICULTY <=  2 ) "Difficulty : Bruh fr?"
    else if ( DIFFICULTY <=  8 ) "Difficulty : Babymode"
    else if ( DIFFICULTY <= 12 ) "Difficulty : Easypeasy"
    else if ( DIFFICULTY <= 16 ) "Difficulty : Easy"
    else if ( DIFFICULTY <= 20 ) "Difficulty : Normal"
    else if ( DIFFICULTY <= 24 ) "Difficulty : Hard"
    else if ( DIFFICULTY <= 28 ) "Difficulty : Extreme"
    else                         "Difficulty : Insane";


  if( !IS_INIT )
  {
    _ = std.fmt.bufPrint( &mineBuff, "Difficulty : {d}%", .{ DIFFICULTY }) catch | err |
    {
        def.log( .ERROR, 0, @src(), "Failed to format mineCount : {}", .{ err });
        return;
    };

    _ = std.fmt.bufPrint( &lifeBuff, "Lives : {d}", .{ LIFE_COUNT }) catch | err |
    {
        def.log( .ERROR, 0, @src(), "Failed to format lifeCount : {}", .{ err });
        return;
    };
  }
  else
  {
    var unmarkedMineCount : i32 = @intCast( MINE_COUNT );
        unmarkedMineCount      -= @intCast( FLAG_COUNT );

    _ = std.fmt.bufPrint( &mineBuff, "Mines : {d}", .{ unmarkedMineCount }) catch | err |
    {
        def.log( .ERROR, 0, @src(), "Failed to format mineCount : {}", .{ err });
        return;
    };

    _ = std.fmt.bufPrint( &lifeBuff, "Lives : {d}", .{ LIFE_COUNT }) catch | err |
    {
        def.log( .ERROR, 0, @src(), "Failed to format lifeCount : {}", .{ err });
        return;
    };
  }


  const screenCenter = def.ray.getWorldToScreen2D( .{ .x = 0, .y = 0 }, ng.camera.toRayCam() );


  var grid = ng.tilemapManager.getTilemap( stateInj.GRID_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with Id {d} ( Grid ) not found", .{ stateInj.GRID_ID });
    return;
  };

  const scale2 = def.getScreenSize().div( grid.mapSize.toVec2() ).?;

  const scale = @min( scale2.x * 1.0, scale2.y * 1.0 );

  if( grid.tileScale.x != scale )
  {
    grid.tileScale.x = scale;
    grid.tileScale.y = scale;
    grid.mapPos.y    = scale; // gives some space for top UI

    grid.resetCachedTilePos();
  }

  const text_scale = scale * 0.6;

  def.drawCenteredText( &mineBuff, screenCenter.x * 0.75, screenCenter.y * 0.1, text_scale * 2.0, def.Colour.red   );
  def.drawCenteredText( &lifeBuff, screenCenter.x * 1.25, screenCenter.y * 0.1, text_scale * 2.0, def.Colour.green );


  for( 0 .. grid.getTileCount() )| index |
  {
    const tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    const tileCenter = def.ray.getWorldToScreen2D( grid.getAbsTilePos( tile.mapCoords ).toRayVec2(), ng.camera.toRayCam() );

    if(      tile.colour.isEq( .blue   )){ def.drawCenteredText( "1", tileCenter.x, tileCenter.y, text_scale, .white ); }
    else if( tile.colour.isEq( .lBlue  )){ def.drawCenteredText( "2", tileCenter.x, tileCenter.y, text_scale, .white ); }
    else if( tile.colour.isEq( .mBlue  )){ def.drawCenteredText( "3", tileCenter.x, tileCenter.y, text_scale, .white ); }

    else if( tile.colour.isEq( .yellow )){ def.drawCenteredText( "1", tileCenter.x, tileCenter.y, text_scale, .black ); }
    else if( tile.colour.isEq( .orange )){ def.drawCenteredText( "2", tileCenter.x, tileCenter.y, text_scale, .black ); }
    else if( tile.colour.isEq( .red    )){ def.drawCenteredText( "3", tileCenter.x, tileCenter.y, text_scale, .black ); }

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

    def.drawCenteredText( &numBuff, tileCenter.x, tileCenter.y, text_scale, numCol );
  }

  if( !IS_INIT )
  {
    def.coverScreenWithCol( def.Colour.new( 0, 0, 0, 32 ));

    def.drawCenteredText( diffName, screenCenter.x, screenCenter.y * 0.5, text_scale * 3.0, .yellow );

    def.drawCenteredText( "Use up & down arrows to change mine count ( difficulty )",                         screenCenter.x, screenCenter.y * 0.80, text_scale * 2.0, .red    );
    def.drawCenteredText( "Use left & right arrows to change life count",                                     screenCenter.x, screenCenter.y * 1.00, text_scale * 2.0, .green  );
    def.drawCenteredText( "Click any cell to start",                                                          screenCenter.x, screenCenter.y * 1.50, text_scale * 2.0, .yellow );
    def.drawCenteredText( "Dehexer plays like classic minesweeper, with two exception :",                     screenCenter.x, screenCenter.y * 1.65, text_scale * 1.0, .nWhite );
    def.drawCenteredText( "Mines can count for either 1, 2 or 3 'damage', which impacts the displayed value", screenCenter.x, screenCenter.y * 1.75, text_scale * 1.0, .nWhite );
    def.drawCenteredText( "You also only lose the game once you take more damage than you have lives",        screenCenter.x, screenCenter.y * 1.85, text_scale * 1.0, .nWhite );
  }

  if( LIFE_COUNT <= 0 or HAS_WON )
  {
    if( end_text_scale < text_scale * 2.5 ){ end_text_scale = @min( 2.0 + end_text_scale, text_scale * 2.5 ); }

    def.coverScreenWithCol( def.Colour.new( 0, 0, 0, 192 ));

    if( HAS_WON )
    {
      def.drawCenteredText( "W + SKILLFUL + HELL YEAH + ROFL + STAY GLAD", screenCenter.x, screenCenter.y * 0.90, end_text_scale,       .green );
      def.drawCenteredText( "Press Enter to Restart, champ",               screenCenter.x, screenCenter.y * 1.10, end_text_scale * 0.5, .yellow );
    }
    else
    {
      def.drawCenteredText( "L + SKILL ISSUE + WOMP WOMP + LMFAO + STAY MAD", screenCenter.x, screenCenter.y * 0.90, end_text_scale,       .red );
      def.drawCenteredText( "Press Enter to Restart, loser",                  screenCenter.x, screenCenter.y * 1.10, end_text_scale * 0.5, .yellow );
    }
  }


  // Make it so screen shake affects what is currently rendered on the UI ( the whole game )
//if( shake_prog < 0.2 )
//{
//  const offset = shaker.getOffsetAtTime( shake_prog );

//  ng.camera.pos = .{ .x = offset.x * 32, .y = offset.y * 32, .a = .{ .r = offset.a.r * 4, }};

//  shake_prog += ( 1.0 / 120.0 );
//}
}