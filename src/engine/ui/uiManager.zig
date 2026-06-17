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

  hoveredPanel     : UiPanelHandle = .{},
  hoveredPanelTime : utl.Duration  = .{},
  capturedPanel    : [ MouseButton.count ]UiPanelHandle = [_]UiPanelHandle{ .{} } ** MouseButton.count,

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

  /// Invalidates every outstanding panel handle while retaining manager slot
  /// and event-list capacity for reuse by the next registration batch.
  pub fn clear( self : *UiManager ) void
  {
    if( !self.isInit ){ return; }

    self.events.clearRetainingCapacity();
    for( self.panels.items )| *reg |
    {
      reg.isAlive = false;
      reg.panel   = null;
      reg.gen     = nextGeneration( reg.gen );
      reg.handle  = .{};
    }

    self.hoveredPanel     = .{};
    self.hoveredPanelTime = .{};
    self.capturedPanel    = [_]UiPanelHandle{ .{} } ** MouseButton.count;
    self.nextOrder        = 1;
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

      const gen = nextGeneration( slot.gen );
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

    self.clearInputStateFor( handle );

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
  pub inline fn getHoveredPanelTime( self : *const UiManager ) utl.Duration { return self.hoveredPanelTime; }

  pub fn getHoveredWidget( self : *const UiManager ) utl.UiHandle
  {
    const reg = self.getRegistration( self.hoveredPanel ) orelse return .{};
    const panel = reg.panel orelse return .{};
    return panel.getHovered();
  }

  pub inline fn getCapturedPanel( self : *const UiManager, button : MouseButton ) UiPanelHandle
  {
    return self.capturedPanel[ button.toIndex() ];
  }

  pub fn getCapturedWidget( self : *const UiManager, button : MouseButton ) utl.UiHandle
  {
    const reg = self.getRegistration( self.getCapturedPanel( button )) orelse return .{};
    const panel = reg.panel orelse return .{};
    return panel.getPressed( button );
  }

  pub fn hasCapturedPanel( self : *const UiManager ) bool
  {
    inline for( .{ MouseButton.left, MouseButton.right, MouseButton.middle } )| button |
    {
      if( self.getCapturedPanel( button ).isValid() ){ return true; }
    }

    return false;
  }

  pub inline fn hasPendingEvents( self : *const UiManager ) bool
  {
    return self.events.items.len > 0;
  }

  /// Mouse-consumption boundary for game code. This does not imply keyboard
  /// focus, modal blocking, or global hotkey suppression.
  pub fn wantsMouse( self : *const UiManager ) bool
  {
    return self.hoveredPanel.isValid()
      or self.hasCapturedPanel()
      or self.hasPendingEvents();
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
    if( self.getRegistrationPtr( handle ))| reg |
    {
      reg.isVisible = isVisible;
      if( !isVisible ){ self.clearInputStateFor( handle ); }
    }
  }

  pub fn setPanelInputEnabled( self : *UiManager, handle : UiPanelHandle, isInputEnabled : bool ) void
  {
    if( self.getRegistrationPtr( handle ))| reg |
    {
      reg.isInputEnabled = isInputEnabled;
      if( !isInputEnabled ){ self.clearInputStateFor( handle ); }
    }
  }

  pub fn setPanelDrawEnabled( self : *UiManager, handle : UiPanelHandle, isDrawEnabled : bool ) void
  {
    if( self.getRegistrationPtr( handle ))| reg |{ reg.isDrawEnabled = isDrawEnabled; }
  }


  // ================================ INPUT ================================

  /// Routes one mouse snapshot to registered panels. Routing is pointer-only:
  /// it does not imply focus, keyboard capture, or modal blocking.
  pub fn updateInput( self : *UiManager, mouse : Mouse ) void
  {
    if( !self.isInit ){ return; }

    const topPanel = self.findTopInputPanelAt( mouse.screenPos );
    self.updateHoveredPanel( topPanel, mouse.frameTime );

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
      if( !reg.isVisible or !reg.isDrawEnabled ){ continue; }
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

  fn clearInputStateFor( self : *UiManager, handle : UiPanelHandle ) void
  {
    if( self.hoveredPanel.isEq( handle ))
    {
      self.hoveredPanel     = .{};
      self.hoveredPanelTime = .{};
    }

    for( &self.capturedPanel )| *captured |
    {
      if( captured.isEq( handle )){ captured.* = .{}; }
    }
  }

  fn updateHoveredPanel( self : *UiManager, hovered : UiPanelHandle, deltaTime : utl.Duration ) void
  {
    if( !hovered.isValid() )
    {
      self.hoveredPanel     = .{};
      self.hoveredPanelTime = .{};
      return;
    }

    if( self.hoveredPanel.isEq( hovered ))
    {
      self.hoveredPanelTime = addDuration( self.hoveredPanelTime, deltaTime );
    }
    else
    {
      self.hoveredPanel     = hovered;
      self.hoveredPanelTime = .{};
    }
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

fn nextGeneration( gen : u32 ) u32
{
  const next = gen +% 1;
  return if( next == 0 ) 1 else next;
}

fn addDuration( base : utl.Duration, delta : utl.Duration ) utl.Duration
{
  return .{
    .value = std.math.add( i128, base.value, delta.value ) catch std.math.maxInt( i128 ),
  };
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

test "UiManager reuses unregistered panel slots with new generations"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var first = try testPanel( .{ .center = .new( 0.0, 0.0 ), .scale = .new( 20.0, 20.0 ) } );
  defer first.deinit();

  var second = try testPanel( .{ .center = .new( 0.0, 0.0 ), .scale = .new( 20.0, 20.0 ) } );
  defer second.deinit();

  const stale = try manager.registerPanel( &first, .{} );
  try std.testing.expect( manager.unregisterPanel( stale ));
  try std.testing.expect( manager.getRegistration( stale ) == null );

  const fresh = try manager.registerPanel( &second, .{} );
  try std.testing.expectEqual( stale.idx, fresh.idx );
  try std.testing.expect( stale.gen != fresh.gen );
  try std.testing.expect( manager.getRegistration( stale ) == null );
  try std.testing.expect( manager.getPanelPtr( fresh ) == &second );
}

test "UiManager keeps panel visibility input and draw flags independent"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var invisible = try testPanel( .{ .center = .new( 20.0, 20.0 ), .scale = .new( 10.0, 10.0 ) } );
  defer invisible.deinit();
  _ = try invisible.addButton( .{ .box = .{ .center = .new( 20.0, 20.0 ), .scale = .new( 5.0, 5.0 ) } } );

  const invisibleHandle = try manager.registerPanel( &invisible, .{ .isVisible = false } );
  try std.testing.expect( !manager.getPanelAtDrawIndex( 0 ).isValid() );

  manager.updateInput( testMouseAt( .new( 20.0, 20.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 20.0, 20.0 ), false, false, true  ) );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expectEqual( @as( usize, 0 ), manager.getEventCount() );

  manager.setPanelVisible( invisibleHandle, true );
  manager.setPanelInputEnabled( invisibleHandle, false );
  try std.testing.expect( manager.getPanelAtDrawIndex( 0 ).isEq( invisibleHandle ));

  manager.updateInput( testMouseAt( .new( 20.0, 20.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 20.0, 20.0 ), false, false, true  ) );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expectEqual( @as( usize, 0 ), manager.getEventCount() );

  manager.setPanelInputEnabled( invisibleHandle, true );
  manager.setPanelDrawEnabled(  invisibleHandle, false );
  try std.testing.expect( !manager.getPanelAtDrawIndex( 0 ).isValid() );

  manager.updateInput( testMouseAt( .new( 20.0, 20.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 20.0, 20.0 ), false, false, true  ) );
  try std.testing.expect( manager.getHoveredPanel().isEq( invisibleHandle ));
  try std.testing.expectEqual( @as( usize, 1 ), manager.getEventCount() );
}

test "UiManager routes through lower panel when top panel input is disabled"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var lower = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 30.0, 30.0 ) } );
  defer lower.deinit();
  const lowerButton = try lower.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 10.0, 10.0 ) } } );

  var upper = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 30.0, 30.0 ) } );
  defer upper.deinit();
  _ = try upper.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 10.0, 10.0 ) } } );

  const lowerHandle = try manager.registerPanel( &lower, .{ .layer = 0 } );
  const upperHandle = try manager.registerPanel( &upper, .{ .layer = 1, .isInputEnabled = false } );

  try std.testing.expect( manager.getPanelAtDrawIndex( 0 ).isEq( lowerHandle ));
  try std.testing.expect( manager.getPanelAtDrawIndex( 1 ).isEq( upperHandle ));

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, true  ) );

  const event = manager.popEvent().?;
  try std.testing.expect( event.panel.isEq( lowerHandle ));
  try std.testing.expect( event.event.isClicked( lowerButton ));
  try std.testing.expectEqual( @as( usize, 0 ), manager.getEventCount() );
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

test "UiManager clears capture when a captured panel is unregistered"
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
  try std.testing.expect( manager.wantsMouse() );

  try std.testing.expect( manager.unregisterPanel( handle ));
  try std.testing.expect( !manager.getCapturedPanel( .left ).isValid() );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expect( !manager.wantsMouse() );
}

test "UiManager clear invalidates handles and retains reusable capacity"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var panel = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 30.0, 30.0 ) } );
  defer panel.deinit();
  _ = try panel.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 10.0, 10.0 ) } } );

  const stale = try manager.registerPanel( &panel, .{} );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, true  ) );
  try std.testing.expectEqual( @as( usize, 1 ), manager.getEventCount() );

  const slotCap  = manager.panels.capacity;
  const eventCap = manager.events.capacity;

  manager.clear();
  try std.testing.expectEqual( slotCap,  manager.panels.capacity );
  try std.testing.expectEqual( eventCap, manager.events.capacity );
  try std.testing.expectEqual( @as( usize, 0 ), manager.getPanelCount() );
  try std.testing.expect( manager.getRegistration( stale ) == null );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expect( !manager.getCapturedPanel( .left ).isValid() );

  const fresh = try manager.registerPanel( &panel, .{} );
  try std.testing.expectEqual( stale.idx, fresh.idx );
  try std.testing.expect( stale.gen != fresh.gen );
  try std.testing.expect( manager.getRegistration( stale ) == null );
}

test "UiManager wantsMouse follows hover capture and pending routed events"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var panel = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 30.0, 30.0 ) } );
  defer panel.deinit();
  const button = try panel.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 10.0, 10.0 ) } } );

  const handle = try manager.registerPanel( &panel, .{} );
  try std.testing.expect( !manager.wantsMouse() );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, false ) );
  try std.testing.expect( manager.getHoveredPanel().isEq( handle ));
  try std.testing.expect( manager.wantsMouse() );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, false ) );
  try std.testing.expect( manager.getHoveredPanelTime().value > 0 );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true, true, false ) );
  try std.testing.expect( manager.getCapturedPanel( .left ).isEq( handle ));
  try std.testing.expect( manager.wantsMouse() );

  manager.updateInput( testMouseAt( .new( 90.0, 90.0 ), true, false, false ) );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expect( manager.getCapturedPanel( .left ).isEq( handle ));
  try std.testing.expect( manager.wantsMouse() );

  manager.updateInput( testMouseAt( .new( 90.0, 90.0 ), false, false, true ) );
  try std.testing.expect( !manager.getCapturedPanel( .left ).isValid() );
  try std.testing.expect( !manager.wantsMouse() );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true,  true,  false ) );
  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, true  ) );
  try std.testing.expectEqual( @as( usize, 1 ), manager.getEventCount() );

  manager.updateInput( testMouseAt( .new( 90.0, 90.0 ), false, false, false ) );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expect( manager.wantsMouse() );
  try std.testing.expect( manager.popEvent().?.event.isClicked( button ) );

  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expect( !manager.wantsMouse() );
}

test "UiManager wantsMouse clears when routing is disabled"
{
  var manager : UiManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var panel = try testPanel( .{ .center = .new( 50.0, 50.0 ), .scale = .new( 30.0, 30.0 ) } );
  defer panel.deinit();
  _ = try panel.addButton( .{ .box = .{ .center = .new( 50.0, 50.0 ), .scale = .new( 10.0, 10.0 ) } } );

  const handle = try manager.registerPanel( &panel, .{} );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), true, true, false ) );
  try std.testing.expect( manager.wantsMouse() );

  manager.setPanelInputEnabled( handle, false );
  try std.testing.expect( !manager.wantsMouse() );

  manager.updateInput( testMouseAt( .new( 50.0, 50.0 ), false, false, true ) );
  try std.testing.expect( !manager.getHoveredPanel().isValid() );
  try std.testing.expect( !manager.getCapturedPanel( .left ).isValid() );
  try std.testing.expect( !manager.wantsMouse() );
}
