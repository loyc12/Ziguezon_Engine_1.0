const eng = @import( "engine" );
const utl = @import( "utils" );

const Tile         = eng.Tile;
const Tilemap      = eng.Tilemap;

const TileType = eng.TileType;


// ================================ FLOODRULE STRUCT ================================

fn filterDefault( r : *FloodRule, t : *Tile ) bool { _ = r; _ = t; return true; }
fn changeDefault( r : *FloodRule, t : *Tile ) void { _ = r; _ = t; return; }

pub const FloodRule = struct
{
  // TODO : implement a "max travel distance for ranged floodfills"

  filterData : Tile = .{},
  changeData : Tile = .{},

  filterFunc : *const fn( *FloodRule, *Tile ) bool = filterDefault,
  changeFunc : *const fn( *FloodRule, *Tile ) void = changeDefault,

  pub fn filter( self : *FloodRule, tile : *Tile ) bool { return self.filterFunc( self, tile ); }
  pub fn change( self : *FloodRule, tile : *Tile ) void {        self.changeFunc( self, tile ); }
};



// ================================ BASE FLOODFILL FUNCTIONS ================================

pub inline fn resetFloodMarks( tlmp : *Tilemap ) void
{
  for( tlmp.tileArray )| *tile |{ tile.floodMark = 0; }
  tlmp.floodMark = 0;
}




pub fn floodFillWithParams( tlmp : *Tilemap, start : *Tile, rules : *FloodRule ) void
{
  const alloc = utl.getDefaultAlloc();

  _ = tlmp.beginFloodFill();

  // Explicit stack avoids recursive flood fill and is bounded by the tile count.
  const stack = alloc.alloc( *Tile, tlmp.getTileCount() ) catch | err |
  {
    utl.log( .ERROR, @src(), "Stack initialization error : {} : returning", .{ err });
    return;
  };
  defer alloc.free( stack );

  var stackLen : usize = 0;

  if( tlmp.isFloodMarked( start ) or !rules.filter( start ))
  {
    utl.qlog( .TRACE, @src(), "Invalid start location for floodFill : returning" );
    return;
  }

  tlmp.addFloodMark( start );
  stack[ stackLen ] = start;
  stackLen += 1;

  while( stackLen > 0 )
  {
    stackLen -= 1;
    const cTile = stack[ stackLen ];

    rules.change( cTile );

    for( utl.Dir2.arr )| dir |
    {
      if( tlmp.getNeighbourTile( cTile.mapCoords, dir ))| nTile |
      {
        if( tlmp.isFloodMarked( nTile ) or !rules.filter( nTile ) ){ continue; }
        if( stackLen >= stack.len )
        {
          utl.qlog( .ERROR, @src(), "Flood-fill stack exceeded tile count : returning" );
          return;
        }

        tlmp.addFloodMark( nTile );
        stack[ stackLen ] = nTile;
        stackLen += 1;
      }
    }
  }
}


// ================================ FLOODFILL FUNCTION WRAPPERS ================================

fn filterType( r : *FloodRule, t : *Tile ) bool { return t.tType == r.filterData.tType; }
fn changeType( r : *FloodRule, t : *Tile ) void { t.tType = r.changeData.tType; }

pub fn floodFillWithType( tlmp : *Tilemap, start : *Tile, targetType : TileType, newType : TileType ) void
{
  var rules : FloodRule =
  .{
    .filterData = .{ .tType = targetType },
    .changeData = .{ .tType = newType },
    .filterFunc = filterType,
    .changeFunc = changeType,
  };

  tlmp.floodFillWithParams( start, &rules );
}


fn changeColour( r : *FloodRule, t : *Tile ) void { t.colour = r.changeData.colour; }

pub fn floodFillWithColour( tlmp : *Tilemap, start : *Tile, targetType : TileType, newCol : utl.Colour ) void
{
  var rules : FloodRule =
  .{
    .filterData = .{ .tType  = targetType },
    .changeData = .{ .colour = newCol     },
    .filterFunc = filterType,
    .changeFunc = changeColour,
  };

  tlmp.floodFillWithParams( start, &rules );
}
