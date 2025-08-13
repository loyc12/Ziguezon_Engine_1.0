const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const VecR = def.VecR;
const Dim2 = [ 2 ]u16; // like vec2, but with u16 instead of f32

const DEF_GRID_SCALE = Dim2{ .x = 64, .y = 64 };
const DEF_TILE_SCALE = Vec2{ .x = 64, .y = 64 };

pub const e_tlmp_shape = enum( u8 )
{
  RECT, // []
//DIAM, // <>
//HEXA, // <_>
//TRIA, // /\
};

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

  DEFAULT    = 0b00100000, // Default flags for the tilemap ( active )
  TO_CPY     = 0b00011111, // Flags to copy when creating a new tilemap from params
  NONE       = 0b00000000, // No flags set
  ALL        = 0b11111111, // All flags set
};

pub const e_tile_type = enum( u8 )
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
    .TRIGGER => def.newColour( 100, 255, 100, 255 ),
    .DOOR    => def.newColour( 255, 200, 100, 255 ),
    .WATER   => def.newColour( 50,  150, 255, 255 ),
    .LAVA    => def.newColour( 255, 100, 50,  255 ),
    .SPAWN   => def.newColour( 0,   255, 0,   255 ),
    .EXIT    => def.newColour( 0,   0,   255, 255 ),
  };
}

pub const Tile = struct
{
  tType  : e_tile_type = .EMPTY,
  colour : def.Colour = def.newColour( 255, 255, 255, 255 ),
  mapPos : Dim2 = .{ 0, 0 },
};

pub const Tilemap = struct
{
  id    : u32 = 0,
  flags : u8  = 0, // Flags for the tilemap ( e.g. is it a grid tilemap ? )

  gridPos   : VecR,
  gridScale : Dim2 = DEF_GRID_SCALE,

  tileScale : Vec2 = DEF_TILE_SCALE,
  tileShape : e_tlmp_shape = .RECT,

  tileArray : ?std.ArrayList( Tile ) = null,


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


  // ================ INITIALIZATION FUNCTIONS ================

  pub fn init( self : *Tilemap, allocator : std.mem.Allocatorm, fillType : ?e_tile_type ) void
  {
    if( self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is already initialized, cannot reinitialize", .{ self.id });
      return;
    }
    def.log( .DEBUG, 0, @src(), "Initializing Tilemap {d}", .{ self.id });

    if( self.gridScale.x == 0 or self.gridScale.y == 0 )
    {
      def.log( .ERROR, 0, @src(), "Tilemap grid scale must be greater than 0, got {d}:{d}", .{ self.gridScale.x, self.gridScale.y });
      return;
    }
    if( self.tileScale.x <= 0 or self.tileScale.y <= 0 )
    {
      def.log( .ERROR, 0, @src(), "Tilemap tile scale must be greater than 0, got {d}:{d}", .{ self.tileScale.x, self.tileScale.y });
      return;
    }

    const capacity = @as( usize, self.gridScale.x * self.gridScale.y );

    self.tileArray = std.ArrayList( Tile ).initCapacity( allocator, capacity ) orelse
    {
      def.log( .ERROR, 0, @src(), "Failed to allocate memory for tilemap tile array with capacity {d}", .{ capacity });
      return;
    };

    self.setFlag( e_tlmp_flags.IS_INIT, true );
    self.setFlag( e_tlmp_flags.ACTIVE,  true );

    if( fillType != null ){ self.fillWithType( fillType ); }
    else                  { self.fillWithType( .EMPTY   ); }
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
    if( params.tileArray != null )
    {
      def.log( .ERROR, 0, @src(), "Params cannot have a pre-existing tile array", .{});
      return null;
    }

    var tmp = Tilemap{
      .flags       = params.flags | e_tlmp_flags.TO_CPY,
      .gridPos     = params.gridPos,
      .gridScale   = params.gridScale,
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

  pub inline fn getTileCoords( self : *const Tilemap, index : u32 ) ?Dim2
  {
    if( !self.isIndexInGrid( index ))
    {
      def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridScale.x, self.gridScale.y });
      return null;
    }
    return Dim2{ .x = index % self.gridScale.x, .y = index / self.gridScale.x };
  }

  pub inline fn getTileIndex( self : *const Tilemap, gridPos : Dim2 ) ?u32
  {
    if( !self.isTileInGrid( gridPos ))
    {
      def.log( .ERROR, 0, @src(), "Tile position {d}:{d} is out of bounds for tilemap with scale {d}:{d}", .{ gridPos.x, gridPos.y, self.gridScale.x, self.gridScale.y });
      return null;
    }
    return ( gridPos.y * self.gridScale.x ) + gridPos.x;
  }

  pub inline fn getTile( self : *Tilemap, gridPos : Dim2 ) ?*Tile
  {
    const index = self.getTileIndex( gridPos ) orelse return null;
    return &self.tileArray[ index ];
  }


  // ================ GRID FUNCTIONS ================

  pub inline fn isCoordInGrid( self : *const Tilemap, coord : Dim2 ) bool
  {
    return( coord.x < self.gridScale.x and coord.y < self.gridScale.y );
  }
  pub inline fn isIndexInGrid( self : *const Tilemap, index : u32 ) bool
  {
    return( index < self.gridScale.x * self.gridScale.y );
  }
//pub inline fn isTileArrayProperlySized( self : *const Tilemap ) bool
//{
//  return( self.tileArray.len == self.gridScale.x * self.gridScale.y );
//}

  pub fn fillWithType( self : *Tilemap, tileType : e_tile_type ) void
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot fill grid with type {s}", .{ self.id, @tagName( tileType ) });
      return;
    }

    for( 0..self.gridScale.x * self.gridScale.y )| index |
    {
      const coords = self.getTileCoords( index ) orelse
      {
        def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridScale.x, self.gridScale.y });
        continue;
      };

      self.tileArray[ index ] = Tile{
        .tType  = tileType,
        .colour = getTileTypeColour( tileType ),
        .mapPos = coords,
      };
    }
  }

  // ================ POSITION FUNCTIONS ================

  pub inline fn getGridCenter( self : *const Tilemap ) Vec2 { return Vec2{ .x = self.gridPos.x, .y = self.gridPos.y }; }
  pub inline fn getGridRot(    self : *const Tilemap ) f32  { return self.gridPos.z; }
  pub inline fn getTilePos(    self : *const Tilemap, gridPos : Dim2 ) VecR
  {
    const relPos = def.addVec2( self.getGridCenter(), self.getRelTilePos( gridPos ));
    return VecR{ .x = relPos.x, .y = relPos.y, .z = self.gridPos.z };
  }
  pub fn getRelTilePos( self : *const Tilemap, gridPos : Dim2 ) Vec2
  {
    var tilePos = switch( self.tileShape )
    {
      .RECT => Vec2{
        .x = @as( f32, @floatFromInt( gridPos.x )) + 0.5,
        .y = @as( f32, @floatFromInt( gridPos.y )) + 0.5,
        },
      // TODO : add other shapes ( trickier posisitons )
    };

    tilePos = def.mulVec2(    tilePos, self.tileScale );
    tilePos = def.rotVec2Rad( tilePos, self.getRot()  );

    return tilePos;
  }

  // =============== DRAW FUNCTIONS ================

  pub fn drawSingleTile( self : *const Tilemap, gridPos : Dim2 ) void
  {
    const tile = self.getTile( gridPos ) orelse
    {
      def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ gridPos.x, gridPos.y, -1 });
      return;
    };

    if( tile.tType == .EMPTY )
    {
      def.log( .TRACE, 0, @src(), "Tile at position {d}:{d} is empty, not drawing", .{ gridPos.x, gridPos.y });
      return;
    }

    const pos = self.getTilePos( gridPos );
    def.drawCircle( pos, self.tileScale.x / 2, tile.colour ); // TODO : replace by proper polygon
  }

  pub fn drawTilemap( self : *const Tilemap ) void
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot draw", .{ self.id });
      return;
    }

    for( 0..self.gridScale.x * self.gridScale.y )| index |
    {
      const gridPos = self.getTileCoords( index ) orelse
      {
        def.log( .ERROR, 0, @src(), "Tile index {d} is out of bounds for tilemap with scale {d}:{d}", .{ index, self.gridScale.x, self.gridScale.y });
        continue;
      };
      self.drawSingleTile( gridPos );
    }
  }

  // TODO : test me
  pub fn findHitTileCoords( self : *const Tilemap, point : Vec2 ) ?Dim2
  {
    if( !self.isInit() )
    {
      def.log( .ERROR, 0, @src(), "Tilemap {d} is not initialized, cannot find hit tile", .{ self.id });
      return null;
    }

    // Aligning the rotation of the point to the tilemap's
    var p = def.rotVec2Rad( point, -self.getRot());

    // Canceling out the grid's pos and scale
    p = def.subVec2( p, self.getGridCenter() );
    p = def.divVec2( p, self.tileScale );
    p = def.addVec2( p, Vec2{ .x = 0.5, .y = 0.5 });

    if( p.x < 0 or p.x >= @as( f32, self.gridScale.x ) or p.y < 0 or p.y >= @as( f32, self.gridScale.y ))
    {
      def.log( .DEBUG, 0, @src(), "Point {d}:{d} is out of bounds for tilemap with scale {d}:{d}", .{ p.x, p.y, self.gridScale.x, self.gridScale.y });
      return null;
    }

    // Getting the tile hit
    return switch( self.tileShape )
    {
      .RECT => Dim2{
        .x = @as( u16, @intFromFloat( @floor( p.x ))),
        .y = @as( u16, @intFromFloat( @floor( p.y ))),
      }
      // TODO : add other shapes ( trickier posisitons )
    };
  }
};



