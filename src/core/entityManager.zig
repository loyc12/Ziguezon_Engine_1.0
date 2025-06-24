const std = @import( "std" );
const h   = @import( "../headers.zig" );
const ntt = @import( "entity.zig" );

pub const entityManager = struct
{
  isInit : bool = false, // Flag to check if the entity manager is initialized
  maxID  : u32 = 0,      // Global variable to keep track of the maximum ID assigned

  entities : std.ArrayList( ntt.entity ) = undefined, // List to store all entities

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID PROPERTIES ================

  pub fn getNewID( self : *entityManager ) u32
  {
    // Increment the global maxID and return it as the new ID
    self.maxID += 1;
    return self.maxID;
  }

  pub fn getMaxID( self : *entityManager ) u32
  {
    // Return the current maximum ID assigned
    return self.maxID;
  }

  pub fn isIdValid( self : *entityManager, id : u32 ) bool
  {
    if( id <= 0 ) // Check if the ID is 0
    {
      h.log( .WARN, 0, @src(), "Entity ID cannot be 0", .{});
      return false; // ID cannot be 0
    }
    if( id > self.maxID )
    {
      h.log( .WARN, 0, @src(), "Entity ID {d} is greater than maxID {d}", .{ id, self.maxID });
      return false; // ID cannot be greater than maxID
    }
    return true; // ID is valid
  }

  // ================ INDEX FUNCTIONS ================

  fn getIndex( self : *entityManager, id : u32 ) ?usize
  {
    // Find the index of the entity with the given ID
    const index = self.entities.indexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return index; // Return the index of the entity
  }

  fn isIndexValid( self : *entityManager, index : ?usize ) bool
  {
    // Check if the index is valid
    if( self.entities.len == 0 ) // If there are no entities, return false
    {
      h.log( .WARN, 0, @src(), "No entities available", .{});
      return false; // No entities to check against
    }
    if( index == null ) // If the index is null, return false
    {
      h.log( .WARN, 0, @src(), "Index is null", .{});
      return false; // Index cannot be null
    }
    if( index < 0 ) // If the index is negative, return false
    {
      h.log( .WARN, 0, @src(), "Index {d} is negative", .{ index });
      return false; // Index cannot be negative
    }
    if( index >= self.entities.len ) // If the index is out of bounds, return false
    {
      h.log( .WARN, 0, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.entities.len });
      return false; // Index cannot be greater than or equal to the length of entities
    }
    return true; // Index is valid
  }

  // ================================ ENTITY MANAGEMENT ================================

  pub fn init( self : *entityManager, allocator : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      h.log( .WARN, 0, @src(), "Entity manager is already initialized", .{});
      return;
    }

    self.entities = std.ArrayList( ntt.entity ).init( allocator  ); // Initialize the entity manager by allocating memory for the list of entities
    self.maxID = 0;

    self.isInit = true;
    h.log( .INFO, 0, @src(), "Entity manager initialized", .{});

    return;
  }

  pub fn deinit( self : *entityManager ) void
  {
    if( !self.isInit )
    {
      h.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return;
    }

    self.entities.deinit(); // Deinitialize the entity manager by deallocating memory for the list of entities
    self.maxID = 0;

    self.isInit = false;
    h.log( .INFO, 0, @src(), "Entity manager deinitialized", .{});
  }

  pub fn addEntity( self : *entityManager, newEntity : ntt.entity ) ?ntt.entity
  {

    if( !self.isInit )
    {
      h.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return null; // If the entity manager is not initialized, log a warning and return null
    }

    var tmp = newEntity; // Create a temporary variable to hold the new entity
    tmp.id  = self.getNewID(); // Assign a new ID to the entity

    self.entities.append( tmp ) catch | err |
    {
      h.log( .ERROR, 0, @src(), "Failed to add entity: {}", .{ err });
      return null; // If the entity cannot be added, log an error and return null
    };

    return newEntity;
  }

  pub fn getEntity( self : *entityManager, id : u32 ) ?ntt.entity
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );

    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ];
  }

  pub fn delEntity( self : *entityManager, id : u32 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );

    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found, log a warning and return
    }
    self.entities.removeAt( index );
    h.log( .INFO, 0, @src(), "Entity with ID {d} deleted", .{ id });
  }

  // ================================ INDIVIDUAL ACCESSORS / MUTATORS ================================

  pub fn setActivity( self : *entityManager, id : u32, active : bool ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }
    self.entities[ index ].active = active;
  }
  pub fn isActive( self : *entityManager, id : u32 ) bool
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return false; // If the entity is not found, log a warning and return false
    }
    return self.entities[ index ].active;
  }

  // ================ POSITION PROPERTIES ================

  pub fn setPosition( self : *entityManager, id : u32, position : h.vec2 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found, log a warning and return
    }
    self.entities[ index ].pos = position;
  }
  pub fn getPosition( self : *entityManager, id : u32 ) ?h.vec2
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].pos;
  }

  // ================ ROTATION PROPERTIES ================

  pub fn setRotation( self : *entityManager, id : u32, rotation : f16 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found, log a warning and return
    }
    self.entities[ index ].rotPos = rotation;
  }
  pub fn getRotation( self : *entityManager, id : u32 ) ?f16
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].rotPos;
  }

  // ================ SHAPE PROPERTIES ================

  pub fn setShape( self : *entityManager, id : u32, shape : ntt.e_shape ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }
    self.entities[ index ].shape = shape;
  }
  pub fn getShape( self : *entityManager, id : u32 ) ?ntt.e_shape
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].shape;
  }

  pub fn setScale( self : *entityManager, id : u32, scale : h.vec2 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }
    self.entities[ index ].scale = scale;
  }
  pub fn getScale( self : *entityManager, id : u32 ) ?h.vec2
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].scale;
  }

  pub fn setColour( self : *entityManager, id : u32, colour : h.rl.Color ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }
    self.entities[ index ].colour = colour;
  }
  pub fn getColour( self : *entityManager, id : u32 ) ?h.rl.Color
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].colour;
  }

  // ================================ RENDER FUNCTIONS ================================

  pub fn renderActiveEntities( self : *entityManager ) void // TODO : have this take in a renderer construct and pass it to entity.render()
  {
    // Iterate through all entities and render them if they are active
    for( self.entities.items )| entity |{ if( entity.active ){ entity.renderSelf(); }}
  }
  pub fn collideActiveEntities( self : *entityManager ) void // TODO : have this take in a collider construct and pass it to entity.collide()
  {
    // Iterate through all entities and check for collisions if they are active
    for( self.entities.items )| entity |{ if( entity.active )
    {
      // Prevent segfaulting with the last entity in the list
      if( entity.id == self.maxID ){ continue; } // TODO : make sure maxID is always up to date

      // Iterate through all remaining entities ( those following the current one in the list ) to check for collisions
      for( self.entities.items[ entity.id + 1 .. ])| otherEntity |
      {
         // Check for collision between the two entities
        if( otherEntity.active )
        {
          const overlap = entity.getOverlap( &otherEntity ) orelse continue; // Get the overlap vector between the two entities, or continue if there is no overlap
          {
            h.log( .DEBUG, 0, @src(), "Collision detected between entity {d} and {d} with magnitude {d}:{d}", .{ entity.id, otherEntity.id, overlap.x, overlap.y });

          }
        } // TODO : implement and replace with collideWith()
      }
    }}
  }
};