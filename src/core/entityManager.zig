const std = @import( "std" );
const h   = @import( "../headers.zig" );
const ntt = @import( "entity.zig" );

pub const entityManager = struct
{
  isInit : bool = false, // Flag to check if the entity manager is initialized
  maxID  : u32 = 0,      // Global variable to keep track of the maximum ID assigned

  entities : std.ArrayList( ntt.entity ) = undefined, // List to store all entities

  // ================================ HELPER FUNCTIONS ================================

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

  pub fn getNewEnitity( self : *entityManager, position : ?h.vec2 ) ntt.entity
  {
    const pos = if( position )| p | p else h.vec2{ 0, 0 }; // Default to ( 0, 0 ) if no position is provided

    const newEntity = ntt.entity// Create a new entity with a unique ID, active status, and position
    {
      .id = self.getNewID(),
      .active = true,
      .position = pos,
    };

    self.entities.append( newEntity ); // Append the new entity to the list of entities
    return newEntity;                  // Return the newly created entity
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

    return self.entities[ index ]; // Return the entity at the found index
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

    // Remove the entity at the found index from the list of entities
    self.entities.removeAt( index );
    h.log( .INFO, 0, @src(), "Entity with ID {d} deleted", .{ id });
  }

  // ================================ ACCESSORS ================================
  pub fn setActivity( self : *entityManager, id : u32, active : bool ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }

    self.entities[ index ].active = active; // Set the activity status of the entity at the found index
  }

  pub fn setPosition( self : *entityManager, id : u32, position : h.vec2 ) void
  {
    // Find the index of the entity with the given ID
    const index = self.getIndex( id );
    if( index == null )
    {
      h.log( .WARN, 0, @src(), "Entity with ID {d} not found : passing", .{ id });
      return; // If the entity is not found
    }

    self.entities[ index ].position = position; // Set the position of the entity at the found index
  }
};