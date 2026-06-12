// REWORK NOTE: Reframe Tilemap as World-managed spatial simulation data rather
// than an Engine-managed object. Preserve its specialized grid representation,
// but separate simulation state from rendering/lifecycle concerns and expose it
// through World queries, systems, and entity/relation links where appropriate.

// REWORK NOTE : This is not a pressing matter. Do not implement these changes
// without explicit orders to do so by the user

const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Box2    = utl.Box2;
const Coords2 = utl.Coords2;
const Vec2    = utl.Vec2;
const VecA    = utl.VecA;

const tileCore  = @import( "tile.zig" );
const tlmpFlood = @import( "tilemapFlood.zig" );
const tlmpShape = @import( "tilemapShape.zig" );

pub const Tile         = tileCore.Tile;
pub const TileType     = tileCore.TileType;
pub const TileFlags    = tileCore.TileFlags;
pub const TilemapShape = tlmpShape.TilemapShape;
pub const FloodRule    = tlmpFlood.FloodRule;

const DEF_GRID_SIZE    = Coords2{ .x = 32, .y = 32 };
const DEF_TILE_SCALE   = Vec2{    .x = 32, .y = 32 };


/// Runtime flags for Tilemap lifecycle, activity, and debug rendering.
pub const TilemapFlags = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  DELETE  = 0b10000000, // Grid is marked for deletion
  IS_INIT = 0b01000000, // Grid is initialized
  ACTIVE  = 0b00100000, // Grid is active and can be used
//MORE... = 0b00010000, //
//MORE... = 0b00001000, //
//MORE... = 0b00000100, //
//MORE... = 0b00000010, //
  DEBUG   = 0b00000001, // Tilemap will be rendered with debug information

  DEFAULT = 0b00111110, // Default flags for a new tilemap
  TO_CPY  = 0b00011111, // Flags to copy when creating a new tilemap from params
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};


/// Grid of lightweight tiles with world position, tile scale, and shape metadata.
/// Tilemaps are still a specialized world utility; future rework may route them
/// through World-managed facts and queries.
pub const Tilemap = struct
{
  // ================ PROPERTIES ================
  id    : u32 = 0,
  flags : utl.Bfd8 = .new( TilemapFlags.DEFAULT ),

  // ======== GRID DATA ========
  mapPos  : VecA    = .{},
  mapSize : Coords2 = DEF_GRID_SIZE,

  tileArray : []Tile = &.{},
  floodMark : u32    = 0,

  // ======= TILE DATA ========
  tileScale : Vec2         = DEF_TILE_SCALE,
  tileShape : TilemapShape = .RECT,

  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Tilemap, flag : TilemapFlags ) bool { return self.flags.hasFlag( @intFromEnum( flag )); }

  pub inline fn setAllFlags( self : *Tilemap, flags : u8 )                       void { self.flags.setAllFlags( flags ); }
  pub inline fn setFlag(     self : *Tilemap, flag  : TilemapFlags, val : bool ) void { self.flags.setBitFlag( @intFromEnum( flag ), val); }
  pub inline fn addFlag(     self : *Tilemap, flag  : TilemapFlags )             void { self.flags.addFlag( @intFromEnum( flag )); }
  pub inline fn delFlag(     self : *Tilemap, flag  : TilemapFlags )             void { self.flags.delFlag( @intFromEnum( flag )); }

  pub inline fn canBeDel( self : *const Tilemap ) bool { return self.hasFlag( TilemapFlags.DELETE  ); }
  pub inline fn isInit(   self : *const Tilemap ) bool { return self.hasFlag( TilemapFlags.IS_INIT ); }
  pub inline fn isActive( self : *const Tilemap ) bool { return self.hasFlag( TilemapFlags.ACTIVE  ); }

  pub inline fn viewDBG(  self : *const Tilemap ) bool { return self.hasFlag( TilemapFlags.DEBUG   ); }


  // ================ CHECKERS ================


  /// Returns the total number of tile cells in the grid.
  pub inline fn getTileCount(  self : *const Tilemap ) u32 { return @intCast( self.mapSize.x * self.mapSize.y ); }
  pub inline fn isIndexValid(  self : *const Tilemap, index : u32 ) bool { return( index < self.getTileCount() ); }
  /// Returns true when grid coordinates are non-negative and inside `mapSize`.
  pub inline fn isCoordsValid( self : *const Tilemap, coords : Coords2 ) bool
  {
    if( !coords.isPosi() )
    {
      utl.log( .TRACE, @src(), "Tile position {d}:{d} is negative, cannot be in grid", .{ coords.x, coords.y });
      return false;
    }
    if( coords.x >= self.mapSize.x or coords.y >= self.mapSize.y )
    {
      utl.log( .TRACE, @src(), "Tile position {d}:{d} is out of bounds for tilemap with scale {d}:{d}", .{ coords.x, coords.y, self.mapSize.x, self.mapSize.y });
      return false;
    }
    return true;
  }

  /// Returns true when two map coordinates touch through one cardinal direction.
  pub fn areCoordsNeighbours( self : *const Tilemap, c1 : Coords2, c2 : Coords2 ) bool
  {
    for( utl.Dir2.arr )| dir |
    {
      const nCoords = self.getNeighbourCoords( c1, dir ) orelse
      {
        utl.log( .TRACE, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), c1.x, c1.y });
        continue;
      };

      if( nCoords.isEq( c2 )){ return true; }
    }

    utl.log( .TRACE, @src(), "{d}:{d} and {d}:{d} are not neighbours", .{ c1.x, c1.y, c2.x, c2.y });
    return false;
  }


  // ================ INITIALIZATION FUNCTIONS ================

  /// Allocates the tile array and fills every cell with `fillType`.
  pub fn init( self : *Tilemap, allocator : std.mem.Allocator, fillType : TileType ) void
  {
    utl.log( .TRACE, @src(), "Initializing Tilemap {d}", .{ self.id });

    if( self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is already initialized, cannot reinitialize", .{ self.id });
      return;
    }
    if( self.mapSize.x <= 0 or self.mapSize.y <= 0 )
    {
      utl.log( .ERROR, @src(), "Tilemap grid scale must be greater than 0, got {d}:{d}", .{ self.mapSize.x, self.mapSize.y });
      return;
    }
    if( self.tileScale.x <= utl.EPS or self.tileScale.y <= utl.EPS )
    {
      utl.log( .ERROR, @src(), "Tilemap tile scale must be greater than 0, got {d}:{d}", .{ self.tileScale.x, self.tileScale.y });
      return;
    }

    self.tileArray = allocator.alloc( Tile, self.getTileCount() ) catch | err |
    {
      utl.log( .ERROR, @src(), "Failed to initialize tilemap tile array: {}", .{ err } );
      return;
    };

    self.setFlag( TilemapFlags.IS_INIT, true );
    self.setFlag( TilemapFlags.ACTIVE,  true );

    self.fillWithType( fillType );
  }

  /// Releases the tile array and marks the tilemap inactive/deleted.
  pub fn deinit( self : *Tilemap, allocator : std.mem.Allocator ) void
  {
    utl.log( .TRACE, @src(), "Deinitializing Tilemap {d}", .{ self.id });

    if( !self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is not initialized, cannot deinitialize", .{ self.id });
      return;
    }
    allocator.free( self.tileArray );
    self.tileArray = &.{};
    self.floodMark = 0;
    self.setFlag( TilemapFlags.DELETE,  true );
    self.setFlag( TilemapFlags.IS_INIT, false );
    self.setFlag( TilemapFlags.ACTIVE,  false );
  }

  /// Creates a fresh tilemap by copying safe setup fields from `params`.
  pub fn createTilemapFromParams( params : Tilemap, fillType : TileType, allocator : std.mem.Allocator ) ?Tilemap
  {
    if( params.isInit() ){ utl.qlog( .WARN, @src(), "Params shoul not be an initialized tilemap"); }

    var flags = params.flags;
    flags.filterField( TilemapFlags.TO_CPY );

    var tmp      = Tilemap{
      .flags     = flags,
      .mapPos    = params.mapPos,
      .mapSize   = params.mapSize,
      .tileScale = params.tileScale,
      .tileShape = params.tileShape,
    };

    tmp.init( allocator, fillType );
    return tmp;
  }

  /// Placeholder for future tilemap loading.
  pub fn createTilemapFromFile( filePath : []const u8, allocator : std.mem.Allocator ) ?Tilemap
  {
    _ = filePath;
    _ = allocator;

    // TODO : implement me

    utl.qlog( .ERROR, @src(), "Tilemap loading from file is not yet implemented");
    return null;
  }


  // ================ TILE FUNCTIONS ================

  /// Converts a flat tile-array index into grid coordinates.
  pub inline fn getTileCoordsFromIndex( self : *const Tilemap, index : u32 ) ?Coords2
  {
    if( !self.isIndexValid( index ))
    {
      utl.log( .ERROR, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.mapSize.x, self.mapSize.y });
      return null;
    }

    const tmp = @as( i32, @intCast( index ));

    return Coords2{
      .x = @mod(      tmp, self.mapSize.x ),
      .y = @divTrunc( tmp, self.mapSize.x ),
    };
  }


  /// Converts grid coordinates into a flat tile-array index.
  pub inline fn getTileIndex( self : *const Tilemap, mapCoords : Coords2 ) ?u32
  {
    if( !self.isCoordsValid( mapCoords )){ return null; }

    return @intCast(( mapCoords.y * self.mapSize.x ) + mapCoords.x );
  }

  /// Returns a tile pointer for valid grid coordinates.
  pub inline fn getTile( self : *const Tilemap, mapCoords : Coords2 ) ?*Tile
  {
    if( !self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is not initialized, cannot get tile at {d}:{d}", .{ self.id, mapCoords.x, mapCoords.y });
      return null;
    }
    if( !self.isCoordsValid( mapCoords )){ return null; }

    const index = self.getTileIndex( mapCoords ) orelse return null;
    return &self.tileArray[ index ];
  }

  pub inline fn getNeighbourTile( self : *const Tilemap, mapCoords : Coords2, dir : utl.Dir2 ) ?*Tile
  {
    const nCoords : Coords2 = self.getNeighbourCoords( mapCoords, dir ) orelse
    {
      utl.log( .TRACE, @src(), "No neighbour in direction {s} found for tile at {d}:{d}", .{ @tagName( dir ), mapCoords.x, mapCoords.y});
      return null;
    };

    return self.getTile( nCoords );
  }

  pub inline fn getNextTile( self : *const Tilemap, mapCoords : Coords2 ) ?*Tile
  {
    var index : u32 = self.getTileIndex( mapCoords ) orelse
    {
      utl.log( .TRACE, @src(), "No index found for tile at {d}:{d}", .{ mapCoords.x, mapCoords.y});
      return null;
    };

    index += 1;

    index = @mod( index, self.getTileCount() );
    return &self.tileArray[ index ];
  }

  pub inline fn getPreviousTile( self : *const Tilemap, mapCoords : Coords2 ) ?*Tile
  {
    var index : u32 = self.getTileIndex( mapCoords ) orelse
    {
      utl.log( .TRACE, @src(), "No index found for tile at {d}:{d}", .{ mapCoords.x, mapCoords.y});
      return null;
    };

    index -= 1;
    index = @mod( index, self.getTileCount() );

    return &self.tileArray[ index ];
  }


  // ================ GRID FUNCTIONS ================

  pub fn setTileShape( self : *Tilemap, shape : TilemapShape ) void
  {
    if( self.tileShape == shape )
    {
      utl.log( .DEBUG, @src(), "Tilemap {d} already has tile shape {s}, no change needed", .{ self.id, @tagName( shape )});
      return;
    }

    utl.log( .INFO, @src(), "Changing tilemap {d} shape from {s} to {s}", .{ self.id, @tagName( self.tileShape ), @tagName( shape )});

    self.resetCachedTilePos();
    self.tileShape = shape;
  }

  pub inline fn resetCachedTilePos( self : *Tilemap ) void
  {
    utl.log( .INFO, @src(), "@ Resetting cached tile positions for tilemap {d}", .{ self.id });

    for( 0 .. self.getTileCount() )| index |{ self.tileArray[ index ].relPos = null; }
  }

  // ================ FILL FUNCTIONS ================

  pub fn fillWithTileFlagVal( self : *Tilemap, flag : TileFlags, val : bool ) void
  {
    utl.log( .DEBUG, @src(), "@ Mass changing tile flags for tilemap {d}", .{ self.id });

    if( !self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is not initialized, cannot fill grid with given flag value", .{ self.id });
      return;
    }

    for( 0 .. self.getTileCount() )| index |
    {
      self.tileArray[ index ].setFlag( flag, val );
    }
  }

  pub fn fillWithType( self : *Tilemap, tileType : TileType ) void
  {
    if( !self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is not initialized, cannot fill grid with type {s}", .{ self.id, @tagName( tileType )});
      return;
    }

    for( 0 .. self.getTileCount() )| index |
    {
      const tileCoords = self.getTileCoordsFromIndex( @intCast( index )) orelse
      {
        utl.log( .ERROR, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.mapSize.x, self.mapSize.y });
        continue;
      };

      var tmpType : TileType = undefined;

      if( tileType != .RANDOM ){ tmpType = tileType; }
      else switch( eng.G_ENG.rng.getClampedInt( 1, 8 ))
      {
        1    => tmpType = .T1,
        2    => tmpType = .T2,
        3    => tmpType = .T3,
        4    => tmpType = .T4,
        5    => tmpType = .T5,
        6    => tmpType = .T6,
        7    => tmpType = .T7,
        8    => tmpType = .T8,
        else => unreachable, // Should never happen
      }

      const col = switch( tmpType )
      {
        .PARITY => tileCoords.getParityColour(),
        else    => tmpType.getTileTypeColour(),
      };

      self.tileArray[ index ] = Tile
      {
        .tType     = tmpType,
        .colour    = col,
        .mapCoords = tileCoords,
      };
    }
  }

  pub fn fillWithColour( self : *Tilemap, col : utl.Colour ) void
  {
    if( !self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is not initialized, cannot fill grid with given colour", .{ self.id });
      return;
    }

    for( 0 .. self.getTileCount() )| index |
    {
      self.tileArray[ index ].colour = col;
    }
  }


  // ======== FLOOD FILL FUNCTIONS ========

  pub fn beginFloodFill( self : *Tilemap ) u32
  {
    self.floodMark +%= 1;
    if( self.floodMark != 0 ){ return self.floodMark; }

    for( self.tileArray )| *tile |{ tile.floodMark = 0; }
    self.floodMark = 1;
    return self.floodMark;
  }

  pub inline fn isFloodMarked( self : *const Tilemap, tile : *const Tile ) bool { return tile.floodMark == self.floodMark; }
  pub inline fn addFloodMark(  self : *const Tilemap, tile : *Tile       ) void { tile.floodMark =  self.floodMark; }
  pub inline fn resetFloodMarks( self : *Tilemap ) void { tlmpFlood.resetFloodMarks( self ); }

  pub inline fn floodFillWithParams( self : *Tilemap, start : *Tile, rules : *FloodRule ) void
  {
    tlmpFlood.floodFillWithParams( self, start, rules );
  }

  pub inline fn floodFillWithType( self : *Tilemap, start : *Tile, targetType : TileType, newType : TileType ) void
  {
    tlmpFlood.floodFillWithType( self, start, targetType, newType );
  }
  pub inline fn floodFillWithColour( self : *Tilemap, start : *Tile, targetType : TileType, newCol : utl.Colour ) void
  {
    tlmpFlood.floodFillWithColour( self, start, targetType, newCol );
  }


  // ================ POSITION FUNCTIONS ================

  pub inline fn getGridPos( self : *const Tilemap ) Vec2 { return Vec2{ .x = self.mapPos.x, .y = self.mapPos.y }; }
  pub inline fn getGridRot( self : *const Tilemap ) f32  { return self.mapPos.a; }

  pub inline fn getAbsTilePos( self : *const Tilemap, mapCoords : Coords2 ) VecA { return tlmpShape.getAbsTilePos( self, mapCoords ); }
  pub inline fn getRelTilePos( self : *const Tilemap, mapCoords : Coords2 ) Vec2 { return tlmpShape.getRelTilePos( self, mapCoords ); }

  pub inline fn getNeighbourCoords( self : *const Tilemap, mapCoords : Coords2, direction : utl.Dir2 ) ?Coords2 { return tlmpShape.getNeighbourCoords( self, mapCoords, direction ); }

  // =============== DRAW FUNCTIONS ================

  // NOTE : why is this commented out ? was it too costly to run per tile ?
  //pub fn isTileOnScreen( self : *const Tilemap, mapCoords : Coords2 ) bool
  //{
  //  if( !self.isCoordsValid( mapCoords ))
  //  {
  //    utl.log( .ERROR, @src(), "Cannot check if tile at {d}:{d} is on screen in tilemap {d} : coords are invalid", .{ mapCoords.x, mapCoords.y, self.id });
  //    return false;
  //  }
  //
  //  const tilePos = self.getTileWorldPos( mapCoords ) orelse
  //  {
  //    utl.log( .ERROR, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ mapCoords.x, mapCoords.y, self.id });
  //    return false;
  //  };
  //
  //  const tileMaxSize = @max( self.tileScale.x, self.tileScale.y ) * 1.415;
  //
  //  const shw : f32 = utl.getScreenWidth()  / 2 + tileMaxSize;
  //  const shh : f32 = utl.getScreenHeight() / 2 + tileMaxSize;
  //
  //  return isOnRange( Vec2{ .x = -shw, .y = -shh }, Vec2{ .x = shw,  .y = shh });
  //}

  pub inline fn getMapBoundingBox(  self : *const Tilemap ) Box2 { return tlmpShape.getMapBoundingBox( self ); }
  pub inline fn getTileBoundingBox( self : *const Tilemap, relPos : Vec2 ) Box2
  {
    return tlmpShape.getTileBoundingBox( self, relPos );
  }

  fn drawSingleTile( self : *const Tilemap, mapCoords : Coords2, viewBox : *const Box2 ) void
  {
    if( !self.isCoordsValid( mapCoords ))
    {
      utl.log( .ERROR, @src(), "Unable to draw tile at position {d}:{d} in tilemap {d} : coords are invalid", .{ mapCoords.x, mapCoords.y, self.id });
      return;
    }

    const tile = self.getTile( mapCoords ) orelse
    {
      utl.log( .ERROR, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ mapCoords.x, mapCoords.y, self.id });
      return;
    };

    tlmpShape.drawTileShape( self, tile, viewBox );
  }

  pub fn drawTilemap( self : *const Tilemap ) void
  {
    utl.log( .TRACE, @src(), "Drawing Tilemap {d} at position {d}:{d} with scale {d}:{d}", .{ self.id, self.mapPos.x, self.mapPos.y, self.mapSize.x, self.mapSize.y });

    if( !self.isInit() )
    {
      utl.log( .ERROR, @src(), "Tilemap {d} is not initialized, cannot draw", .{ self.id });
      return;
    }

    const viewBox = eng.G_ENG.camera.toViewBox();

    if( !viewBox.doesOverlap( self.getMapBoundingBox() )){ return; } // Quick check to see if tilemap is even in view

    for( 0 .. self.getTileCount() )| index |
    {
      const mapCoords = self.getTileCoordsFromIndex( @intCast( index )) orelse
      {
        utl.log( .ERROR, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.mapSize.x, self.mapSize.y });
        continue;
      };
      self.drawSingleTile( mapCoords, &viewBox );
    }
  }

  pub fn findHitTileCoords( self : *const Tilemap, worldPos : Vec2 ) ?Coords2
  {
    utl.log( .TRACE, @src(), "Finding hit tile at p {d}:{d} for Tilemap {d}", .{ worldPos.x, worldPos.y, self.id });

    if( !self.isInit() )
    {
      utl.log( .WARN, @src(), "Tilemap {d} is not initialized, cannot find hit tile : returning null", .{ self.id });
      return null;
    }

    return tlmpShape.getCoordsFromAbsPos( self, worldPos ) orelse
    {
      utl.log( .TRACE, @src(), "Failed to get tile coordinates in tilemap {d} at {d}:{d} : return null", .{ self.id, worldPos.x, worldPos.y });
      return null;
    };
  }
};


test "Tilemap starts with empty tile storage"
{
  const tlmp : Tilemap = .{};

  try std.testing.expect( !tlmp.isInit() );
  try std.testing.expectEqual( @as( usize, 0 ), tlmp.tileArray.len );
}

test "Tilemap init allocates fixed tile storage"
{
  var tlmp : Tilemap = .{ .mapSize = .{ .x = 3, .y = 2 }};

  tlmp.init( std.testing.allocator, .T1 );
  defer tlmp.deinit( std.testing.allocator );

  try std.testing.expect( tlmp.isInit() );
  try std.testing.expectEqual( @as( usize, 6 ), tlmp.tileArray.len );
  try std.testing.expectEqual( TileType.T1, tlmp.tileArray[ 0 ].tType );
  try std.testing.expectEqual( Coords2{ .x = 2, .y = 1 }, tlmp.tileArray[ 5 ].mapCoords );
}

test "Tilemap flood fill uses generation marks"
{
  var tlmp : Tilemap = .{ .mapSize = .{ .x = 3, .y = 3 }};

  tlmp.init( std.testing.allocator, .T1 );
  defer tlmp.deinit( std.testing.allocator );

  tlmp.tileArray[ 4 ].tType = .T2;

  const startA = tlmp.getTile( .{ .x = 0, .y = 0 } ).?;
  tlmp.floodFillWithType( startA, .T1, .T3 );

  try std.testing.expectEqual( @as( u32, 1 ), tlmp.floodMark );
  try std.testing.expectEqual( TileType.T2, tlmp.tileArray[ 4 ].tType );
  try std.testing.expectEqual( TileType.T3, tlmp.tileArray[ 0 ].tType );
  try std.testing.expectEqual( @as( u32, 1 ), tlmp.tileArray[ 0 ].floodMark );

  const startB = tlmp.getTile( .{ .x = 0, .y = 0 } ).?;
  tlmp.floodFillWithType( startB, .T3, .T4 );

  try std.testing.expectEqual( @as( u32, 2 ), tlmp.floodMark );
  try std.testing.expectEqual( TileType.T4, tlmp.tileArray[ 0 ].tType );
  try std.testing.expectEqual( @as( u32, 2 ), tlmp.tileArray[ 0 ].floodMark );
}
