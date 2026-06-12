const std     = @import( "std" );
const eng     = @import( "engine" );
const utl = @import( "utils" );

const Tile    = eng.tilemap.Tile;
const Tilemap = eng.tilemap.Tilemap;
const Vec2    = utl.Vec2;
const VecA    = utl.VecA;

pub const TilemapManager = struct
{
  maxId       : u32  = 0,
  isInit      : bool = false,
  allocator   : std.mem.Allocator       = undefined,
  tilemapList : std.ArrayList( Tilemap ) = .empty,

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID FUNCTIONS ================

  fn getNewId( self : *TilemapManager ) u32
  {
    if( !self.isInit )
    {
      utl.qlog( .ERROR, @src(), "Tilemap manager is not initialized : returning id 0" );
      return 0;
    }
    self.maxId += 1;
    return self.maxId;
  }

  pub fn getMaxId( self : *TilemapManager ) u32
  {
    if( !self.isInit )
    {
      utl.qlog( .ERROR, @src(), "Tilemap manager is not initialized : returning id 0" );
      return 0;
    }
    return self.maxId;
  }

  pub fn recalcMaxId( self : *TilemapManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .ERROR, @src(), "Tilemap manager is not initialized : cannot recalculate maxId" );
      return;
    }
    var newMaxId: u32 = 0;

    for( self.tilemapList.items )| *tlmp |
    {
      if( tlmp.id > newMaxId ) { newMaxId = tlmp.id; }
    }

    if( newMaxId < self.maxId )
    {
      utl.log( .TRACE, @src(), "Recalculated maxId {d} is less than previous maxId {d}", .{ newMaxId, self.maxId });
    }
    else if( newMaxId > self.maxId )
    {
      utl.log( .WARN, @src(), "Recalculated maxId {d} is greater than previous maxId {d}", .{ newMaxId, self.maxId });
    }

    self.maxId = newMaxId;
  }

  pub fn isIdValid( self : *TilemapManager, id : u32 ) bool
  {
    if( id <= 0 )
    {
      utl.qlog( .WARN, @src(), "Tilemap Id cannot be 0 or less" );
      return false;
    }
    if( id > self.maxId )
    {
      utl.log( .WARN, @src(), "Tilemap Id {d} is greater than maxId {d}", .{ id, self.maxId });
      return false;
    }
    return true;
  }

  // ================ INDEX FUNCTIONS ================

  fn getIndexOf( self : *TilemapManager, id : u32 ) ?usize
  {
    if( !self.isInit )
    {
      utl.qlog( .ERROR, @src(), "Tilemap manager is not initialized : returning null" );
      return null;
    }

    if( !self.isIdValid( id ))
    {
      utl.log( .WARN, @src(), "Tilemap Id {d} is not valid", .{ id });
      return null;
    }

    for( self.tilemapList.items, 0 .. )| tlmp, index |{ if( tlmp.id == id ){ return index; }}

    utl.log( .TRACE, @src(), "Tilemap with Id {d} not found", .{ id });
    return null;
  }

  fn isIndexValid( self : *TilemapManager, index : ?usize ) bool
  {
    if( self.tilemapList.len == 0 )
    {
      utl.qlog( .WARN, @src(), "No tilemapList available" );
      return false;
    }
    if( index == null )
    {
      utl.qlog( .WARN, @src(), "Index is null" );
      return false;
    }
    if( index < 0 )
    {
      utl.log( .WARN, @src(), "Index {d} is negative", .{ index });
      return false;
    }
    if( index >= self.tilemapList.items.len )
    {
      utl.log( .WARN, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.tilemapList.len });
      return false;
    }
    return true;
  }

  // ================================ INITIALISATION MANAGEMENT ================================

  pub fn init( self : *TilemapManager, allocator : std.mem.Allocator ) void
  {
    utl.qlog( .TRACE, @src(), "# Initializing Tilemap manager..." );

    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "@ Tilemap manager is already initialized" );
      return;
    }

    self.allocator   = allocator;
    self.tilemapList = .empty;
    self.isInit      = true;

    utl.qlog( .INFO, @src(), "$ Tilemap manager initialized !\n" );
  }

  pub fn deinit( self : *TilemapManager ) void
  {
    utl.qlog( .TRACE, @src(), "# Deinitializing Tilemap manager..." );

    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "@ Tilemap manager was not initialized" );
      return;
    }

    for( self.tilemapList.items )| *tlmp |{ tlmp.deinit( self.allocator ); }

    self.tilemapList.deinit( self.allocator );
    self.maxId = 0;

    self.isInit    = false;
    self.allocator = undefined;
    utl.qlog( .INFO, @src(), "$ Tilemap manager deinitialized\n" );
  }

  // ================================ TILEMAP MANAGEMENT FUNCTIONS ================================

  pub fn loadTilemapFromParams( self : *TilemapManager, params : Tilemap, fillType : eng.tilemap.TileType ) ?*Tilemap
  {
    utl.qlog( .TRACE, @src(), "Adding new Tilemap" );

    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Tilemap manager is not initialized" );
      return null;
    }

    var tmp = Tilemap.createTilemapFromParams( params, fillType, self.allocator ) orelse
    {
      utl.qlog( .ERROR, @src(), "Failed to create Tilemap from params" );
      return null;
    };

    tmp.id = self.getNewId();
    if( params.id != 0 and params.id != tmp.id )
    {
      utl.log( .WARN, @src(), "Dummy id ({d}) differs from given id ({d})", .{ params.id, tmp.id });
    }

    self.tilemapList.append( self.allocator, tmp ) catch | err |
    {
      utl.log( .ERROR, @src(), "Failed to add Tilemap: {}", .{ err });
      return null;
    };

    const tlmp : *Tilemap = &self.tilemapList.items[ self.tilemapList.items.len - 1 ];

    return tlmp;
  }


  pub fn loadDefaultTilemap( self : *TilemapManager ) ?*Tilemap
  {
    utl.qlog( .TRACE, @src(), "Creating default Tilemap" );

    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Tilemap manager is not initialized" );
      return null;
    }

    return self.loadTilemapFromParams( .{}, .T1 );
  }

  // pub fn loadTilemapFromFile( self : *TilemapManager, filePath : []const u8 ) ?*Tilemap

  pub fn getTilemap( self : *TilemapManager, id : u32 ) ?*Tilemap
  {
    utl.log( .TRACE, @src(), "Getting Tilemap with Id {d}", .{ id });

    const index = self.getIndexOf( id ) orelse
    {
      utl.log( .TRACE, @src(), "Tilemap with Id {d} not found : returning null", .{ id });
      return null;
    };

    return &self.tilemapList.items[ index ];
  }

  pub fn delTilemap( self : *TilemapManager, id : u32 ) void
  {
    const index = self.getIndexOf( id );

    if( index == null )
    {
      utl.log( .WARN, @src(), "Tilemap with Id {d} not found : returning", .{ id });
      return;
    }

    var tlmp = &self.tilemapList.items[ index ];

    tlmp.deinit( self.allocator );
    _ = self.tilemapList.swapRemove( index );

    utl.log( .DEBUG, @src(), "Tilemap with Id {d} deleted", .{ id });
  }

  pub fn deleteAllMarkedTilemaps( self : *TilemapManager ) void
  {
    utl.qlog( .TRACE, @src(), "Deleting all Tilemaps marked for deletion" );

    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Tilemap manager is not initialized" );
      return;
    }

    // Iterate through all tilemaps and delete those marked for deletion via the .DELETE flag
    for( self.tilemapList.items, 0 .. )| *tlmp, index |
    {
      if( index >= self.tilemapList.items.len ){ break; }
      if( tlmp.canBeDel() )
      {
        tlmp.deinit( self.allocator );
        _ = self.tilemapList.swapRemove( index );
      }
    }

    self.recalcMaxId();
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderTilemapHitboxes( self : *TilemapManager ) void // TODO : have this take in a renderer construct and pass it to Body.renderHitbox()
  {
    utl.qlog( .TRACE, @src(), "Rendering Tilemap hitboxes" );

    for( self.tilemapList.items )| *tlmp  |{ if( tlmp.isActive() )
    {
      const mapBox = tlmp.getMapBoundingBox();
      eng.wDraw.rect( mapBox.center, mapBox.scale, .{}, utl.Colour.yellow.setA( 32 ));

      if( eng.G_CNFGS.DebugDraw_Tile ){ for ( 0 .. tlmp.getTileCount() )| index |
      {
        const tile = tlmp.tileArray[ index ];
        const tilePos = tlmp.getRelTilePos( tile.mapCoords );
        const tileBox = tlmp.getTileBoundingBox( tilePos );
        eng.wDraw.rect( tileBox.center, tileBox.scale, .{}, utl.Colour.green.setA( 32 ));
      }}
    }}
  }

  pub fn renderActiveTilemaps( self : *TilemapManager, ng : *eng.Engine ) void // TODO : have this take in a renderer construct and pass it to Tilemap.renderGraphics()
  {
    _ = ng;

    utl.qlog( .TRACE, @src(), "Rendering active Tilemaps" );

    for( self.tilemapList.items )| *tlmp |{ if( tlmp.isActive() )
    {
      tlmp.drawTilemap();
    }}
  }

  // ================================ TICK FUNCTIONS ================================

  pub fn tickActiveTilemaps( self : *TilemapManager, ng : *eng.Engine ) void
  {
    _ = ng;

    for( self.tilemapList.items )| *tlmp |{ if( tlmp.isActive() )
    {
      // Reserved for future tilemap-owned simulation.
    }}
  }
};


test "TilemapManager starts with empty tilemap storage"
{
  const manager : TilemapManager = .{};

  try std.testing.expect( !manager.isInit );
  try std.testing.expectEqual( @as( usize, 0 ), manager.tilemapList.items.len );
  try std.testing.expectEqual( @as( usize, 0 ), manager.tilemapList.capacity );
}
