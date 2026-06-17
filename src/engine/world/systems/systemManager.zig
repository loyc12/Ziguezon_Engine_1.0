const std = @import( "std" );
const utl = @import( "utils" );

const system   = @import( "system.zig" );
const query    = @import( "../queries/query.zig" );
const worldMgr = @import( "../worldManager.zig" );

const System        = system.System;
const SystemContext = system.SystemContext;
const EntityId      = @import( "../entity.zig" ).EntityId;
const World         = worldMgr.World;
const WorldQuery    = query.WorldQuery;


/// Small ordered registry for explicit simulation-system passes.
/// This does not schedule systems; callers choose when to run the manager.
pub const SystemManager = struct
{
  alloc   : std.mem.Allocator      = undefined,
  systems : std.ArrayList( System ) = .empty,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes system registry storage.
  pub fn init( self : *SystemManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "SystemManager is already initialized : returning" );
      return;
    }

    self.alloc   = alloc;
    self.systems = .empty;
    self.isInit  = true;
  }

  /// Releases registered system declarations.
  pub fn deinit( self : *SystemManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "SystemManager is uninitialized : returning" );
      return;
    }

    self.systems.deinit( self.alloc );
    self.systems = .empty;
    self.isInit  = false;
  }


  // ================================ REGISTRATION FUNCTIONS ================================

  /// Registers one named system and keeps lower `order` values earlier.
  pub fn register( self : *SystemManager, systemDef : System ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot register System : SystemManager is uninitialized" );
      return false;
    }
    if( systemDef.name.len == 0 )
    {
      utl.qlog( .WARN, @src(), "Cannot register System : name is empty" );
      return false;
    }
    if( self.hasSystem( systemDef.name ))
    {
      utl.log( .WARN, @src(), "Cannot register System {s} : name already registered", .{ systemDef.name });
      return false;
    }

    self.systems.append( self.alloc, systemDef ) catch
    {
      utl.log( .ERROR, @src(), "Failed to register System {s}", .{ systemDef.name });
      return false;
    };

    self.reorderLastSystem();
    return true;
  }

  /// Returns true when a system name is already registered.
  pub fn hasSystem( self : *const SystemManager, name : []const u8 ) bool
  {
    if( !self.isInit ){ return false; }

    for( self.systems.items )| systemDef |
    {
      if( std.mem.eql( u8, systemDef.name, name )){ return true; }
    }

    return false;
  }

  /// Returns the number of registered systems.
  pub inline fn getSystemCount( self : *const SystemManager ) usize
  {
    if( !self.isInit ){ return 0; }
    return self.systems.items.len;
  }


  // ================================ EXECUTION FUNCTIONS ================================

  /// Runs registered systems in order against one initialized World.
  /// Systems receive read-only query access and can enqueue commands.
  pub fn runAll( self : *SystemManager, world : *World ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot run Systems : SystemManager is uninitialized" );
      return false;
    }

    const worldQuery = WorldQuery.init( world ) orelse return false;

    var context : SystemContext =
    .{
      .query    = worldQuery,
      .commands = &world.commandManager,
    };

    for( self.systems.items )| *systemDef |
    {
      if( !systemDef.run( &context ))
      {
        utl.log( .WARN, @src(), "System {s} returned failure", .{ systemDef.name });
        return false;
      }
    }

    return true;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn reorderLastSystem( self : *SystemManager ) void
  {
    var idx = self.systems.items.len - 1;

    while( idx > 0 and self.systems.items[ idx - 1 ].order > self.systems.items[ idx ].order )
    {
      const tmp = self.systems.items[ idx - 1 ];
      self.systems.items[ idx - 1 ] = self.systems.items[ idx ];
      self.systems.items[ idx ] = tmp;
      idx -= 1;
    }
  }
};


// ================================ TESTS ================================

test "SystemManager registers systems in order"
{
  const Runner = struct
  {
    fn run( context : *SystemContext ) bool
    {
      _ = context;
      return true;
    }
  };

  var manager : SystemManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "late",  .order = 20, .runFn = Runner.run }));
  try std.testing.expect( manager.register( .{ .name = "early", .order = 10, .runFn = Runner.run }));
  try std.testing.expect( !manager.register( .{ .name = "early", .order = 30, .runFn = Runner.run }));

  try std.testing.expect( manager.getSystemCount() == 2 );
  try std.testing.expect( std.mem.eql( u8, manager.systems.items[ 0 ].name, "early" ));
  try std.testing.expect( std.mem.eql( u8, manager.systems.items[ 1 ].name, "late"  ));
}

test "SystemManager runs systems with query and command emission"
{
  const TestComp = struct
  {
    pub const compStorePolicy : @import( "../components/component.zig" ).CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const TestCommand = struct
  {
    entityId : EntityId = 0,
    value    : u32 = 0,
  };

  const Runner = struct
  {
    var entityId : EntityId = 0;

    fn run( context : *SystemContext ) bool
    {
      const comp = context.query.getComp( TestComp, entityId ) orelse return false;
      return context.enqueueCommand( TestCommand, .{ .entityId = entityId, .value = comp.value + 1 });
    }
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp(    TestComp ));
  try std.testing.expect( world.registerCommand( TestCommand ));

  Runner.entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( TestComp, Runner.entityId, .{ .value = 41 }));

  var manager : SystemManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "reader", .runFn = Runner.run }));
  try std.testing.expect( manager.runAll( &world ));

  const record = world.popCommand( TestCommand ).?;
  try std.testing.expect( record.value.entityId == Runner.entityId );
  try std.testing.expect( record.value.value    == 42 );
}

test "SystemManager rejects uninitialized use and uninitialized worlds"
{
  const Runner = struct
  {
    fn run( context : *SystemContext ) bool
    {
      _ = context;
      return true;
    }
  };

  var manager : SystemManager = .{};
  var world   : World         = .{};

  try std.testing.expect( !manager.register( .{ .name = "reader", .runFn = Runner.run }));
  try std.testing.expect( !manager.runAll( &world ));

  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "reader", .runFn = Runner.run }));
  try std.testing.expect( !manager.runAll( &world ));
}
