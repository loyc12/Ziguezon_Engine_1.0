const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;
const VecR   = def.VecR;

pub const EntityManager = struct
{
  isInit   : bool = false, // Flag to check if the Entity manager is initialized
  maxID    : u32 = 0,      // Global variable to keep track of the maximum ID assigned
  entities : std.ArrayList( Entity ) = undefined, // List to store all entities

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID FUNCTIONS ================

  fn getNewID( self : *EntityManager ) u32
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Entity manager is not initialized : returning id 0", .{});
      return 0;
    }

    self.maxID += 1;
    return self.maxID;
  }

  pub fn getMaxID( self : *EntityManager ) u32
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Entity manager is not initialized : returning id 0", .{});
      return 0;
    }

    return self.maxID;
  }

  pub fn recalcMaxID( self : *EntityManager ) void
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Entity manager is not initialized : cannot recalculate maxID", .{});
      return;
    }
    var newMaxID: u32 = 0;

    for( self.entities.items )| *e |
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
      def.log( .WARN, 0, @src(), "Entity ID cannot be 0 or less", .{});
      return false; // ID cannot be 0
    }
    if( id > self.maxID )
    {
      def.log( .WARN, 0, @src(), "Entity ID {d} is greater than maxID {d}", .{ id, self.maxID });
      return false; // ID cannot be greater than maxID
    }
    return true; // ID is valid
  }

  // ================ INDEX FUNCTIONS ================

  fn getIndexOf( self : *EntityManager, id : u32 ) ?usize
  {
    if( !self.isInit )
    {
      def.log( .ERROR, 0, @src(), "Entity manager is not initialized : returning null", .{});
      return null;
    }

    if( !self.isIdValid( id ))
    {
      def.log( .WARN, 0, @src(), "Entity ID {d} is not valid", .{ id });
      return null;
    }

    for( self.entities.items, 0.. )| e, index |
    {
      if( e.id == id ){ return index; }
    }

    def.log( .TRACE, 0, @src(), "Entity with ID {d} not found", .{ id });
    return null;
  }

  fn isIndexValid( self : *EntityManager, index : ?usize ) bool
  {
    // Check if the index is valid
    if( self.entities.len == 0 ) // If there are no entities, return false
    {
      def.log( .WARN, 0, @src(), "No entities available", .{});
      return false; // No entities to check against
    }
    if( index == null ) // If the index is null, return false
    {
      def.log( .WARN, 0, @src(), "Index is null", .{});
      return false; // Index cannot be null
    }
    if( index < 0 ) // If the index is negative, return false
    {
      def.log( .WARN, 0, @src(), "Index {d} is negative", .{ index });
      return false; // Index cannot be negative
    }
    if( index >= self.entities.items.len ) // If the index is out of bounds, return false
    {
      def.log( .WARN, 0, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.entities.len });
      return false; // Index cannot be greater than or equal to the length of entities
    }
    return true; // Index is valid
  }

  // ================================ INITIALISATION MANAGEMENT ================================

  pub fn init( self : *EntityManager, allocator : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing Entity manager" );

    if( self.isInit )
    {
      def.log( .WARN, 0, @src(), "Entity manager is already initialized", .{});
      return;
    }

    self.entities = std.ArrayList( Entity ).init( allocator  ); // Initialize the Entity manager by allocating memory for the list of entities
    self.maxID = 0;

    self.isInit = true;
    def.log( .INFO, 0, @src(), "Entity manager initialized", .{});

    return;
  }

  pub fn deinit( self : *EntityManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing Entity manager" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return;
    }

    self.entities.deinit(); // Deinitialize the Entity manager by deallocating memory for the list of entities
    self.maxID = 0;

    self.isInit = false;
    def.log( .INFO, 0, @src(), "Entity manager deinitialized", .{});
  }

  // ================================ ENTITY MANAGEMENT FUNCTIONS ================================

  pub fn addEntity( self : *EntityManager, newEntity : Entity ) ?*Entity
  {
    def.qlog( .TRACE, 0, @src(), "Adding new Entity" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return null; // If the Entity manager is not initialized, log a warning and return null
    }

    var tmp = newEntity;         // Create a temporary variable to hold the new Entity
    tmp.id  = self.getNewID();   // Assign a new ID to the Entity

    if( newEntity.id != 0 and newEntity.id != tmp.id )
    {
      def.log( .WARN, 0, @src(), "Dummy id ({d}) differs from given id ({d})", .{ newEntity.id, tmp.id });
    }

    self.entities.append( tmp ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to add Entity: {}", .{ err });
      return null; // If the Entity cannot be added, log an error and return null
    };

    // Return a pointer to the newly added Entity
    return &self.entities.items[ self.entities.items.len - 1 ];
  }

  pub fn createDefaultEntity( self : *EntityManager ) ?*Entity
  {
    def.qlog( .TRACE, 0, @src(), "Creating default Entity" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return null;
    }

    return self.addEntity( Entity{
      .pos    = def.newVecR( 0, 0, 0 ),
      .colour = def.newColour( 255, 255, 255, 255 ),
      .shape  = .RECT,
    });
  }

  pub fn getEntity( self : *EntityManager, id : u32 ) ?*Entity
  {
    def.log( .TRACE, 0, @src(), "Getting Entity with ID {d}", .{ id });

    // Find the index of the Entity with the given ID
    const index = self.getIndexOf( id ) orelse
    {
      def.log( .TRACE, 0, @src(), "Entity with ID {d} not found : returning null", .{ id });
      return null;
    };

    return &self.entities.items[ index ];
  }

  pub fn delEntity( self : *EntityManager, id : u32 ) void
  {
    // Find the index of the Entity with the given ID
    const index = self.getIndexOf( id );

    if( index == null )
    {
      def.log( .WARN, 0, @src(), "Entity with ID {d} not found : returning", .{ id });
      return;
    }

    _ = self.entities.swapRemove( index );
    def.log( .DEBUG, 0, @src(), "Entity with ID {d} deleted", .{ id });
  }

  pub fn deleteAllMarkedEntities( self : *EntityManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deleting all Entities marked for deletion" );

    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return;
    }

    // Iterate through all entities and delete those marked for deletion via the .DELETE flag
    for( self.entities.items, 0.. )| e, index |
    {
      if( index >= self.entities.items.len ){ break; }
      if( e.canBeDel() ){ _ = self.entities.swapRemove( index ); }
    }

    self.recalcMaxID();
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderActiveEntities( self : *EntityManager ) void // TODO : have this take in a renderer construct and pass it to Entity.renderGraphics()
  {
    def.qlog( .TRACE, 0, @src(), "Rendering active Entities" );

    // Iterate through all entities and render them if they are active
    for( self.entities.items )| *e |{ if( e.isActive() )
    {
      e.renderSelf();
    }}
  }

  // ================================ TICK FUNCTIONS ================================

  pub fn tickActiveEntities( self : *EntityManager, sdt : f32 ) void
  {
    for( self.entities.items )| *e |{ if( e.isActive() )
    {
      e.moveSelf( sdt );
    }}
  }

  pub fn collideActiveEntities( self : *EntityManager, sdt : f32 ) void
  {
    _ = sdt; // Prevent unused variable warning

    // Iterate through all entities and check for collisions if they are active
    for( self.entities.items, 0 .. )| *e1, index |{ if( e1.isActive() ) // Using index rather than id, since there is no guarantee that the id will always be index + 1
    {
      if( index + 1 >= self.entities.items.len ){ continue; } // Prevents out of bounds access

      // Iterate through all remaining entities ( those following the current one in the list ) to check for collisions
      for( self.entities.items[ index + 1 .. ])| e2 |{ if( e2.isActive() )
      {
        const overlap = e1.getOverlap( &e2 ) orelse continue; // TODO : swap this will "collideTogether( e1, e2 )" when implemented
        {
          def.log( .DEBUG, 0, @src(), "Collision detected between Entity {d} and {d} with magnitude {d}:{d}", .{ e1.id, e2.id, overlap.x, overlap.y });
          def.log( .DEBUG, 0, @src(), "Entity {d} position: {d}:{d}, Entity {d} position: {d}:{d}", .{ e1.id, e1.pos.x, e1.pos.y, e2.id, e2.pos.x, e2.pos.y });
          def.log( .DEBUG, 0, @src(), "Entity {d} scale:    {d}:{d}, Entity {d} scale:    {d}:{d}", .{ e1.id, e1.scale.x, e1.scale.y, e2.id, e2.scale.x, e2.scale.y });
        }
      }}
    }}
  }
};