const std          = @import( "std" );
const def          = @import( "defs" );

const Tile         = def.Tile;
const Tilemap      = def.Tilemap;

const e_tile_type  = Tilemap.e_tile_type;
const e_tile_flags = Tilemap.e_tile_flags;

const Box2         = def.Box2;
const Coords2      = def.Coords2;
const Vec2         = def.Vec2;
const VecA         = def.VecA;

const floodFunc = *const fn ( *Tile ) bool; // NOTE : defines which functions floodFillWithParams() can take in as args

// TODO : WIP, use this file


pub inline fn resetFloodFillFlags( self : *Tilemap ) void { self.fillWithTileFlagVal( .FLOODED, false ); }


// TODO : implement a "max step distance"

pub fn floodFillWithParams( self : *Tilemap, start : *Tile, expectedIter : u32, filterFunc : floodFunc, changeFunc : floodFunc ) void
{
  const alloc = def.getAlloc();

  // Using a stack to avoid Depth-First Search, thus avoiding stack overflows due to recursivity
  var stack = std.ArrayList( *Tile ).initCapacity( alloc, expectedIter ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Stack initialization error : {} : returning", .{ err });
    return;
  };
  defer stack.deinit( alloc );

  if( start.isFlooded() or !filterFunc( start ))
  {
    def.qlog( .TRACE, 0, @src(), "Invalid start location for floodFill : returning" );
    return;
  }

  start.addFlag( .FLOODED );
  stack.append( alloc, start ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Early stack error : {} : returning", .{ err });
    return;
  };

  while( stack.pop() )| cTile |
  {
    _ = changeFunc( cTile );

    for( def.e_dir_2.arr )| dir |
    {
      if( self.getNeighbourTile( cTile.mapCoords, dir ))| nTile |
      {
        if( nTile.isFlooded() or !filterFunc( nTile ) ){ continue; }

        nTile.addFlag( .FLOODED );
        stack.append( alloc, nTile ) catch | err |
        {
          def.log( .WARN, 0, @src(), "Late stack error : {} : ignoring", .{ err });
        };
      }
    }
  }

  self.resetFloodFillFlags();
}

pub fn floodFillWithType( self : *Tilemap, start : *Tile, expectedIter : u32 , targetType : e_tile_type, newType : e_tile_type ) void
{
  // NOTE : ugly af
  const filterFunc = struct{ fn f( t: *Tile ) bool { return t.tType == targetType;   }}.f;
  const changeFunc = struct{ fn f( t: *Tile ) bool { t.tType = newType; return true; }}.f;

  self.floodFillWithParams( start, expectedIter, filterFunc, changeFunc );
}

pub fn floodFillWithColour( self : *Tilemap, start : *Tile, expectedIter : u32 , targetType : e_tile_type, newCol : def.Colour ) void
{
  // NOTE : ugly af
  const filterFunc = struct{ fn f( t: *Tile ) bool { return t.tType == targetType;   }}.f;
  const changeFunc = struct{ fn f( t: *Tile ) bool { t.colour = newCol; return true; }}.f;

  self.floodFillWithParams( start, expectedIter, filterFunc, changeFunc );
}