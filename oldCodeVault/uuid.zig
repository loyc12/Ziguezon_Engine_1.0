const std = @import( "std" );
const def = @import( "defs" );


// ================================ DEFINITIONS ================================

const flagBits = 0xFFF00000; // 12 bits for the flags themselves ( 0 to 4095 )
const idBits   = 0x000FFFFF; // 20 bits for the ID itself ( 1 to 1048575 )
const idSize   = @sizeOf( u20 );

const flagType = enum( u12 )
{
  FREE    = 0b100000000000, // Whether this UUID is free to be reused
  DELETE  = 0b010000000000, // Whether this UUID is marked for deletion

//DEBUG   = 0b001000000000, // Whether this UUID has debug information ( for debugging purposes )
  ACTIVE  = 0b000100000000, // Whether this UUID is active at all ( overrides the subsequent flags )

  MOBILE  = 0b000010000000, // Whether this UUID is movable       ( has transform component )
  COLLIDE = 0b000001000000, // Whether this UUID is collidable    ( has collision component )
//TRIGGER = 0b000000100000, // Whether this UUID is triggerable   ( has trigger component )

  RENDER  = 0b000000010000, // Whether this UUID is renderable    ( has render component )
//ANIMATE = 0b000000001000, // Whether this UUID is animated      ( has animation component )
//AUDIO   = 0b000000000100, // Whether this UUID is audible       ( has audio component )

//EVENT   = 0b000000000010, // Whether this UUID is eventful      ( has event component )
//AI      = 0b000000000001, // Whether this UUID is AI controlled ( has AI component )

  NONE    = 0x000, // No flags enabled
  ALL     = 0xFFF, // All flags enabled
};

var MIN_ID : u20 = 1; // The minimum ID value ( 0 is reserved for "no ID" )
var MAX_ID : u20 = @as( u20, idBits ); // The maximum ID value ( 1048575 )

var TOP_ID : u20 = 0; // The top ID value ( used to generate new IDs )

// ================================ UUID REUSE FUNCTIONS ================================

var isAvailabilityInit : bool = false;                      // Whether the freed IDs list has been initialized
var availableUUIDs     : std.ArrayList( Uuid ) = undefined; // A list of freed IDs ( used to reuse IDs )

pub fn initAvailableUUIDs( allocator : std.mem.Allocator ) void
{
  if( isAvailabilityInit )
  {
    def.qlog( .WARN, 0, @src(), "Freed IDs list is already initialized" );
    return;
  }

  availableUUIDs = std.ArrayList( Uuid ).init( allocator );
  isAvailabilityInit = true;
  def.qlog( .DEBUG, 0, @src(), "Initialized freed IDs list" );
}

pub fn deinitAvailableUUIDs() void
{
  if( !isAvailabilityInit )
  {
    def.qlog( .WARN, 0, @src(), "Freed IDs list is not initialized" );
    return;
  }

  availableUUIDs.deinit();
  isAvailabilityInit = false;
  def.qlog( .DEBUG, 0, @src(), "Deinitialized freed IDs list" );
}


// ================================ UUID STRUCT ================================

inline fn convFlagToU32( flag : flagType ) u32 { return @as( u32, @intFromEnum( flag )) << idSize; }

pub const Uuid = struct
{
  // This value stores both the ID itself ( bottom 20 bits ) and its associated flags ( top 12 bits )
  value : u32 = 0, // NOTE : ID 0 is reserved for "no ID"

  // ================ METHODS ================

  pub inline fn override( self : *Uuid, other : Uuid ) void { self.value = other.value; }

  pub inline fn getId(       self : *const Uuid ) u20 { return @as( u20, self.value & idBits   ); }
  pub inline fn getAllFlags( self : *const Uuid ) u12 { return @as( u12, ( self.value & flagBits ) >> idSize ); }
  pub inline fn getFlag(     self : *const Uuid, flag : flagType ) bool { return( self.value & convFlagToU32( flag ) != 0 ); }

  pub inline fn activateFlag(   self : *Uuid, flag : flagType  ) void { self.value |=  convFlagToU32( flag ); }
  pub inline fn deactivateFlag( self : *Uuid, flag : flagType  ) void { self.value &= ~convFlagToU32( flag ); }

  pub inline fn setAllFlags( self : *Uuid, flags : u12 ) void
  {
    self.value = ( self.value & ~flagBits ) | @as( u32, flags ) << idSize;
  }
  pub inline fn setFlag( self : *Uuid, flag : flagType , value : bool ) void
  {
    if( value ) { self.activateFlag( flag ); }
    else {        self.deactivateFlag( flag ); }
  }

  pub fn setId( self : *Uuid, id : u20 ) void
  {
    if( id == 0 )
    {
      def.qlog( .WARN, 0, @src(), "setting an ID to zero ( aka no value )" );
    }
    self.value = @as( u32, id ) | ( self.value & flagBits ); // Keep the flags intact
  }

  pub inline fn isFree(    self : *const Uuid ) bool { return self.getFlag( .FREE   ); }
  pub inline fn willFree(  self : *const Uuid ) bool { return self.getFlag( .DELETE ); }

//pub inline fn isDebug(   self : *const Uuid ) bool { return self.getFlag( .DEBUG  ); }
  pub inline fn isActive(  self : *const Uuid ) bool { return( !self.isFree() and !self.willFree() and self.getFlag( .ACTIVE )); }

  pub inline fn isMobile(  self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .MOBILE  )); }
  pub inline fn isCollide( self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .COLLIDE )); }
//pub inline fn isTrigger( self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .TRIGGER )); }

  pub inline fn isRender(  self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .RENDER  )); }
//pub inline fn isAnimate( self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .ANIMATE )); }
//pub inline fn isAudio(   self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .AUDIO   )); }

//pub inline fn isEvent(   self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .EVENT )); }
//pub inline fn isAI(      self : *const Uuid ) bool { return( self.isActive() and self.getFlag( .AI    )); }


  // ================ INIT FUNCTIONS ================

  pub inline fn initEmpty()                   Uuid { return .{ .value = 0 }; }
  pub inline fn init( id : u20, flags : u12 ) Uuid { return .{ .value = @as( u32, id ) | ( @as( u32, flags ) << idSize )}; }

  // ================ DELETION FUNCTIONS ================

  // fn addAvailableUUID( toAdd : Uuid ) void
  // prevent duplicates or invalid IDs from being added

  //pub fn sortAvailableUUIDs() void {}
  // Sort the list by ID

  //pub fn compactAvailableUUIDs() void {}
  // Remove IDs that are not marked for deletion
  // Remove IDs that are continuously bellow the current MAX_ID, and lower the MAX_ID accordingly

  pub fn markUUIDForDeletion( toDelete : *Uuid ) void
  {
    if( toDelete == null )
    {
      def.qlog( .WARN, 0, @src(), "Attempting to mark a null UUID for deletion" );
      return;
    }

    const id = toDelete.getId();
    if( id == 0 )
    {
      def.qlog( .WARN, 0, @src(), "Marking UUID with ID 0 ( reserved for no ID ) for deletion" );
    }

    if( !isAvailabilityInit )
    {
      def.qlog( .WARN, 0, @src(), "Freed IDs list is not initialized. Deleted ID will not be tracked or reused" );
    }

    def.log( .DEBUG, 0, @src(), "Marking UUID {d} for deletion", .{ id });

    toDelete.activateFlag(   .DELETE ); // Activate the DELETE flag
    toDelete.deactivateFlag( .ACTIVE ); // Deactivate the ACTIVE flag
  }

  pub fn freeUUID( toFree : *Uuid ) void
  {
    if( toFree == null )
    {
      def.qlog( .WARN, 0, @src(), "Attempting to free a null UUID" );
      return;
    }

    const id = toFree.getId();
    if( id == 0 )
    {
      def.qlog( .WARN, 0, @src(), "Freeing a UUID with ID 0 ( reserved for no ID )" );
    }
    if( !isAvailabilityInit )
    {
      def.log( .WARN, 0, @src(), "AvailableUUIDs list is not initialized. AvailableUUID with ID {d} will not be tracked or reused", .{ id });
    }
    if( !toFree.willFree() )
    {
      def.log( .WARN, 0, @src(), "Freeing UUID with ID {d} that was not properly marked for deletion beforehand", .{ id });
    }

    def.log( .DEBUG, 0, @src(), "Freeing UUID {d}", .{ id });

    toFree.activateFlag(   .FREE );   // Activate the FREE flag
    toFree.deactivateFlag( .DELETE ); // Deactivate the DELETE flag

    if( isAvailabilityInit )
    {
      availableUUIDs.append( *toFree ) catch | err | // TODO : use addAvailableUUID instead
      {
        def.log( .ERROR, 0, @src(), "Error appending freed UUID {d} to the list: {}", .{ id, err });
        return;
      };
      def.qlog( .DEBUG, 0, @src(), "UUID {d} has been freed and added to the list of freed IDs", .{ id });
    }
  }


  // ================ CREATION / REUSE FUNCTIONS ================

  inline fn hasIDsToReuse() bool
  {
    if( !isAvailabilityInit )
    {
      def.qlog( .WARN, 0, @src(), "Freed IDs list is not initialized" );
      return false;
    }
    return availableUUIDs.items.len > 0;
  }

  inline fn reuseUUID( flags : u12 ) ?Uuid
  {
    def.qlog( .TRACE, 0, @src(), "Reusing an old UUID..." );

    if( !isAvailabilityInit )
    {
      def.qlog( .WARN, 0, @src(), "Freed IDs list is not initialized" );
      return null;
    }

    if( availableUUIDs.items.len > 0 )
    {
      if( availableUUIDs.pop() )| old |
      {
        old.setAllFlags( flags ); // Reset its flags to ACTIVE only
        def.qlog( .DEBUG, 0, @src(), "Reusing old UUID {d}", .{ old.getId() });
        return old;
      }
      def.qlog( .ERROR, 0, @src(), "Failed to pop an old UUID from the list" );
    }
    return null;
  }

  inline fn createNewUUID( flags : u12 ) ?Uuid
  {
    def.qlog( .TRACE, 0, @src(), "Creating a new UUID..." );

    if( TOP_ID >= MAX_ID - 1 )
    {
      def.log( .ERROR, 0, @src(), "! Reached maximum UUID ID value. What have you done, bozo ! ", .{ MAX_ID });
      return null;
    } // If we reached the maximum ID, we can't create a new one

    TOP_ID += 1;
    return Uuid.init( TOP_ID, flags );
  }

  pub fn getNewUUID( flags : u12 ) ?Uuid
  {
    def.qlog( .TRACE, 0, @src(), "Generating a UUID..." );

    if( hasIDsToReuse( flags ))
    {
      if( reuseUUID())| old |
      {
        def.qlog( .DEBUG, 0, @src(), "Reusing old UUID {d}", .{ old.getId() });
        return old;
      }
      def.qlog( .WARN, 0, @src(), "Error reusing UUID, falling back to generating a new one instead" );
    }

    if( createNewUUID( flags ))| new |
    {
      def.qlog( .DEBUG, 0, @src(), "Creating new UUID {d}", .{ new.getId() });
      return new;
    }

    def.qlog( .ERROR, 0, @src(), "Unable to create a new UUID" );
    return null;
  }
};






