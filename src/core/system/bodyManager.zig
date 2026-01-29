const std  = @import( "std" );
const def  = @import( "defs" );

const Body = def.bdy.Body;
const Vec2 = def.Vec2;
const VecA = def.VecA;

pub const BodyManager = struct
{
  maxId      : u32  = 0,
  isInit     : bool = false,
  allocator  : std.mem.Allocator      = undefined,
  bodyList : std.ArrayList( Body ) = undefined,

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID FUNCTIONS ================

  fn getNewId( self : *BodyManager ) u32
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Body manager is not initialized : returning id 0" );
      return 0;
    }
    self.maxId += 1;
    return self.maxId;
  }

  pub fn getMaxId( self : *BodyManager ) u32
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Body manager is not initialized : returning id 0" );
      return 0;
    }
    return self.maxId;
  }

  pub fn recalcMaxId( self : *BodyManager ) void
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Body manager is not initialized : cannot recalculate maxId" );
      return;
    }
    var newMaxId: u32 = 0;

    for( self.bodyList.items )| *e |
    {
      if( e.id > newMaxId ) { newMaxId = e.id; }
    }

    if( newMaxId < self.maxId )
    {
      def.log( .TRACE, 0, @src(), "Recalculated maxId {d} is less than previous maxId {d}", .{ newMaxId, self.maxId });
    }
    else if( newMaxId > self.maxId )
    {
      def.log( .WARN, 0, @src(), "Recalculated maxId {d} is greater than previous maxId {d}", .{ newMaxId, self.maxId });
    }
    self.maxId = newMaxId;
  }

  pub fn isIdValid( self : *BodyManager, id : u32 ) bool
  {
    if( id <= 0 )
    {
      def.qlog( .WARN, 0, @src(), "Body Id cannot be 0 or less" );
      return false;
    }
    if( id > self.maxId )
    {
      def.log( .WARN, 0, @src(), "Body Id {d} is greater than maxId {d}", .{ id, self.maxId });
      return false;
    }
    return true;
  }

  // ================ INDEX FUNCTIONS ================

  fn getIndexOf( self : *BodyManager, id : u32 ) ?usize
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Body manager is not initialized : returning null" );
      return null;
    }

    if( !self.isIdValid( id ))
    {
      def.log( .WARN, 0, @src(), "Body Id {d} is not valid", .{ id });
      return null;
    }

    for( self.bodyList.items, 0 .. )| e, index |
    {
      if( e.id == id ){ return index; }
    }

    def.log( .TRACE, 0, @src(), "Body with Id {d} not found", .{ id });
    return null;
  }

  fn isIndexValid( self : *BodyManager, index : ?usize ) bool
  {
    if( self.bodyList.len == 0 )
    {
      def.qlog( .WARN, 0, @src(), "No bodyList available" );
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
    if( index >= self.bodyList.items.len )
    {
      def.log( .WARN, 0, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.bodyList.len });
      return false;
    }
    return true;
  }

  // ================================ INITIALISATION MANAGEMENT ================================

  pub fn init( self : *BodyManager, allocator : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Initializing Body manager..." );

    if( self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "@ Body manager is already initialized" );
      return;
    }

    self.bodyList = std.ArrayList( Body ).empty;
    //self.bodyList = std.ArrayList( Body ).initCapacity( allocator, 64 ) catch
    //{
    //  def.qlog( .ERROR, 0, @src(), "Failed to initialize bodyList to proper default lenght" );
    //  return;
    //};

    self.isInit    = true;
    self.allocator = allocator;
    def.qlog( .INFO, 0, @src(), "$ Body manager initialized !\n" );
  }

  pub fn deinit( self : *BodyManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Deinitializing Body manager..." );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "@ Body manager was not initialized" );
      return;
    }

    self.bodyList.deinit( self.allocator );
    self.maxId = 0;

    self.isInit    = false;
    self.allocator = undefined;
    def.qlog( .INFO, 0, @src(), "$ Body manager deinitialized !\n" );
  }

  // ================================ BODY MANAGEMENT FUNCTIONS ================================

  pub fn loadBodyFromParams( self : *BodyManager, params : Body ) ?*Body
  {
    def.qlog( .TRACE, 0, @src(), "Adding new Body" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Body manager is not initialized" );
      return null;
    }

    var tmp = Body.createBodyFromParams( params ) orelse
    {
      def.qlog( .ERROR, 0, @src(), "Failed to create Body from params" );
      return null;
    };

    tmp.id = self.getNewId();
    if( params.id != 0 and params.id != tmp.id )
    {
      def.log( .WARN, 0, @src(), "Dummy id ({d}) differs from given id ({d})", .{ params.id, tmp.id });
    }

    self.bodyList.append( self.allocator, tmp ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to add Body: {}", .{ err });
      return null;
    };

    const e : *Body = &self.bodyList.items[ self.bodyList.items.len - 1 ];

    //if( e.script.hasScript() ){ _ = e.script.init( ng ); } // TODO : see if this needs implementing

    return e;
  }

  pub fn loadDefaultBody( self : *BodyManager ) ?*Body
  {
    def.qlog( .TRACE, 0, @src(), "Creating default Body" );

    return self.loadBodyFromParams( .{} );
  }

  //pub fn loadBodiesFromFile( self : *BodyManager, filePath : []const u8 ) ?*Body

  pub fn getBody( self : *BodyManager, id : u32 ) ?*Body
  {
    def.log( .TRACE, 0, @src(), "Getting Body with Id {d}", .{ id });

    const index = self.getIndexOf( id ) orelse
    {
      def.log( .TRACE, 0, @src(), "Body with Id {d} not found : returning null", .{ id });
      return null;
    };

    return &self.bodyList.items[ index ];
  }

  pub fn delBody( self : *BodyManager, id : u32 ) void
  {
    const index = self.getIndexOf( id );

    if( index == null )
    {
      def.log( .WARN, 0, @src(), "Body with Id {d} not found : returning", .{ id });
      return;
    }

    const e = &self.bodyList.items[ index ];

    //if( e.script.hasScript() ){ _ = e.script.exit( ng ); } // TODO : see if this needs implementing
    _ = e;

    _ = self.bodyList.swapRemove( index );
    def.log( .DEBUG, 0, @src(), "Body with Id {d} deleted", .{ id });
  }

  pub fn deleteAllMarkedBodies( self : *BodyManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deleting all Bodies marked for deletion" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Body manager is not initialized : returning" );
      return;
    }

    // Iterate through all bodies and delete those marked for deletion via the .DELETE flag
    for( self.bodyList.items, 0 .. )| *e, index |
    {
      if( index >= self.bodyList.items.len ){ break; }
      if( e.canBeDel() )
      {
      //if( e.script.hasScript() ){ _ = e.script.exit( ng ); } // TODO : see if this needs implementing
        _ = self.bodyList.swapRemove( index );
      }
    }

    self.recalcMaxId();
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderBodyHitboxes( self : *BodyManager ) void // TODO : have this take in a renderer construct and pass it to Body.renderHitbox()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering Body hitboxes" );

    for( self.bodyList.items )| *e |{ if( e.isActive() )
    {
      if( e.isSolid() ){ e.hitbox.drawSelf( def.Colour.blue.setA( 32 )); }
      else             { e.hitbox.drawSelf( def.Colour.red.setA(  32 )); }

    }}
  }

  pub fn renderActiveBodies( self : *BodyManager, ng : *def.Engine ) void // TODO : have this take in a renderer construct and pass it to Body.renderGraphics()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering active Bodies" );

    for( self.bodyList.items )| *e |
    {
      if( e.isActive() )
      {
        e.renderSelf();
        if( e.script.hasScript() ){ _ = e.script.rndr( ng ); }
      }
    }
  }

  // ================================ TICK FUNCTIONS ================================

  pub fn tickActiveBodies( self : *BodyManager, ng : *def.Engine ) void
  {
    def.qlog( .TRACE, 0, @src(), "Ticking active Bodies" );

    const sdt = ng.getScaledTargetTickDelta();

    if( def.G_ST.AutoApply_Body_Movement ){ for( self.bodyList.items )| *e |
    {
      if( e.isActive() )
      {
        e.moveSelf( sdt );
        if( e.script.hasScript() ){ _ = e.script.tick( ng, sdt ); }
      }
    }}

    //ng.collideActiveBodies( ng );
  }

  pub fn collideActiveBodies( self : *BodyManager, ng : *def.Engine ) void // TODO : make it actually collide body, instead of just logging overlap
  {
    def.qlog( .TRACE, 0, @src(), "Coliding active Bodies" );

    const sdt = ng.getScaledTargetTickDelta();
    _ = sdt;

    if( def.G_ST.AutoApply_Body_Collision ){ for( self.bodyList.items, 0 .. )| *e1, index |{ if( e1.isActive() )
    {
      if( index + 1 >= self.bodyList.items.len ){ continue; } // Prevents out of bounds access

      // Iterate through all following bodies ( those following the current one in the list ) to check for collisions
      for( self.bodyList.items[ index + 1 .. ])| e2 |{ if( e2.isActive() )
      {
        const overlap = e1.getOverlap( &e2 ) orelse continue; // TODO : swap this with "collideWith( e2 )" when implemented
        {
          def.log( .DEBUG, 0, @src(), "Collision detected between Body {d} and {d} with magnitude {d}:{d}", .{ e1.id, e2.id, overlap.x, overlap.y });
          def.log( .DEBUG, 0, @src(), "Body {d} position: {d}:{d}, Body {d} position: {d}:{d}", .{ e1.id, e1.pos.x, e1.pos.y, e2.id, e2.pos.x, e2.pos.y });
          def.log( .DEBUG, 0, @src(), "Body {d} scale:    {d}:{d}, Body {d} scale:    {d}:{d}", .{ e1.id, e1.scale.x, e1.scale.y, e2.id, e2.scale.x, e2.scale.y });
        }
      }}
    }}}
  }
};