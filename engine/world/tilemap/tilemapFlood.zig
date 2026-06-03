const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Tile         = eng.Tile;
const Tilemap      = eng.Tilemap;

const e_tile_type  = eng.e_tile_type;
const e_tile_flags = eng.e_tile_flags;

const Box2         = utl.Box2;
const Coords2      = utl.Coords2;
const Vec2         = utl.Vec2;
const VecA         = utl.VecA;


// ================================ FLOODRULE STRUCT ================================

fn filterDefault( r : *e_flood_rule, t : *Tile ) bool { _ = r; _ = t; return true; }
fn changeDefault( r : *e_flood_rule, t : *Tile ) void { _ = r; _ = t; return; }

pub const e_flood_rule = struct
{
  // TODO : implement a "max travel distance for ranged floodfills"

  filterData : Tile = .{},
  changeData : Tile = .{},

  filterFunc : *const fn( *e_flood_rule, *Tile ) bool = filterDefault,
  changeFunc : *const fn( *e_flood_rule, *Tile ) void = changeDefault,

  pub fn filter( self : *e_flood_rule, tile : *Tile ) bool { return self.filterFunc( self, tile ); }
  pub fn change( self : *e_flood_rule, tile : *Tile ) void {        self.changeFunc( self, tile ); }
};



// ================================ BASE FLOODFILL FUNCTIONS ================================

pub inline fn resetFloodFillFlags( tlmp : *Tilemap ) void { tlmp.fillWithTileFlagVal( .FLOODED, false ); }




pub fn floodFillWithParams( tlmp : *Tilemap, start : *Tile, expectedIter : u32, rules : *e_flood_rule ) void
{
  const alloc = utl.getDefaultAlloc();

  // Using a stack to avoid Depth-First Search, thus avoiding stack overflows due to recursivity
  var stack = std.ArrayList( *Tile ).initCapacity( alloc, expectedIter ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Stack initialization error : {} : returning", .{ err });
    return;
  };
  defer stack.deinit( alloc );

  if( start.isFlooded() or !rules.filter( start ))
  {
    utl.qlog( .TRACE, 0, @src(), "Invalid start location for floodFill : returning" );
    return;
  }

  start.addFlag( .FLOODED );
  stack.append( alloc, start ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Early stack error : {} : returning", .{ err });
    return;
  };

  while( stack.pop() )| cTile |
  {
    rules.change( cTile );

    for( utl.e_dir_2.arr )| dir |
    {
      if( tlmp.getNeighbourTile( cTile.mapCoords, dir ))| nTile |
      {
        if( nTile.isFlooded() or !rules.filter( nTile ) ){ continue; }

        nTile.addFlag( .FLOODED );
        stack.append( alloc, nTile ) catch | err |
        {
          utl.log( .WARN, 0, @src(), "Late stack error : {} : ignoring", .{ err });
        };
      }
    }
  }

  tlmp.resetFloodFillFlags();
}


// ================================ FLOODFILL FUNCTION WRAPPERS ================================

fn filterType( r : *e_flood_rule, t : *Tile ) bool { return t.tType == r.filterData.tType; }
fn changeType( r : *e_flood_rule, t : *Tile ) void { t.tType = r.changeData.tType; }

pub fn floodFillWithType( tlmp : *Tilemap, start : *Tile, expectedIter : u32 , targetType : e_tile_type, newType : e_tile_type ) void
{
  var rules : e_flood_rule =
  .{
    .filterData = .{ .tType = targetType },
    .changeData = .{ .tType = newType },
    .filterFunc = filterType,
    .changeFunc = changeType,
  };

  tlmp.floodFillWithParams( start, expectedIter, &rules );
}


fn changeColour( r : *e_flood_rule, t : *Tile ) void { t.colour = r.changeData.colour; }

pub fn floodFillWithColour( tlmp : *Tilemap, start : *Tile, expectedIter : u32 , targetType : e_tile_type, newCol : utl.Colour ) void
{
  var rules : e_flood_rule =
  .{
    .filterData = .{ .tType  = targetType },
    .changeData = .{ .colour = newCol     },
    .filterFunc = filterType,
    .changeFunc = changeColour,
  };

  tlmp.floodFillWithParams( start, expectedIter, &rules );
}