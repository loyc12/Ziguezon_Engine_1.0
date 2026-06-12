const std = @import( "std" );
const utl = @import( "utils" );

const Mouse       = utl.Mouse;
const MouseButton = utl.MouseButton;
const Panel       = utl.Panel;


// ================================ PANEL HANDLES ================================

/// Generation-checked runtime identity for a panel registration in `UiManager`.
/// The handle identifies the registration, not ownership of the `Panel`.
pub const UiPanelHandle = struct
{
  pub const invalidIndex : u32 = std.math.maxInt( u32 );

  idx : u32 = invalidIndex,
  gen : u32 = 0,

  pub inline fn none() UiPanelHandle { return .{}; }
  pub inline fn fromIndexGen( idx : u32, gen : u32 ) UiPanelHandle { return .{ .idx = idx, .gen = gen }; }

  pub inline fn isValid( self : UiPanelHandle ) bool { return self.idx < invalidIndex; }

  pub inline fn isEq( self : UiPanelHandle, other : UiPanelHandle ) bool
  {
    return self.idx == other.idx and self.gen == other.gen;
  }
};


// ================================ REGISTRATION ================================

/// Engine-side routing metadata for one game-owned panel.
pub const UiPanelConfig = struct
{
  key            : u64  = 0,
  layer          : i32  = 0,
  z              : i32  = 0,
  isVisible      : bool = true,
  isInputEnabled : bool = true,
  isDrawEnabled  : bool = true,
};

pub const UiPanelRegistration = struct
{
  key            : u64           = 0,
  handle         : UiPanelHandle = .{},
  gen            : u32           = 0,
  order          : u64           = 0,
  panel          : ?*Panel       = null,
  layer          : i32           = 0,
  z              : i32           = 0,
  isVisible      : bool          = true,
  isInputEnabled : bool          = true,
  isDrawEnabled  : bool          = true,
  isAlive        : bool          = false,
};

/// Event forwarded from a registered panel's local event queue.
pub const UiManagerEvent = struct
{
  panel : UiPanelHandle = .{},
  event : utl.UiEvent   = .{},
};


// ================================ MANAGER ================================

/// Minimal engine-side orchestrator for game-owned `Panel` primitives. It owns
/// registration metadata and forwarded events, while games still own panels.
pub const UiManager = struct
{
  alloc : std.mem.Allocator = undefined,

  panels : std.ArrayList( UiPanelRegistration ) = .empty,
  events : std.ArrayList( UiManagerEvent      ) = .empty,

  hoveredPanel  : UiPanelHandle = .{},
  capturedPanel : [ MouseButton.count ]UiPanelHandle = [_]UiPanelHandle{ .{} } ** MouseButton.count,

  nextOrder : u64  = 1,
  isInit    : bool = false,


  // ================================ LIFETIME ================================

  pub fn init( self : *UiManager, alloc : std.mem.Allocator ) void
  {
    self.* = .{
      .alloc  = alloc,
      .isInit = true,
    };
  }

  pub fn deinit( self : *UiManager ) void
  {
    if( !self.isInit ){ return; }

    self.events.deinit( self.alloc );
    self.panels.deinit( self.alloc );

    self.* = .{};
  }

  pub fn clear( self : *UiManager ) void
  {
    if( !self.isInit ){ return; }

    self.events.clearRetainingCapacity();
    self.panels.clearRetainingCapacity();
    self.hoveredPanel = .{};
    self.capturedPanel = [_]UiPanelHandle{ .{} } ** MouseButton.count;
    self.nextOrder = 1;
  }


  // ================================ REGISTRATION ================================

  /// Registers a game-owned panel pointer. The caller must keep the panel alive
  /// until it is unregistered or the manager is cleared/deinitialized.
  pub fn registerPanel( self : *UiManager, panel : *Panel, config : UiPanelConfig ) !UiPanelHandle
  {
    if( !self.isInit ){ return error.UiManagerNotInitialized; }

    for( self.panels.items, 0.. )| *slot, i |
    {
      if( slot.isAlive ){ continue; }

      var gen = slot.gen +% 1;
      if( gen == 0 ){ gen = 1; }

      const handle = UiPanelHandle.fromIndexGen( @intCast( i ), gen );
      slot.* = self.makeRegistration( handle, panel, config, gen );
      return handle;
    }

    if( self.panels.items.len >= @as( usize, UiPanelHandle.invalidIndex ))
    {
      return error.UiPanelLimitReached;
    }

    const handle = UiPanelHandle.fromIndexGen( @intCast( self.panels.items.len ), 1 );
    try self.panels.append( self.alloc, self.makeRegistration( handle, panel, config, 1 ) );
    return handle;
  }

  fn makeRegistration( self : *UiManager, handle : UiPanelHandle, panel : *Panel, config : UiPanelConfig, gen : u32 ) UiPanelRegistration
  {
    const order = self.nextOrder;
    self.nextOrder +%= 1;
    if( self.nextOrder == 0 ){ self.nextOrder = 1; }

    return .{
      .key            = config.key,
      .handle         = handle,
      .gen            = gen,
      .order          = order,
      .panel          = panel,
      .layer          = config.layer,
      .z              = config.z,
      .isVisible      = config.isVisible,
      .isInputEnabled = config.isInputEnabled,
      .isDrawEnabled  = config.isDrawEnabled,
      .isAlive        = true,
    };
  }

  pub fn unregisterPanel( self : *UiManager, handle : UiPanelHandle ) bool
  {
    const reg = self.getRegistrationPtr( handle ) orelse return false;

    reg.isAlive = false;
    reg.panel   = null;

    if( self.hoveredPanel.isEq( handle )){ self.hoveredPanel = .{}; }

    for( &self.capturedPanel )| *captured |
    {
      if( captured.isEq( handle )){ captured.* = .{}; }
    }

    return true;
  }


  // ================================ LOOKUP ================================

  pub fn getRegistrationPtr( self : *UiManager, handle : UiPanelHandle ) ?*UiPanelRegistration
  {
    if( !handle.isValid() ){ return null; }

    const idx : usize = @intCast( handle.idx );
    if( idx >= self.panels.items.len ){ return null; }

    const reg = &self.panels.items[ idx ];
    if( !reg.isAlive or reg.gen != handle.gen ){ return null; }

    return reg;
  }

  pub fn getRegistration( self : *const UiManager, handle : UiPanelHandle ) ?*const UiPanelRegistration
  {
    if( !handle.isValid() ){ return null; }

    const idx : usize = @intCast( handle.idx );
    if( idx >= self.panels.items.len ){ return null; }

    const reg = &self.panels.items[ idx ];
    if( !reg.isAlive or reg.gen != handle.gen ){ return null; }

    return reg;
  }

  pub fn getPanelPtr( self : *UiManager, handle : UiPanelHandle ) ?*Panel
  {
    const reg = self.getRegistrationPtr( handle ) orelse return null;
    return reg.panel;
  }

  pub fn getPanelCount( self : *const UiManager ) usize
  {
    var count : usize = 0;

    for( self.panels.items )| *reg |
    {
      if( reg.isAlive ){ count += 1; }
    }

    return count;
  }

  pub inline fn getEventCount( self : *const UiManager ) usize { return self.events.items.len; }
  pub inline fn getHoveredPanel( self : *const UiManager ) UiPanelHandle { return self.hoveredPanel; }

  pub inline fn getCapturedPanel( self : *const UiManager, button : MouseButton ) UiPanelHandle
  {
    return self.capturedPanel[ button.toIndex() ];
  }

  pub fn getPanelAtDrawIndex( self : *const UiManager, drawIdx : usize ) UiPanelHandle
  {
    var cursor : ?usize = null;
    var count  : usize  = 0;

    while( self.getNextDrawIndex( cursor ))| idx |
    {
      if( count == drawIdx ){ return self.panels.items[ idx ].handle; }

      cursor = idx;
      count += 1;
    }

    return .{};
  }


  // ================================ CAPABILITIES ================================

  pub fn setPanelVisible( self : *UiManager, handle : UiPanelHandle, isVisible : bool ) void
  {
    if( self.getRegistrationPtr( handle ))| reg |{ reg.isVisible = isVisible; }
  }

  pub fn setPanelInputEnabled( self : *UiManager, handle : UiPanelHandle, isInputEnabled : bool ) void
  {
    if( self.getRegistrationPtr( handle ))| reg |{ reg.isInputEnabled = isInputEnabled; }
  }

  pub fn setPanelDrawEnabled( self : *UiManager, handle : UiPanelHandle, isDrawEnabled : bool ) void
  {
    if( self.getRegistrationPtr( handle ))| reg |{ reg.isDrawEnabled = isDrawEnabled; }
  }


  // ================================ INPUT ================================

  pub fn updateInput( self : *UiManager, mouse : Mouse ) void
  {
    if( !self.isInit ){ return; }

    const topPanel = self.findTopInputPanelAt( mouse.screenPos );
    self.hoveredPanel = topPanel;

    var routed : [ MouseButton.count + 1 ]UiPanelHandle = [_]UiPanelHandle{ .{} } ** ( MouseButton.count + 1 );
    var routeCount : usize = 0;

    inline for( .{ MouseButton.left, MouseButton.right, MouseButton.middle })| button |
    {
      const captured = self.getCapturedPanel( button );
      if( captured.isValid() and ( mouse.isDown( button ) or mouse.isReleased( button )))
      {
        appendUniqueRoute( &routed, &routeCount, captured );
      }
    }

    if( routeCount == 0 and topPanel.isValid() )
    {
      appendUniqueRoute( &routed, &routeCount, topPanel );
    }

    for( routed[ 0..routeCount ] )| handle |
    {
      if( self.getPanelPtr( handle ))| panel |
      {
        panel.updateInput( mouse );
        self.drainPanelEvents( handle, panel );
      }
    }

    inline for( .{ MouseButton.left, MouseButton.right, MouseButton.middle } )| button |
    {
      if( mouse.isPressed( button ) )
      {
        self.capturedPanel[ button.toIndex() ] = topPanel;
      }

      if( mouse.isReleased( button ) )
      {
        self.capturedPanel[ button.toIndex() ] = .{};
      }
    }
  }

  fn drainPanelEvents( self : *UiManager, handle : UiPanelHandle, panel : *Panel ) void
  {
    while( panel.popEvent() )| event |
    {
      self.events.append( self.alloc, .{ .panel = handle, .event = event }) catch | err |
      {
        utl.log( .ERROR, @src(), "Failed to append UI manager event : {}", .{ err });
        return;
      };
    }
  }

  pub fn popEvent( self : *UiManager ) ?UiManagerEvent
  {
    if( self.events.items.len == 0 ){ return null; }
    return self.events.orderedRemove( 0 );
  }

  pub fn clearEvents( self : *UiManager ) void
  {
    self.events.clearRetainingCapacity();
  }


  // ================================ DRAWING ================================

  pub fn drawAll( self : *UiManager ) void
  {
    if( !self.isInit ){ return; }

    var cursor : ?usize = null;

    while( self.getNextDrawIndex( cursor ))| idx |
    {
      const reg = &self.panels.items[ idx ];
      cursor = idx;

      if( !reg.isVisible or !reg.isDrawEnabled ){ continue; }
      if( reg.panel )| panel |{ panel.draw(); }
    }
  }


  // ================================ ORDERING ================================

  fn findTopInputPanelAt( self : *const UiManager, point : utl.Vec2 ) UiPanelHandle
  {
    var bestIdx : ?usize = null;

    for( self.panels.items, 0.. )| *reg, i |
    {
      if( !reg.isAlive or !reg.isVisible or !reg.isInputEnabled ){ continue; }
      if( reg.panel == null or !reg.panel.?.getBox().isOnPoint( point )){ continue; }

      if( bestIdx )| idx |
      {
        if( isDrawAfter( reg, &self.panels.items[ idx ] )){ bestIdx = i; }
      }
      else
      {
        bestIdx = i;
      }
    }

    if( bestIdx )| idx |{ return self.panels.items[ idx ].handle; }
    return .{};
  }

  fn getNextDrawIndex( self : *const UiManager, cursor : ?usize ) ?usize
  {
    var bestIdx : ?usize = null;

    for( self.panels.items, 0.. )| *reg, i |
    {
      if( !reg.isAlive ){ continue; }
      if( cursor )| cursorIdx |
      {
        if( !isDrawAfter( reg, &self.panels.items[ cursorIdx ] )){ continue; }
      }

      if( bestIdx )| idx |
      {
        if( isDrawBefore( reg, &self.panels.items[ idx ] )){ bestIdx = i; }
      }
      else
      {
        bestIdx = i;
      }
    }

    return bestIdx;
  }
};


// ================================ HELPERS ================================

fn appendUniqueRoute( routes : []UiPanelHandle, count : *usize, handle : UiPanelHandle ) void
{
  if( !handle.isValid() ){ return; }

  for( routes[ 0..count.* ] )| route |
  {
    if( route.isEq( handle )){ return; }
  }

  if( count.* >= routes.len ){ return; }
  routes[ count.* ] = handle;
  count.* += 1;
}

fn isDrawBefore( a : *const UiPanelRegistration, b : *const UiPanelRegistration ) bool
{
  if( a.layer != b.layer ){ return a.layer < b.layer; }
  if( a.z     != b.z     ){ return a.z     < b.z;     }
  return a.order < b.order;
}

fn isDrawAfter( a : *const UiPanelRegistration, b : *const UiPanelRegistration ) bool
{
  if( a.layer != b.layer ){ return a.layer > b.layer; }
  if( a.z     != b.z     ){ return a.z     > b.z;     }
  return a.order > b.order;
}

fn testPanel( box : utl.Box2 ) !Panel
{
  return Panel.init(
    std.testing.allocator,
    .{
      .key    = utl.uiKey( "manager.test.panel" ),
      .box    = box,
      .config = .{ .layout = .absolute },
    }
  );
}

fn testMouseAt( pos : utl.Vec2, isDown : bool, pressed : bool, released : bool ) Mouse
{
  var mouse : Mouse = .{
    .screenPos = pos,
    .frameTime = .new( 1, .NS ),
  };

  mouse.buttons[ MouseButton.left.toIndex() ] = .{
    .isDown            = isDown,
    .pressedThisFrame  = pressed,
    .releasedThisFrame = released,
  };

  return mouse;
}


// ================================ TESTS ================================

test "UiManager orders panels by layer z and registration order"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var a = try testPanel( .{ .center = .new( 0.0, 0.0 ), .scale = .new( 20.0, 20.0 ) } );
  defer a.deinit();

  var b = try testPanel( .{ .center = .new( 0.0, 0.0 ), .scale = .new( 20.0, 20.0 ) } );
  defer b.deinit();

  var c = try testPanel( .{ .center = .new( 0.0, 0.0 ), .scale = .new( 20.0, 20.0 ) } );
  defer c.deinit();

  const hA = try manager.registerPanel( &a, .{ .layer = 0, .z = 2 } );
  const hB = try manager.registerPanel( &b, .{ .layer = 1, .z = 0 } );
  const hC = try manager.registerPanel( &c, .{ .layer = 0, .z = 2 } );

  try std.testing.expect( manager.getPanelAtDrawIndex( 0 ).isEq( hA ));
  try std.testing.expect( manager.getPanelAtDrawIndex( 1 ).isEq( hC ));
  try std.testing.expect( manager.getPanelAtDrawIndex( 2 ).isEq( hB ));
}

test "UiManager routes clicks to top panel and forwards events"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var lower = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 40.0, 40.0 ) } );
  defer lower.deinit();
  _ = try lower.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 15.0, 15.0 ) } } );

  var upper = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 40.0, 40.0 ) } );
  defer upper.deinit();
  const upperButton = try upper.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 15.0, 15.0 ) } } );

  _ = try manager.registerPanel( &lower, .{ .layer = 0 } );
  const upperHandle = try manager.registerPanel( &upper, .{ .layer = 1 } );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, true  ) );

  const event = manager.popEvent().?;
  try std.testing.expect( event.panel.isEq( upperHandle ));
  try std.testing.expect( event.event.isClicked( upperButton ));
  try std.testing.expectEqual( @as( usize, 0 ), lower.getEventCount() );
  try std.testing.expectEqual( @as( usize, 0 ), manager.getEventCount() );
}

test "UiManager keeps captured panel until release outside"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var panel = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 30.0, 30.0 ) } );
  defer panel.deinit();
  _ = try panel.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 10.0, 10.0 ) } } );

  const handle = try manager.registerPanel( &panel, .{} );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true, true, false ) );
  try std.testing.expect( manager.getCapturedPanel( .left ).isEq( handle ));

  manager.updateInput( testMouseAt( .new( 95.0, 95.0 ), true, false, false ) );
  try std.testing.expect( manager.getCapturedPanel( .left ).isEq( handle ));

  manager.updateInput( testMouseAt( .new( 95.0, 95.0 ), false, false, true ) );
  try std.testing.expect( !manager.getCapturedPanel( .left ).isValid() );
  try std.testing.expectEqual( @as( usize, 0 ), manager.getEventCount() );
}
