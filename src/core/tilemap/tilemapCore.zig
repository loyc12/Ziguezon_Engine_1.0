const std              = @import( "std" );
const def              = @import( "defs" );

const tileCore         = @import( "tileCore.zig" );
const tlmpShape        = @import( "tilemapShape.zig" );

pub const Tile         = tileCore.Tile;
pub const e_tile_type  = tileCore.e_tile_type;
pub const e_tlmp_shape = tlmpShape.e_tlmp_shape;

const Box2             = def.Box2;
const Coords2          = def.Coords2;
const Vec2             = def.Vec2;
const VecA             = def.VecA;

const DEF_GRID_SIZE    = Coords2{ .x = 32, .y = 32 };
const DEF_TILE_SCALE   = Vec2{    .x = 32, .y = 32 };


pub const e_tlmp_flags = enum( u8 )
{
  DELETE  = 0b10000000, // Grid is marked for deletion
  IS_INIT = 0b01000000, // Grid is initialized
  ACTIVE  = 0b00100000, // Grid is active and can be used
//MORE... = 0b00010000, //
//MORE... = 0b00001000, //
//MORE... = 0b00000100, //
//MORE... = 0b00000010, //
  DEBUG   = 0b00000001, // Tilemap will be rendered with debug information

  DEFAULT = 0b00111000, // Default flags for a new tilemap
  TO_CPY  = 0b00011111, // Flags to copy when creating a new tilemap from params
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};


pub const Tilemap = struct
{
  // ================ PROPERTIES ================
  id     : u32 = 0,
  flags  : def.BitField8 = def.BitField8.new( e_tlmp_flags.DEFAULT ),

  // ======== GRID DATA ========
  gridPos    : VecA    = .{},
  gridSize   : Coords2 = DEF_GRID_SIZE,

  tileArray  : std.ArrayList( Tile ) = undefined,

  // ======= TILE DATA ========
  tileScale  : Vec2         = DEF_TILE_SCALE,
  tileShape  : e_tlmp_shape = .RECT,

//baseFillType : e_tile_type = .EMPTY,

  // ======= CUSTOM BEHAVIOUR ========
//data     : ?*anyopaque = null, // Pointer to instance specific data ( if any )
//script   : ?*anyopaque = null, // Pointer to instance specific scripting ( if any )


  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Tilemap, flag : e_tlmp_flags ) bool { return self.flags.hasFlag( @intFromEnum( flag )); }

  pub inline fn setAllFlags( self : *Tilemap, flags : u8 )                       void { self.flags.bitField = flags; }
  pub inline fn setFlag(     self : *Tilemap, flag  : e_tlmp_flags, val : bool ) void { self.flags = self.flags.setFlag( @intFromEnum( flag ), val); }
  pub inline fn addFlag(     self : *Tilemap, flag  : e_tlmp_flags )             void { self.flags = self.flags.addFlag( @intFromEnum( flag )); }
  pub inline fn delFlag(     self : *Tilemap, flag  : e_tlmp_flags )             void { self.flags = self.flags.delFlag( @intFromEnum( flag )); }

  pub inline fn canBeDel( self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.DELETE  ); }
  pub inline fn isInit(   self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.IS_INIT ); }
  pub inline fn isActive( self : *const Tilemap ) bool { return self.hasFlag( e_tlmp_flags.ACTIVE  ); }


  // ================ CHECKERS ================


  pub inline fn getTileCount(  self : *const Tilemap ) u32 { return @intCast( self.gridSize.x * self.gridSize.y ); }
  pub inline fn isIndexValid(  self : *const Tilemap, index : u32 ) bool { return( index < self.getTileCount() ); }
  pub inline fn isCoordsValid( self : *const Tilemap, coords : Coords2 ) bool
  {
    if( !coords.isPosi() )
    {
      def.log( .DEBUG, 0, @src(), "Tile position {d}:{d} is negative, cannot be in grid", .{ coords.x, coords.y });
      return false;
    }
    if( coords.isSupXY( self.gridSize.subVal( 1 )))
    {
      def.log( .DEBUG, 0, @src(), "Tile position {d}:{d} is out of bounds for tilemap with scale {d}:{d}", .{ coords.x, coords.y, self.gridSize.x, self.gridSize.y });
      return false;
    }
    return true;
  }


  // ================ INITIALIZATION FUNCTIONS ================

  pub fn init( self : *Tilemap, allocator : std.mem.Allocator, fillType : e_tile_type ) void
  {
    def.log( .TRACE, 0, @src(), "Initializing Tilemap {d}", .{ self.id });

    if( self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is already initialized, cannot reinitialize", .{ self.id });
      return;
    }
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

    self.tileArray = std.ArrayList( Tile ).initCapacity( allocator, self.getTileCount() ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to initialize tilemap tile array: {}", .{ err } );
      return;
    };

    self.setFlag( e_tlmp_flags.IS_INIT, true );
    self.setFlag( e_tlmp_flags.ACTIVE,  true );

    self.fillWithType( fillType );
  }

  pub fn deinit( self : *Tilemap, allocator : std.mem.Allocator ) void
  {
    def.log( .TRACE, 0, @src(), "Deinitializing Tilemap {d}", .{ self.id });

    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot deinitialize", .{ self.id });
      return;
    }
    self.tileArray.deinit( allocator );
    self.setFlag( e_tlmp_flags.DELETE,  true );
    self.setFlag( e_tlmp_flags.IS_INIT, false );
    self.setFlag( e_tlmp_flags.ACTIVE,  false );
  }

  pub fn createTilemapFromParams( params : Tilemap, fillType : e_tile_type, allocator : std.mem.Allocator ) ?Tilemap
  {
    if( params.isInit() ){ def.qlog( .WARN, 0, @src(), "Params shoul not be an initialized tilemap"); }

    var tmp      = Tilemap{
      .flags     = params.flags.filterField( @intFromEnum( e_tlmp_flags.TO_CPY )),
      .gridPos   = params.gridPos,
      .gridSize  = params.gridSize,
      .tileScale = params.tileScale,
      .tileShape = params.tileShape,
    };

    tmp.init( allocator, fillType );
    return tmp;
  }

  pub fn createTilemapFromFile( filePath : []const u8, allocator : std.mem.Allocator ) ?Tilemap
  {
    _ = filePath;
    _ = allocator;

    // TODO : implement me

    def.qlog( .ERROR, 0, @src(), "Tilemap loading from file is not yet implemented");
    return null;
  }

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

    return @intCast(( gridCoords.y * self.gridSize.x ) + gridCoords.x );
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

  pub inline fn resetCachedTilePos( self : *Tilemap ) void
  {
    def.log( .INFO, 0, @src(), "! Resetting cached tile positions for tilemap {d}", .{ self.id });

    for( 0 .. self.getTileCount() )| index |{ self.tileArray.items.ptr[ index ].relPos = null; }
  }

  pub fn fillWithType( self : *Tilemap, tileType : e_tile_type ) void
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot fill grid with type {s}", .{ self.id, @tagName( tileType )});
      return;
    }

    for( 0 .. self.getTileCount() )| index |
    {
      const tileCoords = self.getTileCoords( @intCast( index )) orelse
      {
        def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridSize.x, self.gridSize.y });
        continue;
      };

      var tmp : e_tile_type = undefined;

      if( tileType != .RANDOM ){ tmp = tileType; }
      else switch( def.G_RNG.getClampedInt( 1, 2 ))
      {
        1 => tmp    = .FLOOR,
        2 => tmp    = .WALL,
        else => tmp = .EMPTY, // Should never happen
      }

      self.tileArray.items.ptr[ index ] = Tile{
        .tType      = tmp,
        //.colour     = tmp.getTileTypeColour(),
        .colour     = tileCoords.getParityColour(),
        .gridCoords = tileCoords,
      };
    }
  }

  pub fn setTileShape( self : *Tilemap, shape : e_tlmp_shape ) void
  {
    if( self.tileShape == shape )
    {
      def.log( .DEBUG, 0, @src(), "Tilemap {d} already has tile shape {s}, no change needed", .{ self.id, @tagName( shape )});
      return;
    }

    def.log( .INFO, 0, @src(), "Changing tilemap {d} shape from {s} to {s}", .{ self.id, @tagName( self.tileShape ), @tagName( shape )});

    self.resetCachedTilePos();
    self.tileShape = shape;
  }

  // ================ POSITION FUNCTIONS ================

  pub inline fn getGridPos( self : *const Tilemap ) Vec2 { return Vec2{ .x = self.gridPos.x, .y = self.gridPos.y }; }
  pub inline fn getGridRot( self : *const Tilemap ) f32  { return self.gridPos.a; }

  pub inline fn getAbsTilePos( self : *const Tilemap, gridCoords : Coords2 ) VecA { return tlmpShape.getAbsTilePos( self, gridCoords ); }
  pub inline fn getRelTilePos( self : *const Tilemap, gridCoords : Coords2 ) Vec2 { return tlmpShape.getRelTilePos( self, gridCoords ); }

  pub inline fn getNeighbourCoords( self : *const Tilemap, gridCoords : Coords2, direction : def.e_dir_2 ) ?Coords2 { return tlmpShape.getNeighbourCoords( self, gridCoords, direction ); }

  // =============== DRAW FUNCTIONS ================

  //pub fn isTileOnScreen( self : *const Tilemap, gridCoords : Coords2 ) bool
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

  pub inline fn getMapBoundingBox(  self : *const Tilemap ) Box2 { return tlmpShape.getMapBoundingBox( self ); }
  pub inline fn getTileBoundingBox( self : *const Tilemap, relPos : Vec2 ) Box2
  {
    return tlmpShape.getTileBoundingBox( self, relPos );
  }

  fn drawSingleTile( self : *const Tilemap, gridCoords : Coords2, viewBox : *const Box2 ) void
  {
    if( !self.isCoordsValid( gridCoords ))
    {
      def.log( .ERROR, 0, @src(), "Unable to draw tile at position {d}:{d} in tilemap {d} : coords are invalid", .{ gridCoords.x, gridCoords.y, self.id });
      return;
    }

    const tile = self.getTile( gridCoords ) orelse
    {
      def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ gridCoords.x, gridCoords.y, self.id });
      return;
    };

    if( tile.tType == .EMPTY )
    {
      def.log( .TRACE, 0, @src(), "Tile at position {d}:{d} is empty, not drawing", .{ gridCoords.x, gridCoords.y });
      return;
    }

    tlmpShape.drawTileShape( self, tile, viewBox );
  }

  pub fn drawTilemap( self : *const Tilemap ) void
  {
    def.log( .TRACE, 0, @src(), "Drawing Tilemap {d} at position {d}:{d} with scale {d}:{d}", .{ self.id, self.gridPos.x, self.gridPos.y, self.gridSize.x, self.gridSize.y });

    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot draw", .{ self.id });
      return;
    }

    const viewBox = def.G_NG.getCameraViewBox() orelse
    {
      def.log( .ERROR, 0, @src(), "Cannot draw tilemap {d} : camera is not initialized", .{ self.id });
      return;
    };

    if( !viewBox.isOverlapping( &self.getMapBoundingBox() )){ return; } // Quick check to see if tilemap is even in view

    for( 0 .. self.getTileCount() )| index |
    {
      const gridCoords = self.getTileCoords( @intCast( index )) orelse
      {
        def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridSize.x, self.gridSize.y });
        continue;
      };
      self.drawSingleTile( gridCoords, &viewBox );
    }
  }

  pub fn findHitTileCoords( self : *const Tilemap, p : Vec2 ) ?Coords2
  {
    def.log( .TRACE, 0, @src(), "Finding hit tile at p {d}:{d} for Tilemap {d}", .{ p.x, p.y, self.id });

    if( !self.isInit() )
    {
      def.log( .WARN, 0, @src(), "Tilemap {d} is not initialized, cannot find hit tile", .{ self.id });
      return null;
    }

    return tlmpShape.getCoordsFromAbsPos( self, p ) orelse
    {
      def.log( .DEBUG, 0, @src(), "Failed to get tile coordinates in tilemap {d} from p {d}:{d}", .{ p.x, p.y, self.id });
      return null;
    };
  }
};



