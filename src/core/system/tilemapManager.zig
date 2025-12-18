const std     = @import( "std" );
const def     = @import( "defs" );

const Tile    = def.tlm.Tile;
const Tilemap = def.tlm.Tilemap;
const Vec2    = def.Vec2;
const VecA    = def.VecA;

pub const TilemapManager = struct
{
  maxID       : u32  = 0,
  isInit      : bool = false,
  allocator   : std.mem.Allocator       = undefined,
  tilemapList : std.ArrayList( Tilemap ) = undefined,

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID FUNCTIONS ================

  fn getNewID( self : *TilemapManager ) u32
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Tilemap manager is not initialized : returning id 0" );
      return 0;
    }
    self.maxID += 1;
    return self.maxID;
  }

  pub fn getMaxID( self : *TilemapManager ) u32
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Tilemap manager is not initialized : returning id 0" );
      return 0;
    }
    return self.maxID;
  }

  pub fn recalcMaxID( self : *TilemapManager ) void
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Tilemap manager is not initialized : cannot recalculate maxID" );
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
      def.qlog( .WARN, 0, @src(), "Tilemap ID cannot be 0 or less" );
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
      def.qlog( .ERROR, 0, @src(), "Tilemap manager is not initialized : returning null" );
      return null;
    }

    if( !self.isIdValid( id ))
    {
      def.log( .WARN, 0, @src(), "Tilemap ID {d} is not valid", .{ id });
      return null;
    }

    for( self.tilemapList.items, 0 .. )| tlmp, index |{ if( tlmp.id == id ){ return index; }}

    def.log( .TRACE, 0, @src(), "Tilemap with ID {d} not found", .{ id });
    return null;
  }

  fn isIndexValid( self : *TilemapManager, index : ?usize ) bool
  {
    if( self.tilemapList.len == 0 )
    {
      def.qlog( .WARN, 0, @src(), "No tilemapList available" );
      return false;
    }
    if( index == null )
    {
      def.qlog( .WARN, 0, @src(), "Index is null" );
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
    def.qlog( .TRACE, 0, @src(), "# Initializing Tilemap manager..." );

    if( self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "@ Tilemap manager is already initialized" );
      return;
    }

    self.tilemapList = std.ArrayList( Tilemap ).empty;
    //self.tilemapList = std.ArrayList( Tilemap ).initCapacity( self.allocator, 4 ) catch
    //{
    //  def.qlog( .ERROR, 0, @src(), "Failed to initialize tilemapList to proper default lenght" );
    //  return;
    //};

    self.isInit    = true;
    self.allocator = allocator;
    def.qlog( .INFO, 0, @src(), "$ Tilemap manager initialized !\n" );
  }

  pub fn deinit( self : *TilemapManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Deinitializing Tilemap manager..." );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "@ Tilemap manager was not initialized" );
      return;
    }

    for( self.tilemapList.items )| *tlmp |{ tlmp.deinit( self.allocator ); }

    self.tilemapList.deinit( self.allocator );
    self.maxID = 0;

    self.isInit    = false;
    self.allocator = undefined;
    def.qlog( .INFO, 0, @src(), "$ Tilemap manager deinitialized\n" );
  }

  // ================================ TILEMAP MANAGEMENT FUNCTIONS ================================

  pub fn loadTilemapFromParams( self : *TilemapManager, params : Tilemap, fillType : def.tlm.e_tile_type ) ?*Tilemap
  {
    def.qlog( .TRACE, 0, @src(), "Adding new Tilemap" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Tilemap manager is not initialized" );
      return null;
    }

    var tmp = Tilemap.createTilemapFromParams( params, fillType, self.allocator ) orelse
    {
      def.qlog( .ERROR, 0, @src(), "Failed to create Tilemap from params" );
      return null;
    };

    tmp.id = self.getNewID();
    if( params.id != 0 and params.id != tmp.id )
    {
      def.log( .WARN, 0, @src(), "Dummy id ({d}) differs from given id ({d})", .{ params.id, tmp.id });
    }

    self.tilemapList.append( self.allocator, tmp ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to add Tilemap: {}", .{ err });
      return null;
    };

    const tlmp : *Tilemap = &self.tilemapList.items[ self.tilemapList.items.len - 1 ];

    //if( tlmp.script.hasScript() ){ _ = tlmp.script.init( ng ); } // TODO : see if this needs implementing

    return tlmp;
  }


  pub fn loadDefaultTilemap( self : *TilemapManager ) ?*Tilemap
  {
    def.qlog( .TRACE, 0, @src(), "Creating default Tilemap" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Tilemap manager is not initialized" );
      return null;
    }

    return self.loadTilemapFromParams( .{}, .T1 );
  }

  // pub fn loadTilemapFromFile( self : *TilemapManager, filePath : []const u8 ) ?*Tilemap

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

    var tlmp = &self.tilemapList.items[ index ];

    //if( tlmp.script.hasScript() ){ _ = tlmp.script.exit( ng ); } // TODO : see if this needs implementing
    tlmp.deinit( self.allocator );
    _ = self.tilemapList.swapRemove( index );

    def.log( .DEBUG, 0, @src(), "Tilemap with ID {d} deleted", .{ id });
  }

  pub fn deleteAllMarkedTilemaps( self : *TilemapManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deleting all Tilemaps marked for deletion" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Tilemap manager is not initialized" );
      return;
    }

    // Iterate through all tilemaps and delete those marked for deletion via the .DELETE flag
    for( self.tilemapList.items, 0 .. )| *tlmp, index |
    {
      if( index >= self.tilemapList.items.len ){ break; }
      if( tlmp.canBeDel() )
      {
      //if( tlmp.script.hasScript() ){ _ = tlmp.script.exit( ng ); } // TODO : see if this needs implementing
        tlmp.deinit( self.allocator );
        _ = self.tilemapList.swapRemove( index );
      }
    }

    self.recalcMaxID();
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderTilemapHitboxes( self : *TilemapManager ) void // TODO : have this take in a renderer construct and pass it to Entity.renderHitbox()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering Tilemap hitboxes" );

    for( self.tilemapList.items )| *tlmp  |{ if( tlmp.isActive() )
    {
      tlmp.getMapBoundingBox().drawSelf( def.Colour.yellow.setA( 32 ));

      if( def.G_ST.DebugDraw_Tile ){ for ( 0 .. tlmp.getTileCount() )| index |
      {
        const tile = tlmp.tileArray.items.ptr[ index ];
        const tilePos = tlmp.getRelTilePos( tile.mapCoords );
        tlmp.getTileBoundingBox( tilePos ).drawSelf( def.Colour.green.setA( 32 ));
      }}
    }}
  }

  pub fn renderActiveTilemaps( self : *TilemapManager, ng : *def.Engine ) void // TODO : have this take in a renderer construct and pass it to Tilemap.renderGraphics()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering active Tilemaps" );

    for( self.tilemapList.items )| *tlmp |{ if( tlmp.isActive() )
    {
      tlmp.drawTilemap();
      if( tlmp.script.hasScript() ){ _ = tlmp.script.rndr( ng ); }
    }}
  }

  // ================================ TICK FUNCTIONS ================================

  pub fn tickActiveTilemaps( self : *TilemapManager, ng : *def.Engine ) void
  {
    const sdt = ng.getScaledTargetTickDelta();

    for( self.tilemapList.items )| *tlmp |{ if( tlmp.isActive() )
    {
      if( tlmp.isActive() )
      {
      //tlmp.moveSelf( sdt ); // DNE
        if( tlmp.script.hasScript() ){ _ = tlmp.script.tick( ng, sdt ); }
      }
    }}
  }
};