const std = @import( "std" );
const h   = @import( "defs" );

pub const entityManager = struct
{
  isInit   : bool = false, // Flag to check if the entity manager is initialized
  maxID    : u32 = 0,      // Global variable to keep track of the maximum ID assigned
  entities : std.ArrayList( h.ntt.entity ) = undefined, // List to store all entities

  // ================================ HELPER FUNCTIONS ================================

  // ================ ID PROPERTIES ================

  pub fn getNewID( self : *entityManager ) u32
  {
    if( !self.isInit )
    {
      h.log( .ERROR, 0, @src(), "Entity manager is not initialized : returning id 0", .{});
      return 0;
    }

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
    if( id <= 0 )
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

  fn getIndexOf( self : *entityManager, id : u32 ) ?usize
  {
    if( !self.isInit )
    {
      h.log( .ERROR, 0, @src(), "Entity manager is not initialized : returning null", .{});
      return null; // If the entity manager is not initialized, log a warning and return null
    }

    if( !self.isIdValid( id )) // Check if the ID is valid
    {
      h.log( .WARN, 0, @src(), "Entity ID {d} is not valid", .{ id });
      return null; // If the ID is not valid, log a warning and return null
    }

    // Find the index of the entity with the given ID
    for( self.entities.items, 0.. )| entity, index |
    {
      // return the index of the first ( and normally only ) entity with the given ID
      if( entity.id == id ){ return index; }
    }

    h.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ id });
    return null; // If the entity is not found, log a warning and return null
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
    if( index >= self.entities.items.len ) // If the index is out of bounds, return false
    {
      h.log( .WARN, 0, @src(), "Index {d} is out of bounds ( 0 to {d} )", .{ index, self.entities.len });
      return false; // Index cannot be greater than or equal to the length of entities
    }
    return true; // Index is valid
  }

  // ================================ ENTITY MANAGEMENT ================================

  pub fn init( self : *entityManager, allocator : std.mem.Allocator ) void
  {
    h.qlog( .TRACE, 0, @src(), "Initializing entity manager" );

    if( self.isInit )
    {
      h.log( .WARN, 0, @src(), "Entity manager is already initialized", .{});
      return;
    }

    self.entities = std.ArrayList( h.ntt.entity ).init( allocator  ); // Initialize the entity manager by allocating memory for the list of entities
    self.maxID = 0;

    self.isInit = true;
    h.log( .INFO, 0, @src(), "Entity manager initialized", .{});

    return;
  }

  pub fn deinit( self : *entityManager ) void
  {
    h.qlog( .TRACE, 0, @src(), "Deinitializing entity manager" );

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

  pub fn addEntity( self : *entityManager, newEntity : h.ntt.entity ) ?*h.ntt.entity
  {
    h.qlog( .TRACE, 0, @src(), "Adding new entity" );

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

    // Return a pointer to the newly added entity
    return &self.entities.items[ self.entities.items.len - 1 ];
  }

    pub fn createDefaultEntity( self : *entityManager ) ?*h.ntt.entity
  {
    h.qlog( .TRACE, 0, @src(), "Creating default entity" );

    if( !self.isInit )
    {
      h.log( .WARN, 0, @src(), "Entity manager is not initialized", .{});
      return null; // If the entity manager is not initialized, log a warning and return null
    }

    return self.addEntity( h.ntt.entity{
      .id     = 0, // ID will be assigned by the entity manager
      .active = true,

      .pos    = h.vec2{ .x = 0.0, .y = 0.0 },
      .vel    = h.vec2{ .x = 0.0, .y = 0.0 },
      .acc    = h.vec2{ .x = 0.0, .y = 0.0 },

      .rotPos = 0.0,

      .shape  = h.ntt.e_shape.RECT,
      .scale  = h.vec2{ .x = 1.0, .y = 1.0 },
      .colour = h.ray.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    });
  }

  pub fn getEntity( self : *entityManager, id : u32 ) ?*h.ntt.entity
  {
    h.log( .TRACE, 0, @src(), "Getting entity with ID {d}", .{ id });

    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id ) orelse
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    };

    return &self.entities.items[ index ];
  }

  pub fn delEntity( self : *entityManager, id : u32 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );

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
    const index = self.getIndexOf( id );
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
    const index = self.getIndexOf( id );
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
    const index = self.getIndexOf( id );
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
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].pos;
  }

  pub fn setVelocity( self : *entityManager, id : u32, velocity : h.vec2 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found, log a warning and return
    }
    self.entities[ index ].vel = velocity;
  }
  pub fn getVelocity( self : *entityManager, id : u32 ) ?h.vec2
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].vel;
  }

  pub fn setAcceleration( self : *entityManager, id : u32, acceleration : h.vec2 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found, log a warning and return
    }
    self.entities[ index ].acc = acceleration;
  }
  pub fn getAcceleration( self : *entityManager, id : u32 ) ?h.vec2
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].acc;
  }

  // ================ ROTATION PROPERTIES ================

  pub fn setRotation( self : *entityManager, id : u32, rotation : f16 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
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
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].rotPos;
  }

  // ================ SHAPE PROPERTIES ================

  pub fn setShape( self : *entityManager, id : u32, shape : h.ntt.e_shape ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }
    self.entities[ index ].shape = shape;
  }
  pub fn getShape( self : *entityManager, id : u32 ) ?h.ntt.e_shape
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
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
    const index = self.getIndexOf( id );
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
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return null; // If the entity is not found, log a warning and return null
    }
    return self.entities[ index ].scale;
  }

  pub fn setColour( self : *entityManager, id : u32, colour : h.ray.Color ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }
    self.entities[ index ].colour = colour;
  }
  pub fn getColour( self : *entityManager, id : u32 ) ?h.ray.Color
  {
    // Find the index of the entity with the given ID
    const index = self.getIndexOf( id );
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
    for( self.entities.items )| entity |{ entity.renderSelf(); }
  }

  // ================================ TICK FUNCTIONS ================================

  pub fn tickActiveEntities( self : *entityManager, sdt : f32 ) void
  {
    // Iterate through all entities and tick them if they are active
    for( self.entities.items, 0 .. )| entity, index |
    {
      if( entity.active )
      {
        var e = &self.entities.items[ index ]; // Get a mutable reference to the entity

        // Apply the entity's accelerations to its velocities
        e.vel.x += e.acc.x * sdt;
        e.vel.y += e.acc.y * sdt;

        // Apply the entity's velocities to its positions
        e.pos.x += e.vel.x * sdt;
        e.pos.y += e.vel.y * sdt;

        // Reset the entity's accelerations to zero after applying them
        e.acc.x = 0;
        e.acc.y = 0;
      }
    }
    //self.collideActiveEntities( sdt );
  }

  pub fn collideActiveEntities( self : *entityManager, sdt : f32 ) void
  {
    _ = sdt; // Prevent unused variable warning // TODO : use sdt in collision detection

    // Iterate through all entities and check for collisions if they are active
    for( self.entities.items, 0 .. )| entity, index |{ if( entity.active ) // Using index rather than id, since there is no guarantee that the id will always be index + 1
    {
      // If the index is the last entity, skip to the next iteration
      if( index + 1 >= self.entities.items.len ){ continue; } // Prevents out of bounds access

      // Iterate through all remaining entities ( those following the current one in the list ) to check for collisions
      for( self.entities.items[ index + 1 .. ])| otherEntity |
      {
         // Check for collision between the two entities
        if( otherEntity.active )
        {
          // Get the overlap vector between the two entities, or continue if there is no overlap
          const overlap = entity.getOverlap( &otherEntity ) orelse continue; // TODO : swap this will "collideTogether( e1, e2 )" when implemented
          {
            h.log( .DEBUG, 0, @src(), "Collision detected between entity {d} and {d} with magnitude {d}:{d}", .{ entity.id, otherEntity.id, overlap.x, overlap.y });
            h.log( .DEBUG, 0, @src(), "Entity {d} position: {d}:{d}, Entity {d} position: {d}:{d}", .{ entity.id, entity.pos.x, entity.pos.y, otherEntity.id, otherEntity.pos.x, otherEntity.pos.y });
            h.log( .DEBUG, 0, @src(), "Entity {d} scale:    {d}:{d}, Entity {d} scale:    {d}:{d}", .{ entity.id, entity.scale.x, entity.scale.y, otherEntity.id, otherEntity.scale.x, otherEntity.scale.y });
          }
        } // TODO : implement and replace with collideWith()
      }
    }}
  }
};