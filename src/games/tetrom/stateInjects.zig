const eng = @import( "engine" );
const utl = @import( "utils" );

const game    = @import( "game.zig" );
const palette = @import( "palette.zig" );
const tlmp    = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

pub const GRID_WIDTH  = game.Board.width;
pub const GRID_HEIGHT = game.Board.height;

const GRID_SCREEN_FILL = 0.825;

/// The grid owns only stable hex geometry. `GAME.board` owns every Tetrom cell.
pub var GRID : Tilemap = .{};
pub var GAME : game.Game = .{};

pub var GRID_SCALE : f64 = 0.0;


// ================================ GRID DISPLAY ================================

/// Returns the initialized geometry grid, or null outside Tetrom's open state.
pub fn getGrid() ?*Tilemap
{
  if( GRID.isInit() ){ return &GRID; }

  utl.qlog( .WARN, @src(), "Tetrom grid is not initialized" );
  return null;
}

/// Updates render-only tile colours from the authoritative game board.
pub fn syncGridDisplay() void
{
  const grid = getGrid() orelse return;

  for( 0 .. grid.getTileCount() )| index |
  {
    const cell = GAME.board.cells[ index ];
    var col = getCellColour( cell );

    if( GAME.getClearDisplayOverride( index ))| clearOverride |
    {
      col = switch( clearOverride )
      {
        .FlashToWhite => | progress | lerpColour( col, palette.WHITE, progress ),
        .FadeToField  => | progress | lerpColour( palette.WHITE, palette.PLAYFIELD, progress ),
      };
    }

    grid.tileArray[ index ].colour = col;
  }
}

pub fn getCellColour( cell : game.Cell ) utl.Colour
{
  return switch( cell )
  {
    .Empty   => palette.PLAYFIELD,
    .Red     => palette.RED,
    .Orange  => palette.ORANGE,
    .Yellow  => palette.YELLOW,
    .Green   => palette.GREEN,
    .Blue    => palette.BLUE,
    .Purple  => palette.PURPLE,
    .Cyan    => palette.CYAN,
    .Magenta => palette.MAGENTA,
    .Lime    => palette.LIME,
    .Rose    => palette.ROSE,
    .Coral   => palette.CORAL,
    .Teal    => palette.TEAL,
    .Bronze  => palette.BRONZE,
    .Silver  => palette.SILVER,
    .Brown   => palette.BROWN,
  };
}

fn lerpColour( from : utl.Colour, to : utl.Colour, progress : f32 ) utl.Colour
{
  const p : f64 = progress;

  return .{
    .r = lerpChannel( from.r, to.r, p ),
    .g = lerpChannel( from.g, to.g, p ),
    .b = lerpChannel( from.b, to.b, p ),
    .a = lerpChannel( from.a, to.a, p ),
  };
}

fn lerpChannel( from : u8, to : u8, progress : f64 ) u8
{
  const fromFloat : f64 = @floatFromInt( from );
  const toFloat   : f64 = @floatFromInt( to );
  return @intFromFloat( @round( utl.lerp( fromFloat, toFloat, progress )));
}

/// Returns the largest uniform `.HEX2` tile scale that stays inside the viewport.
fn getGridScaleForScreen() f64
{
  const screenSize = utl.getScreenSize();

  const gridWidth  : f64 = @floatFromInt( GRID_WIDTH  );
  const gridHeight : f64 = @floatFromInt( GRID_HEIGHT );

  // These are the same half-extents used by `Tilemap.getMapBoundingBox()`.
  // `getGridScaleFactors()` already includes the legacy hex-area scale factor.
  const gridFactors = tlmp.TilemapShape.HEX2.getGridScaleFactors();
  const widthSpan   = 2.0 * (( gridWidth  * gridFactors.x ) + ( 1.0 / 7.2 ));
  const heightSpan  = 2.0 * (( gridHeight * gridFactors.y ) + ( 1.0 / 4.2 ));

  const usableSize = screenSize.mulVal( GRID_SCREEN_FILL );

  return @min( usableSize.x / widthSpan, usableSize.y / heightSpan );
}

/// Rebuilds cached tile positions after a window-size-driven geometry change.
pub fn updateGridScale() void
{
  const grid = getGrid() orelse return;

  const newScale = getGridScaleForScreen();
  if( utl.isFltEq( GRID_SCALE, newScale )){ return; }

  GRID_SCALE = newScale;
  grid.tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE };
  grid.resetCachedTilePos();
}


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  _ = ng;

  if( GRID.isInit() ){ GRID.deinit( utl.getDefaultAlloc() ); }

  GAME.init();
  GRID_SCALE = getGridScaleForScreen();

  GRID = Tilemap.createTilemapFromParams(
  .{
    .mapPos    = .{},
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT },
    .tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE  },
    .tileShape = .HEX2,
  }, .T1, utl.getDefaultAlloc() ) orelse
  {
    utl.qlog( .ERROR, @src(), "Failed to create Tetrom grid" );
    return;
  };

  syncGridDisplay();
}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  _ = ng;

  if( GRID.isInit() ){ GRID.deinit( utl.getDefaultAlloc() ); }
}
