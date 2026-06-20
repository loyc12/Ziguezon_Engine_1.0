const std = @import( "std" );
const utl = @import( "utils" );


/// Builds storage for registered archetype declarations.
/// The manager owns only declaration copies; game-owned payload data stays with games.
pub fn ArchetypeManagerFactory( comptime ArchetypeType : type ) type
{
  return struct
  {
    const ArchetypeManager = @This();

    alloc      : std.mem.Allocator                 = undefined,
    archetypes : std.StringHashMap( ArchetypeType ) = undefined,

    isInit : bool = false,


    // ================================ LIFECYCLE FUNCTIONS ================================

    /// Initializes the archetype declaration registry.
    pub fn init( self : *ArchetypeManager, alloc : std.mem.Allocator ) void
    {
      if( self.isInit )
      {
        utl.qlog( .WARN, @src(), "ArchetypeManager is already initialized : returning" );
        return;
      }

      self.alloc      = alloc;
      self.archetypes = .init( alloc );
      self.isInit     = true;
    }

    /// Releases registered archetype declarations.
    pub fn deinit( self : *ArchetypeManager ) void
    {
      if( !self.isInit )
      {
        utl.qlog( .WARN, @src(), "ArchetypeManager is uninitialized : returning" );
        return;
      }

      self.archetypes.deinit();
      self.isInit = false;
    }


    // ================================ REGISTRATION FUNCTIONS ================================

    /// Registers one data-only archetype declaration by name.
    /// Duplicate names are rejected so spawn lookups stay deterministic.
    pub fn register( self : *ArchetypeManager, archetype : ArchetypeType ) bool
    {
      if( !self.isInit )
      {
        utl.qlog( .WARN, @src(), "Cannot register Archetype : ArchetypeManager is uninitialized" );
        return false;
      }
      if( archetype.name.len == 0 )
      {
        utl.qlog( .WARN, @src(), "Cannot register Archetype : name is empty" );
        return false;
      }
      if( self.archetypes.contains( archetype.name ))
      {
        utl.log( .WARN, @src(), "Cannot register Archetype {s} : name already registered", .{ archetype.name });
        return false;
      }

      self.archetypes.put( archetype.name, archetype ) catch
      {
        utl.log( .ERROR, @src(), "Failed to register Archetype {s}", .{ archetype.name });
        return false;
      };

      return true;
    }

    /// Returns a registered archetype declaration by name.
    pub fn get( self : *ArchetypeManager, name : []const u8 ) ?*const ArchetypeType
    {
      if( !self.isInit )
      {
        utl.qlog( .WARN, @src(), "Cannot get Archetype : ArchetypeManager is uninitialized" );
        return null;
      }

      return self.archetypes.getPtr( name );
    }

    /// Returns the number of registered archetype declarations.
    pub inline fn getCount( self : *const ArchetypeManager ) usize
    {
      if( !self.isInit ){ return 0; }
      return self.archetypes.count();
    }
  };
}
