const std = @import( "std" );
const def = @import( "defs" );

const Tile    = def.tlm.Tile;
const Tilemap = def.tlm.Tilemap;
const Vec2    = def.Vec2;
const VecR    = def.VecR;

pub const TilemapManager = struct
{
  isInit   : bool = false,
  maxID    : u32  = 0,
  tilemapList : std.ArrayList( Tilemap ) = undefined,

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID FUNCTIONS ================

  fn getNewID( self : *TilemapManager ) u32
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Tilemap manager is not initialized : returning id 0", .{});
      return 0;
    }

    self.maxID += 1;
    return self.maxID;
  }

  pub fn getMaxID( self : *TilemapManager ) u32
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Tilemap manager is not initialized : returning id 0", .{});
      return 0;
    }

    return self.maxID;
  }

  pub fn recalcMaxID( self : *TilemapManager ) void
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Tilemap manager is not initialized : cannot recalculate maxID", .{});
      return;
    }
    var newMaxID: u32 = 0;

    for( self.tilemapList.items )| *tlmp |
    {
      if( tlmp.id > newMaxID ) { newMaxID = tlmp.id; }
    }

    if( newMaxID < self.maxID )
    {
      def.log( .TRACE, 0, @src(), "Recalculated maxID {d} is less than previous maxID {d}", .{ newMaxID, self.maxID });
    }
    else if( newMaxID > self.maxID )
    {
      def.log( .WARN, 0, @src(), "Recalculated maxID {d} is greater than previous maxID {d}", .{ newMaxID, self.maxID });
    }

    self.maxID = newMaxID;
  }

  pub fn isIdValid( self : *TilemapManager, id : u32 ) bool
  {
    if( id <= 0 )
    {
      def.log( .WARN, 0, @src(), "Tilemap ID cannot be 0 or less", .{});
      return false;
    }
    if( id > self.maxID )
    {
      def.log( .WARN, 0, @src(), "Tilemap ID {d} is greater than maxID {d}", .{ id, self.maxID });
      return false;
    }
    return true;
  }

  // ================ INDEX FUNCTIONS ================

  fn getIndexOf( self : *TilemapManager, id : u32 ) ?usize
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Tilemap manager is not initialized : returning null", .{});
      return null;
    }

    if( !self.isIdValid( id ))
    {
      def.log( .WARN, 0, @src(), "Tilemap ID {d} is not valid", .{ id });
      return null;
    }

    for( self.tilemapList.items, 0.. )| tlmp, index |
    {
      if( tlmp.id == id ){ return index; }
    }

    def.log( .TRACE, 0, @src(), "Tilemap with ID {d} not found", .{ id });
    return null;
  }

  fn isIndexValid( self : *TilemapManager, index : ?usize ) bool
  {
    if( self.tilemapList.len == 0 )
    {
      def.log( .WARN, 0, @src(), "No tilemapList available", .{});
      return false;
    }
    if( index == null )
    {
      def.log( .WARN, 0, @src(), "Index is null", .{});
      return false;
    }
    if( index < 0 )
    {
      def.log( .WARN, 0, @src(), "Index {d} is negative", .{ index });
      return false;
    }
    if( index >= self.tilemapList.items.len )
    {
      def.log( .WARN, 0, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.tilemapList.len });
      return false;
    }
    return true;
  }

  // ================================ INITIALISATION MANAGEMENT ================================

  pub fn init( self : *TilemapManager, allocator : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing Tilemap manager" );

    if( self.isInit )
    {
      def.log( .WARN, 0, @src(), "Tilemap manager is already initialized", .{});
      return;
    }

    self.tilemapList = std.ArrayList( Tilemap ).init( allocator  );

    self.isInit = true;
    def.log( .INFO, 0, @src(), "Tilemap manager initialized", .{});
  }

  pub fn deinit( self : *TilemapManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing Tilemap manager" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Tilemap manager is not initialized", .{});
      return;
    }

    for( self.tilemapList.items )| *tlmp |{ tlmp.deinit(); }

    self.tilemapList.deinit();
    self.maxID = 0;

    self.isInit = false;
    def.log( .INFO, 0, @src(), "Tilemap manager deinitialized", .{});
  }

  // ================================ ENTITY MANAGEMENT FUNCTIONS ================================

  pub fn loadTilemapFromParams( self : *TilemapManager, allocator : std.mem.Allocator, params : Tilemap, fillType : ?def.tlm.e_tile_type ) ?*Tilemap
  {
    def.qlog( .TRACE, 0, @src(), "Adding new Tilemap" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Tilemap manager is not initialized", .{});
      return null;
    }

    if( params.isInit() )
    {
      def.log( .WARN, 0, @src(), "Tilemap to be added is already initialized", .{});
      return null;
    }

    var tmp = params;
    tmp.id  = self.getNewID();

    if( params.id != 0 and params.id != tmp.id )
    {
      def.log( .WARN, 0, @src(), "Dummy id ({d}) differs from given id ({d})", .{ params.id, tmp.id });
    }

    tmp.init( allocator, fillType );

    self.tilemapList.append( tmp ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to add Tilemap: {}", .{ err });
      return null;
    };

    return &self.tilemapList.items[ self.tilemapList.items.len - 1 ];
  }

  // pub fn loadTilemapFromFile( self : *TilemapManager, filePath : []const u8, allocator : std.mem.Allocator ) ?*Tilemap

  pub fn createDefaultTilemap( self : *TilemapManager, allocator : std.mem.Allocator ) ?*Tilemap
  {
    def.qlog( .TRACE, 0, @src(), "Creating default Tilemap" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Tilemap manager is not initialized", .{});
      return null;
    }

    return self.createTilemapFromParams( Tilemap{
      .gridPos   = Vec2{ .x = 0, .y = 0 },
      .gridScale = Vec2{ .x = 32, .y = 32 },
      .tileScale = Vec2{ .x = 32, .y = 32 },
      .tileShape = .RECT,
    }, allocator, .FLOOR );
  }

  pub fn getTilemap( self : *TilemapManager, id : u32 ) ?*Tilemap
  {
    def.log( .TRACE, 0, @src(), "Getting Tilemap with ID {d}", .{ id });

    const index = self.getIndexOf( id ) orelse
    {
      def.log( .TRACE, 0, @src(), "Tilemap with ID {d} not found : returning null", .{ id });
      return null;
    };

    return &self.tilemapList.items[ index ];
  }

  pub fn delTilemap( self : *TilemapManager, id : u32 ) void
  {
    const index = self.getIndexOf( id );

    if( index == null )
    {
      def.log( .WARN, 0, @src(), "Tilemap with ID {d} not found : returning", .{ id });
      return;
    }

    var tilemap = &self.tilemapList.items[ index ];
    tilemap.deinit();

    _ = self.tilemapList.swapRemove( index );
    def.log( .DEBUG, 0, @src(), "Tilemap with ID {d} deleted", .{ id });
  }

  pub fn deleteAllMarkedTilemaps( self : *TilemapManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deleting all Tilemaps marked for deletion" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Tilemap manager is not initialized", .{});
      return;
    }

    // Iterate through all tilemaps and delete those marked for deletion via the .DELETE flag
    for( self.tilemapList.items, 0.. )| tlmp, index |
    {
      if( index >= self.tilemapList.items.len ){ break; }
      if( tlmp.canBeDel() ){ _ = self.tilemapList.swapRemove( index ); }
    }

    self.recalcMaxID();
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderActiveTilemaps( self : *TilemapManager ) void // TODO : have this take in a renderer construct and pass it to Tilemap.renderGraphics()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering active Tilemaps" );

    for( self.tilemapList.items )| *tlmp |{ if( tlmp.isActive() )
    {
      //tlmp.renderSelf(); // TODO : implement Tilemap.renderSelf()
    }}
  }

  // ================================ TICK FUNCTIONS ================================

  //pub fn tickActiveTilemaps( self : *TilemapManager, sdt : f32 ) void
  //{
  //  for( self.tilemapList.items )| *tlmp |{ if( tlmp.isActive() )
  //  {
  //    tlmp.moveSelf( sdt );
  //  }}
  //}
};