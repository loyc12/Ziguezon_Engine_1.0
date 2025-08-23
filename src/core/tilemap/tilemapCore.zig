const std  = @import( "std" );
const def  = @import( "defs" );

const tlmpShape = @import( "tilemapShape.zig" );
const e_tlmp_shape = tlmpShape.e_tlmp_shape;

const Vec2    = def.Vec2;
const VecR    = def.VecR;
const Angle   = def.Angle;
const Coords2 = def.Coords2;

const DEF_GRID_SIZE  = Coords2{ .x = 32, .y = 32 };
const DEF_TILE_SCALE = Vec2{    .x = 64, .y = 64 };

pub const e_tlmp_flags = enum( u8 )
{
  DELETE     = 0b10000000, // Grid is marked for deletion
  IS_INIT    = 0b01000000, // Grid is initialized
  ACTIVE     = 0b00100000, // Grid is active and can be used
//DRAW_DIR_X = 0b00010000, // 0 = left to right, 1 = right to left
//DRAW_DIR_Y = 0b00001000, // 0 = top to bottom, 1 = bottom to top
//DUMMY_1    = 0b00000100, // Dummy flag for future use
//DUMMY_2    = 0b00000010, // Dummy flag for future use
  DEBUG      = 0b00000001, // Tilemap will be rendered with debug information

  TO_CPY     = 0b00011111, // Flags to copy when creating a new tilemap from params
  NONE       = 0b00000000, // No flags set
  ALL        = 0b11111111, // All flags set
};

pub const e_tile_type = enum( u8 ) // TODO : abstract this enum to allow for custom tile types ?
{
  EMPTY   = 0,
  FLOOR   = 1,
  WALL    = 2,
//TRIGGER,
//DOOR,
//WATER,
//LAVA,
//SPAWN,
//EXIT,
};

pub fn getTileTypeColour( tileType : e_tile_type ) def.Colour
{
  return switch( tileType )
  {
    .EMPTY   => def.newColour( 0,   0,   0,   0 ),
    .FLOOR   => def.newColour( 200, 200, 200, 255 ),
    .WALL    => def.newColour( 150, 150, 150, 255 ),
  //.TRIGGER => def.newColour( 100, 255, 100, 255 ),
  //.DOOR    => def.newColour( 255, 200, 100, 255 ),
  //.WATER   => def.newColour( 50,  150, 255, 255 ),
  //.LAVA    => def.newColour( 255, 100, 50,  255 ),
  //.SPAWN   => def.newColour( 0,   255, 0,   255 ),
  //.EXIT    => def.newColour( 0,   0,   255, 255 ),
  };
}

pub const Tile = struct
{
  tType      : e_tile_type = .EMPTY,
  colour     : def.Colour  = def.newColour( 255, 255, 255, 255 ),
  gridCoords : Coords2     = .{},
};

pub const Tilemap = struct
{
  id    : u32 = 0,
  flags : u8  = 0, // Flags for the tilemap ( e.g. is it a grid tilemap ? )

  gridPos    : VecR,
  gridSize   : Coords2 = DEF_GRID_SIZE,

  tileScale  : Vec2 = DEF_TILE_SCALE,
  tileShape  : e_tlmp_shape = .RECT,
  tileArray  : std.ArrayList( Tile ) = undefined,


  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Tilemap, flag : e_tlmp_flags ) bool { return ( self.flags & @intFromEnum( flag )) != 0; }

  pub inline fn setAllFlags( self : *Tilemap, flags : u8           ) void { self.flags  =  flags; }
  pub inline fn addFlag(     self : *Tilemap, flag  : e_tlmp_flags ) void { self.flags |=  @intFromEnum( flag ); }
  pub inline fn delFlag(     self : *Tilemap, flag  : e_tlmp_flags ) void { self.flags &= ~@intFromEnum( flag ); }
  pub inline fn setFlag(     self : *Tilemap, flag  : e_tlmp_flags, value : bool ) void
  {
    if( value ){ self.addFlag( flag ); } else { self.delFlag( flag ); }
  }

  pub inline fn canBeDel( self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.DELETE     ); }
  pub inline fn isInit(   self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.IS_INIT    ); }
  pub inline fn isActive( self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.ACTIVE     ); }
//pub inline fn drawDirX( self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.DRAW_DIR_X ); }
//pub inline fn drawDirY( self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.DRAW_DIR_Y ); }

  // ================ CHECKERS ================

  pub inline fn isCoordsValid( self : *const Tilemap, coords : Coords2 ) bool
  {
    if( !coords.isPos() )
    {
      def.log( .ERROR, 0, @src(), "Tile position {d}:{d} is negative, cannot be in grid", .{ coords.x, coords.y });
      return false;
    }
    if( coords.isSupXY( self.gridSize ))
    {
      def.log( .ERROR, 0, @src(), "Tile position {d}:{d} is out of bounds for tilemap with scale {d}:{d}", .{ coords.x, coords.y, self.gridSize.x, self.gridSize.y });
      return false;
    }
    return true;
  }

  pub inline fn isIndexValid( self : *const Tilemap, index : u32 ) bool
  {
    return( index < self.gridSize.x * self.gridSize.y );
  }


  // ================ INITIALIZATION FUNCTIONS ================

  pub fn init( self : *Tilemap, allocator : std.mem.Allocator, fillType : ?e_tile_type ) void
  {
    if( self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is already initialized, cannot reinitialize", .{ self.id });
      return;
    }
    def.log( .DEBUG, 0, @src(), "Initializing Tilemap {d}", .{ self.id });

    if( self.gridSize.x == 0 or self.gridSize.y == 0 )
    {
      def.log( .ERROR, 0, @src(), "Tilemap grid scale must be greater than 0, got {d}:{d}", .{ self.gridSize.x, self.gridSize.y });
      return;
    }
    if( self.tileScale.x <= 0 or self.tileScale.y <= 0 )
    {
      def.log( .ERROR, 0, @src(), "Tilemap tile scale must be greater than 0, got {d}:{d}", .{ self.tileScale.x, self.tileScale.y });
      return;
    }

    const capacity : usize = @intCast( self.gridSize.x * self.gridSize.y );

    self.tileArray = std.ArrayList( Tile ).initCapacity( allocator, capacity ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to initialize tilemap tile array: {}", .{ err } );
      return;
    };

    self.setFlag( e_tlmp_flags.IS_INIT, true );
    self.setFlag( e_tlmp_flags.ACTIVE,  true );

    if( fillType != null ){ self.fillWithType( fillType.? ); }
    else                  { self.fillWithType( .EMPTY     ); }
  }

  pub fn deinit( self : *Tilemap ) void
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot deinitialize", .{ self.id });
      return;
    }
    def.log( .DEBUG, 0, @src(), "Deinitializing Tilemap {d}", .{ self.id });

    self.tileArray.deinit();
    self.setFlag( e_tlmp_flags.DELETE,  true );
    self.setFlag( e_tlmp_flags.IS_INIT, false );
    self.setFlag( e_tlmp_flags.ACTIVE,  false );
  }

  pub fn createTilemapFromParams( params : Tilemap, fillType : e_tile_type, allocator : std.mem.Allocator ) ?Tilemap
  {
    if( params.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Params cannot be an initialized tilemap", .{});
      return null;
    }

    var tmp = Tilemap{
      .flags       = params.flags | e_tlmp_flags.TO_CPY,
      .gridPos     = params.gridPos,
      .gridSize    = params.gridSize,
      .tileScale   = params.tileScale,
      .tileShape   = params.tileShape,
    };

    tmp.init( allocator, fillType ) orelse
    {
      def.log( .ERROR, 0, @src(), "Failed to initialize new tilemap", .{});
      return null;
    };

    return tmp;
  }

  //pub fn createTilemapFromFile( filePath : []const u8, allocator : std.mem.Allocator ) ?Tilemap
  //{
  //  _ = filePath;
  //  _ = allocator;
  //
  //  // TODO : implement me
  //  def.log( .ERROR, 0, @src(), "Tilemap loading from file is not yet implemented", .{});
  //  return null;
  //}

  // ================ TILE FUNCTIONS ================

  pub inline fn getTileCoords( self : *const Tilemap, index : u32 ) ?Coords2
  {
    if( !self.isIndexValid( index ))
    {
      def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridSize.x, self.gridSize.y });
      return null;
    }

    const tmp = @as( i32, @intCast( index ));

    return Coords2{
      .x = @mod(      tmp, self.gridSize.x ),
      .y = @divTrunc( tmp, self.gridSize.x ),
    };
  }

  pub inline fn getTileIndex( self : *const Tilemap, gridCoords : Coords2 ) ?u32
  {
    if( !self.isCoordsValid( gridCoords )){ return null; }

    return @intCast( gridCoords.x + ( gridCoords.y * self.gridSize.y ));
  }

  pub inline fn getTile( self : *const Tilemap, gridCoords : Coords2 ) ?*Tile
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot get tile at {d}:{d}", .{ self.id, gridCoords.x, gridCoords.y });
      return null;
    }
    if( !self.isCoordsValid( gridCoords )){ return null; }

    const index = self.getTileIndex( gridCoords ) orelse return null;
    return &self.tileArray.items.ptr[ index ];
  }


  // ================ GRID FUNCTIONS ================

  pub fn fillWithType( self : *Tilemap, tileType : e_tile_type ) void
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot fill grid with type {s}", .{ self.id, @tagName( tileType )});
      return;
    }

    for( 0 .. @intCast( self.gridSize.x * self.gridSize.y ))| index |
    {
      const tileCoords = self.getTileCoords( @intCast( index )) orelse
      {
        def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridSize.x, self.gridSize.y });
        continue;
      };

      self.tileArray.items.ptr[ index ] = Tile{
        .tType  = tileType,
        .colour = def.G_RNG.getColour(), // NOTE : DEBUG COLOUR : CHANGE BACK TO getTileTypeColour( tileType ),
        .gridCoords = tileCoords,
      };
    }
    else { def.log( .ERROR, 0, @src(), "Tilemap {d} tile array is null, cannot fill with type {s}", .{ self.id, @tagName( tileType )}); }
  }

  // ================ POSITION FUNCTIONS ================

  pub inline fn getGridPos( self : *const Tilemap ) Vec2 { return Vec2{ .x = self.gridPos.x, .y = self.gridPos.y }; }
  pub inline fn getGridRot( self : *const Tilemap ) f32  { return self.gridPos.r; }

  pub inline fn getAbsTilePos( self : *const Tilemap, gridCoords : Coords2 ) ?VecR { return tlmpShape.getAbsTilePos( self, gridCoords ); }
  pub inline fn getRelTilePos( self : *const Tilemap, gridCoords : Coords2 ) ?VecR { return tlmpShape.getRelTilePos( self, gridCoords ); }

  // =============== DRAW FUNCTIONS ================

  //pub fn isTileOnScreen( self : *const Tilemap, gridCoords : Coords2 ) bool // TODO : IMPLEMENT ME ( reuse entity pos logic, after moving it to more generic util file )
  //{
  //  if( !self.isCoordsValid( gridCoords ))
  //  {
  //    def.log( .ERROR, 0, @src(), "Cannot check if tile at {d}:{d} is on screen in tilemap {d} : coords are invalid", .{ gridCoords.x, gridCoords.y, self.id });
  //    return false;
  //  }
//
  //  const tilePos = self.getTileWorldPos( gridCoords ) orelse
  //  {
  //    def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ gridCoords.x, gridCoords.y, self.id });
  //    return false;
  //  };
//
  //  const tileMaxSize = @max( self.tileScale.x, self.tileScale.y ) * 1.415;
//
  //  const shw : f32 = def.getScreenWidth()  / 2 + tileMaxSize;
  //  const shh : f32 = def.getScreenHeight() / 2 + tileMaxSize;
//
  //  return isOnRange( Vec2{ .x = -shw, .y = -shh }, Vec2{ .x = shw,  .y = shh });
  //}

  fn drawSingleTile( self : *const Tilemap, gridCoords : Coords2 ) void
  {
    if( !self.isCoordsValid( gridCoords ))
    {
      def.log( .ERROR, 0, @src(), "Unable to draw tile at position {d}:{d} in tilemap {d} : coords are invalid", .{ gridCoords.x, gridCoords.y, self.id });
      return;
    }

    const tile = self.getTile( gridCoords ) orelse
    {
      def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ gridCoords.x, gridCoords.y, -1 });
      return;
    };

    if( tile.tType == .EMPTY )
    {
      def.log( .TRACE, 0, @src(), "Tile at position {d}:{d} is empty, not drawing", .{ gridCoords.x, gridCoords.y });
      return;
    }

    tlmpShape.drawTileShape( self, tile );

    //def.drawCircle( pos.toVec2(), self.tileScale.x / 2, tile.colour ); // TODO : replace by proper polygon
  }

  pub fn drawTilemap( self : *const Tilemap ) void
  {
    def.log( .TRACE, 0, @src(), "Drawing Tilemap {d} at position {d}:{d} with scale {d}:{d}", .{ self.id, self.gridPos.x, self.gridPos.y, self.gridSize.x, self.gridSize.y });

    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot draw", .{ self.id });
      return;
    }

    for( 0 .. @intCast( self.gridSize.x * self.gridSize.y ))| index |
    {
      const gridCoords = self.getTileCoords( @intCast( index )) orelse
      {
        def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridSize.x, self.gridSize.y });
        continue;
      };
      self.drawSingleTile( gridCoords );
    }
  }

  // TODO : TEST THIS SHIT
  pub fn findHitTileCoords( self : *const Tilemap, point : Vec2 ) ?Coords2
  {
    def.log( .TRACE, 0, @src(), "Finding hit tile at point {d}:{d} for Tilemap {d}", .{ point.x, point.y, self.id });

    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot find hit tile", .{ self.id });
      return null;
    }

    return tlmpShape.getCoordsFromAbsPos( self, point ) orelse
    {
      def.log( .ERROR, 0, @src(), "Failed to get tile coordinates in tilemap {d} from point {d}:{d}", .{ point.x, point.y, self.id });
      return null;
    };
  }
};



