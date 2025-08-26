const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;
const VecA   = def.VecA;

pub const EntityManager = struct
{
  isInit   : bool = false,
  maxID    : u32  = 0,
  entityList : std.ArrayList( Entity ) = undefined,

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID FUNCTIONS ================

  fn getNewID( self : *EntityManager ) u32
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Entity manager is not initialized : returning id 0" );
      return 0;
    }

    self.maxID += 1;
    return self.maxID;
  }

  pub fn getMaxID( self : *EntityManager ) u32
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Entity manager is not initialized : returning id 0" );
      return 0;
    }

    return self.maxID;
  }

  pub fn recalcMaxID( self : *EntityManager ) void
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Entity manager is not initialized : cannot recalculate maxID" );
      return;
    }
    var newMaxID: u32 = 0;

    for( self.entityList.items )| *e |
    {
      if( e.id > newMaxID ) { newMaxID = e.id; }
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

  pub fn isIdValid( self : *EntityManager, id : u32 ) bool
  {
    if( id <= 0 )
    {
      def.qlog( .WARN, 0, @src(), "Entity ID cannot be 0 or less" );
      return false;
    }
    if( id > self.maxID )
    {
      def.log( .WARN, 0, @src(), "Entity ID {d} is greater than maxID {d}", .{ id, self.maxID });
      return false;
    }
    return true;
  }

  // ================ INDEX FUNCTIONS ================

  fn getIndexOf( self : *EntityManager, id : u32 ) ?usize
  {
    if( !self.isInit )
    {
      def.qlog( .ERROR, 0, @src(), "Entity manager is not initialized : returning null" );
      return null;
    }

    if( !self.isIdValid( id ))
    {
      def.log( .WARN, 0, @src(), "Entity ID {d} is not valid", .{ id });
      return null;
    }

    for( self.entityList.items, 0.. )| e, index |
    {
      if( e.id == id ){ return index; }
    }

    def.log( .TRACE, 0, @src(), "Entity with ID {d} not found", .{ id });
    return null;
  }

  fn isIndexValid( self : *EntityManager, index : ?usize ) bool
  {
    if( self.entityList.len == 0 )
    {
      def.qlog( .WARN, 0, @src(), "No entityList available" );
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
    if( index >= self.entityList.items.len )
    {
      def.log( .WARN, 0, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.entityList.len });
      return false;
    }
    return true;
  }

  // ================================ INITIALISATION MANAGEMENT ================================

  pub fn init( self : *EntityManager, allocator : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing Entity manager" );

    if( self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Entity manager is already initialized" );
      return;
    }

    self.entityList = std.ArrayList( Entity ).init( allocator  );

    self.isInit = true;
    def.qlog( .INFO, 0, @src(), "Entity manager initialized" );
  }

  pub fn deinit( self : *EntityManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing Entity manager" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Entity manager is not initialized" );
      return;
    }

    self.entityList.deinit();
    self.maxID = 0;

    self.isInit = false;
    def.qlog( .INFO, 0, @src(), "Entity manager deinitialized" );
  }

  // ================================ ENTITY MANAGEMENT FUNCTIONS ================================

  pub fn loadEntityFromParams( self : *EntityManager, params : Entity ) ?*Entity
  {
    def.qlog( .TRACE, 0, @src(), "Adding new Entity" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Entity manager is not initialized" );
      return null;
    }

    var tmp = params;
    tmp.id  = self.getNewID();

    if( params.id != 0 and params.id != tmp.id )
    {
      def.log( .WARN, 0, @src(), "Dummy id ({d}) differs from given id ({d})", .{ params.id, tmp.id });
    }

    self.entityList.append( tmp ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to add Entity: {}", .{ err });
      return null;
    };

    return &self.entityList.items[ self.entityList.items.len - 1 ];
  }

  // pub fn loadEntitiesFromFile( self : *EntityManager, filePath : []const u8 ) ?*Entity

  pub fn loadDefaultEntity( self : *EntityManager ) ?*Entity
  {
    def.qlog( .TRACE, 0, @src(), "Creating default Entity" );

    return self.loadEntityFromParams( Entity{
      .pos    = .{},
      .colour = def.newColour( 255, 255, 255, 255 ),
      .shape  = .RECT,
    });
  }

  pub fn getEntity( self : *EntityManager, id : u32 ) ?*Entity
  {
    def.log( .TRACE, 0, @src(), "Getting Entity with ID {d}", .{ id });

    const index = self.getIndexOf( id ) orelse
    {
      def.log( .TRACE, 0, @src(), "Entity with ID {d} not found : returning null", .{ id });
      return null;
    };

    return &self.entityList.items[ index ];
  }

  pub fn delEntity( self : *EntityManager, id : u32 ) void
  {
    const index = self.getIndexOf( id );

    if( index == null )
    {
      def.log( .WARN, 0, @src(), "Entity with ID {d} not found : returning", .{ id });
      return;
    }

    _ = self.entityList.swapRemove( index );
    def.log( .DEBUG, 0, @src(), "Entity with ID {d} deleted", .{ id });
  }

  pub fn deleteAllMarkedEntities( self : *EntityManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deleting all Entities marked for deletion" );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Entity manager is not initialized" );
      return;
    }

    // Iterate through all entities and delete those marked for deletion via the .DELETE flag
    for( self.entityList.items, 0.. )| e, index |
    {
      if( index >= self.entityList.items.len ){ break; }
      if( e.canBeDel() ){ _ = self.entityList.swapRemove( index ); }
    }

    self.recalcMaxID();
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderEntityHitboxes( self : *EntityManager ) void // TODO : have this take in a renderer construct and pass it to Entity.renderHitbox()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering Entity hitboxes" );

    for( self.entityList.items )| *e |{ if( e.isActive() )
    {
      if( e.isSolid() ){ e.hitbox.drawSelf( def.newColour( 0, 0, 255, 64 )); }
      else             { e.hitbox.drawSelf( def.newColour( 255, 0, 0, 64 )); }

    }}
  }

  pub fn renderActiveEntities( self : *EntityManager ) void // TODO : have this take in a renderer construct and pass it to Entity.renderGraphics()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering active Entities" );

    for( self.entityList.items )| *e |{ if( e.isActive() )
    {
      e.renderSelf();
    }}
  }

  // ================================ TICK FUNCTIONS ================================

  pub fn tickActiveEntities( self : *EntityManager, sdt : f32 ) void
  {
    for( self.entityList.items )| *e |{ if( e.isActive() )
    {
      e.moveSelf( sdt );
    }}
  }

  pub fn collideActiveEntities( self : *EntityManager, sdt : f32 ) void
  {
    _ = sdt; // Prevent unused variable warning

    for( self.entityList.items, 0 .. )| *e1, index |{ if( e1.isActive() )
    {
      if( index + 1 >= self.entityList.items.len ){ continue; } // Prevents out of bounds access

      // Iterate through all following entities ( those following the current one in the list ) to check for collisions
      for( self.entityList.items[ index + 1 .. ])| e2 |{ if( e2.isActive() )
      {
        const overlap = e1.getOverlap( &e2 ) orelse continue; // TODO : swap this with "collideWith( e2 )" when implemented
        {
          def.log( .DEBUG, 0, @src(), "Collision detected between Entity {d} and {d} with magnitude {d}:{d}", .{ e1.id, e2.id, overlap.x, overlap.y });
          def.log( .DEBUG, 0, @src(), "Entity {d} position: {d}:{d}, Entity {d} position: {d}:{d}", .{ e1.id, e1.pos.x, e1.pos.y, e2.id, e2.pos.x, e2.pos.y });
          def.log( .DEBUG, 0, @src(), "Entity {d} scale:    {d}:{d}, Entity {d} scale:    {d}:{d}", .{ e1.id, e1.scale.x, e1.scale.y, e2.id, e2.scale.x, e2.scale.y });
        }
      }}
    }}
  }
};