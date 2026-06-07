const std   = @import( "std" );
const utl = @import( "utils" );
const input = @import( "uiInput.zig" );
const node  = @import( "uiNode.zig" );
const types = @import( "uiTypes.zig" );

pub const UiId        = types.UiId;
pub const UiNodeKind  = types.UiNodeKind;
pub const UiLayer     = types.UiLayer;
pub const UiLayout    = types.UiLayout;
pub const UiEventType = types.UiEventType;
pub const UiEvent     = types.UiEvent;
pub const UiStyle     = types.UiStyle;
pub const UiNodeOpts  = types.UiNodeOpts;
pub const UiInput     = input.UiInput;

pub const boxFromTopLeft = types.boxFromTopLeft;
pub const boxSize        = types.boxSize;

const UiNode   = node.UiNode;
const Duration = utl.Duration;
const Instant  = utl.Instant;

const tooltipDelay : Duration = Duration.new( 350 * Duration.nsPerMs() );
const scrollWheelStep : f64 = 30.0;
const clipStackLen : usize = 8;


// ================================ UI CONTEXT ================================

pub const UiContext = struct
{
  alloc : std.mem.Allocator = undefined,

  nodes  : std.ArrayList( UiNode  ) = .empty,
  events : std.ArrayList( UiEvent ) = .empty,

  input : UiInput = .{},

  // Hover/focus/press are UI-local input ownership states used for routing and rendering.
  hovered : UiId = .{},
  pressed : UiId = .{},
  focused : UiId = .{},

  hoveredPrev       : UiId     = .{},
  hoverStarted      : ?Instant = null,
  tooltipHoverReady : bool     = false,

  wantsMouseFlag    : bool = false,
  wantsKeyboardFlag : bool = false,

  // Debug overlay is a render-only diagnostic surface; it does not create nodes or capture input.
  debugOverlayEnabled : bool = false,
  debugOverlayBounds  : bool = true,

  clipStack : [ clipStackLen ]utl.Box2 = [_]utl.Box2{ .{} } ** clipStackLen,
  clipDepth : usize = 0,

  isInit : bool = false,


  // ================================ INITIALIZATION ================================

  pub fn init( self : *UiContext, alloc : std.mem.Allocator ) void
  {
    utl.qlog( .TRACE, 0, @src(), "# Initializing UI manager..." );

    if( self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "UI manager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.nodes  = std.ArrayList( UiNode  ).empty;
    self.events = std.ArrayList( UiEvent ).empty;

    self.input   = .{};
    self.hovered = .{};
    self.pressed = .{};
    self.focused = .{};

    self.hoveredPrev       = .{};
    self.hoverStarted      = .{};
    self.tooltipHoverReady = false;

    self.wantsMouseFlag    = false;
    self.wantsKeyboardFlag = false;

    self.debugOverlayEnabled = false;
    self.debugOverlayBounds  = true;

    self.clipDepth = 0;

    self.isInit = true;
    utl.qlog( .INFO, 0, @src(), "& UI manager initialized !" );
  }

  pub fn deinit( self : *UiContext ) void
  {
    utl.qlog( .TRACE, 0, @src(), "# Deinitializing UI manager..." );

    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "UI manager is uninitialized : returning" );
      return;
    }

    self.events.deinit( self.alloc );
    self.nodes.deinit(  self.alloc );

    self.input   = .{};
    self.hovered = .{};
    self.pressed = .{};
    self.focused = .{};

    self.hoveredPrev       = .{};
    self.hoverStarted      = .{};
    self.tooltipHoverReady = false;

    self.wantsMouseFlag    = false;
    self.wantsKeyboardFlag = false;

    self.debugOverlayEnabled = false;
    self.debugOverlayBounds  = true;

    self.clipDepth = 0;

    self.isInit = false;
    self.alloc  = undefined;

    utl.qlog( .INFO, 0, @src(), "$ UI manager deinitialized !" );
  }


  // ================================ FRAME LIFETIME ================================

  /// Reads this frame's raw input and clears transient hover/press rendering state.
  pub fn beginFrame( self : *UiContext ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Failed to begin frame : UiContext uninitialized" );
      return;
    }

    self.input = UiInput.readRaylib();

    self.hovered = .{};
    self.clipDepth = 0;
    self.wantsMouseFlag    = false;
    self.wantsKeyboardFlag = false;

    if( self.focused.isValid() and !self.isNodeAlive( self.focused )){ self.focused = .{}; }

    for( self.nodes.items )| *uiNode |
    {
      uiNode.isHovered = false;
      uiNode.isFocused = uiNode.id.isEq( self.focused );

      if( !self.input.leftDown ){ uiNode.isPressed = false; }
    }
  }

  /// Recomputes bounds for each root and its visible child tree.
  pub fn updateLayout( self : *UiContext ) void
  {
    if( !self.isInit ){ return; }

    for( self.nodes.items )| *uiNode |
    {
      if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
      if( uiNode.parent.isValid() ){ continue; }

      if( uiNode.localBox.scale.isZero() )
      {
        uiNode.bounds = boxFromTopLeft( .{}, uiNode.desiredSize );
      }
      else { uiNode.bounds = uiNode.localBox; }

      self.layoutChildren( uiNode.id );
    }
  }

  /// Routes pointer/key input through the laid-out tree and emits widget events.
  pub fn dispatchInput( self : *UiContext ) void
  {
    if( !self.isInit ){ return; }

    self.hovered = self.findHovered( self.input.mousePos );
    self.updateTooltipState();
    if( self.getNodePtr( self.hovered ))| uiNode |{ uiNode.isHovered = true; }

    if( self.input.escapePressed )
    {
      if( self.closeTopEscapeNode() ){ self.wantsKeyboardFlag = true; }
    }

    if( self.input.mouseWheel != 0.0 )
    {
      if( self.scrollHovered( self.input.mousePos, self.input.mouseWheel ))
      {
        self.wantsMouseFlag = true;
      }
    }

    if( self.input.leftPressed )
    {
      self.closeOutsideTransients( self.input.mousePos, self.hovered );

      self.hovered = self.findHovered( self.input.mousePos );
      const newFocus = self.hovered;

      if( self.getNodePtr( newFocus ))| uiNode |
      {
        uiNode.isHovered = true;
        uiNode.isPressed = true;

        self.pressed = uiNode.id;

        self.wantsMouseFlag    = true;
        self.wantsKeyboardFlag = true;

        self.setFocused( newFocus );

        if( uiNode.isSlider() ){ self.updateSliderFromMouse( newFocus ); }
      }
      else
      {
        self.pressed = .{};
        self.setFocused( .{} );
      }
    }

    if( self.input.leftReleased )
    {
      const oldPressed = self.pressed;

      if( self.getNode( oldPressed ))| uiNode |
      {
        if( uiNode.isSlider() ){ self.updateSliderFromMouse( oldPressed ); }
      }

      if( self.getNodePtr( oldPressed ))| uiNode |{ uiNode.isPressed = false; }

      if( oldPressed.isValid() )
      {
        self.wantsMouseFlag = true;

        if( self.getNode( oldPressed ))| uiNode |
        {
          if( !uiNode.isSlider() and oldPressed.isEq( self.hovered )){ self.triggerNode( oldPressed ); }
        }
      }

      self.pressed = .{};
    }

    // A pressed node has mouse capture until release; sliders and movable nodes update while captured.
    if( self.input.leftDown and self.pressed.isValid() )
    {
      if( self.getNode( self.pressed ))| uiNode |
      {
        if( uiNode.isSlider() ){ self.updateSliderFromMouse( self.pressed ); }
        else if( uiNode.isMovable ){ self.moveNodeByMouseDelta( self.pressed ); }
      }

      self.wantsMouseFlag = true;
    }

    if( self.hovered.isValid() ){ self.wantsMouseFlag = true; }

    if( self.focused.isValid() ){ self.wantsKeyboardFlag = true; }
    // Modal state captures game input even when the pointer is outside the modal surface.
    if( self.hasModalNode() )
    {
      self.wantsMouseFlag    = true;
      self.wantsKeyboardFlag = true;
    }
  }

  pub fn endFrame( self : *UiContext ) void
  {
    _ = self;
  }


  // ================================ NODE CREATION ================================

  /// Creates a node in a free slot when possible; recycled slots get a new generation.
  pub fn createNode( self : *UiContext, kind : UiNodeKind, opts : UiNodeOpts ) ?UiId
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot create UI node : UI manager is uninitialized" );
      return null;
    }

    var fixedOpts = opts;
    fixedOpts.layer = self.resolveLayer( kind, opts );

    for( self.nodes.items, 0.. )| *slot, i |
    {
      if( slot.isAlive ){ continue; }

      // Bump generation so stale IDs from the previous occupant stop resolving.
      var gen = slot.gen +% 1;
      if( gen == 0 ){ gen = 1; }

      const id = UiId.fromIndexGen( @intCast( i ), gen );
      slot.* = UiNode.init( id, kind, fixedOpts );
      return id;
    }

    if( self.nodes.items.len >= @as( usize, UiId.invalidIndex ))
    {
      utl.qlog( .ERROR, 0, @src(), "Cannot create UI node : node index limit reached" );
      return null;
    }

    const id = UiId.fromIndexGen( @intCast( self.nodes.items.len ), 1 );

    self.nodes.append( self.alloc, UiNode.init( id, kind, fixedOpts )) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to append UI node : {}", .{ err });
      return null;
    };

    return id;
  }

  fn resolveLayer( self : *const UiContext, kind : UiNodeKind, opts : UiNodeOpts ) UiLayer
  {
    if( opts.layer )| layer |{ return layer; }
    if( opts.isModal ){ return .modal; }

    if( opts.parent )| parent |
    {
      if( self.getNode( parent ))| parentNode |{ return parentNode.layer; }
    }

    return UiLayer.defaultFor( kind, false );
  }

  pub inline fn createRoot(     self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .root,     opts ); }
  pub inline fn createPanel(    self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .panel,    opts ); }
  pub inline fn createLabel(    self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .label,    opts ); }
  pub inline fn createButton(   self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .button,   opts ); }
  pub inline fn createCheckbox( self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .checkbox, opts ); }
  pub inline fn createPopup(    self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .popup,    opts ); }
  pub inline fn createWindow(   self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .window,   opts ); }
  pub inline fn createScrollArea( self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .scrollArea, opts ); }
  pub inline fn createSlider(     self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .slider,     opts ); }


  // ================================ NODE ACCESS ================================

  pub fn getNodePtr( self : *UiContext, id : UiId ) ?*UiNode
  {
    if( !id.isValid() ){ return null; }

    const idx : usize = @intCast( id.idx );
    if( idx >= self.nodes.items.len ){ return null; }

    const uiNode = &self.nodes.items[ idx ];
    if( !uiNode.isAlive ){ return null; }
    if( uiNode.gen != id.gen ){ return null; }

    return uiNode;
  }

  pub fn getNode( self : *const UiContext, id : UiId ) ?*const UiNode
  {
    if( !id.isValid() ){ return null; }

    const idx : usize = @intCast( id.idx );
    if( idx >= self.nodes.items.len ){ return null; }

    const uiNode = &self.nodes.items[ idx ];
    if( !uiNode.isAlive ){ return null; }
    if( uiNode.gen != id.gen ){ return null; }

    return uiNode;
  }

  pub inline fn isNodeAlive( self : *const UiContext, id : UiId ) bool
  {
    return self.getNode( id ) != null;
  }

  pub fn setText( self : *UiContext, id : UiId, str : []const u8 ) void
  {
    if( self.getNodePtr( id ))| uiNode |{ uiNode.setText( str ); }
  }

  pub fn setTextFmt( self : *UiContext, id : UiId, comptime fmt : []const u8, args : anytype ) void
  {
    var buf : [ UiNode.textBufLen ]u8 = undefined;
    const str = std.fmt.bufPrint( &buf, fmt, args ) catch
    {
      self.setText( id, "<text too long>" );
      return;
    };

    self.setText( id, str );
  }

  pub fn getText( self : *const UiContext, id : UiId ) []const u8
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.getText(); }
    return "";
  }

  pub fn setTooltip( self : *UiContext, id : UiId, str : []const u8 ) void
  {
    if( self.getNodePtr( id ))| uiNode |{ uiNode.setTooltip( str ); }
  }

  pub fn getTooltip( self : *const UiContext, id : UiId ) []const u8
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.getTooltip(); }
    return "";
  }

  pub fn setBool( self : *UiContext, id : UiId, value : bool ) void
  {
    if( self.getNodePtr( id ))| uiNode |{ uiNode.valueBool = value; }
  }

  pub fn getBool( self : *const UiContext, id : UiId ) bool
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.valueBool; }
    return false;
  }

  pub fn setFloat( self : *UiContext, id : UiId, value : f64 ) void
  {
    if( self.getNodePtr( id ))| uiNode |
    {
      uiNode.valueFlt = self.clampSliderValue( uiNode, value );
    }
  }

  pub fn getFloat( self : *const UiContext, id : UiId ) f64
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.valueFlt; }
    return 0.0;
  }

  pub fn setBox( self : *UiContext, id : UiId, box : utl.Box2 ) void
  {
    if( self.getNodePtr( id ))| uiNode |
    {
      uiNode.localBox = box;
      uiNode.bounds   = box;
    }
  }

  pub fn setVisible( self : *UiContext, id : UiId, isVisible : bool ) void
  {
    if( self.getNodePtr( id ))| uiNode |{ uiNode.isVisible = isVisible; }
  }

  pub fn setMovable( self : *UiContext, id : UiId, isMovable : bool ) void
  {
    if( self.getNodePtr( id ))| uiNode |{ uiNode.isMovable = isMovable; }
  }

  pub fn getMovable( self : *const UiContext, id : UiId ) bool
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.isMovable; }
    return false;
  }

  pub fn getNodeKind( self : *const UiContext, id : UiId ) ?UiNodeKind
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.kind; }
    return null;
  }

  pub fn getNodeKindName( self : *const UiContext, id : UiId ) []const u8
  {
    if( self.getNodeKind( id ))| kind |{ return @tagName( kind ); }
    return "none";
  }

  pub fn getNodeLayer( self : *const UiContext, id : UiId ) ?UiLayer
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.layer; }
    return null;
  }

  pub fn getParent( self : *const UiContext, id : UiId ) UiId
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.parent; }
    return .{};
  }

  pub inline fn getHoveredId( self : *const UiContext ) UiId { return self.hovered; }
  pub inline fn getPressedId( self : *const UiContext ) UiId { return self.pressed; }
  pub inline fn getFocusedId( self : *const UiContext ) UiId { return self.focused; }

  pub inline fn setDebugOverlay( self : *UiContext, enabled : bool, drawBounds : bool ) void
  {
    self.debugOverlayEnabled = enabled;
    self.debugOverlayBounds  = drawBounds;
  }

  /// True when UI consumed or is under pointer input this frame.
  pub inline fn wantsMouse( self : *const UiContext ) bool
  {
    return self.wantsMouseFlag;
  }

  /// True when UI focus/modal state should suppress game keyboard shortcuts.
  pub inline fn wantsKeyboard( self : *const UiContext ) bool
  {
    return self.wantsKeyboardFlag;
  }


  // ================================ NODE CLOSING ================================

  /// Closes one node, then closes children it owns and nodes that depend on it.
  pub fn closeNode( self : *UiContext, id : UiId ) void
  {
    var valueBool : bool = false;
    var valueFlt  : f64  = 0.0;
    {
      const uiNode = self.getNodePtr( id ) orelse return;

      valueBool = uiNode.valueBool;
      valueFlt  = uiNode.valueFlt;

      uiNode.isAlive   = false;
      uiNode.isVisible = false;
      uiNode.isHovered = false;
      uiNode.isPressed = false;
      uiNode.isFocused = false;
    }

    self.clearActiveRefs(   id );
    self.closeChildrenOf(   id );
    self.closeDependentsOf( id );

    self.pushEvent( .{ .eType = .closed, .node = id, .valueBool = valueBool, .valueFlt = valueFlt });
  }

  /// Closes layout-owned descendants of `parent`.
  pub fn closeChildrenOf( self : *UiContext, parent : UiId ) void
  {
    var i : usize = 0;
    while( i < self.nodes.items.len ) : ( i += 1 )
    {
      const id = self.nodes.items[ i ].id;
      if( !self.nodes.items[ i ].isAlive ){ continue; }
      if(  self.nodes.items[ i ].parent.isEq( parent )){ self.closeNode( id ); }
    }
  }

  /// Closes menu/popup chains whose lifetime is tied to `dependency`.
  pub fn closeDependentsOf( self : *UiContext, dependency : UiId ) void
  {
    var i : usize = 0;
    while( i < self.nodes.items.len ) : ( i += 1 )
    {
      const id = self.nodes.items[ i ].id;
      if( !self.nodes.items[ i ].isAlive ){ continue; }
      if(  self.nodes.items[ i ].dependsOn.isEq( dependency )){ self.closeNode( id ); }
    }
  }

  fn clearActiveRefs( self : *UiContext, id : UiId ) void
  {
    if( self.hovered.isEq( id )){ self.hovered = .{}; }
    if( self.pressed.isEq( id )){ self.pressed = .{}; }
    if( self.focused.isEq( id )){ self.focused = .{}; }
  }

  fn setFocused( self : *UiContext, id : UiId ) void
  {
    if( self.getNodePtr( self.focused ))| oldNode |{ oldNode.isFocused = false; }

    self.focused = id;

    if( self.getNodePtr( self.focused ))| newNode |{ newNode.isFocused = true; }
  }


  // ================================ EVENTS ================================

  fn pushEvent( self : *UiContext, event : UiEvent ) void
  {
    self.events.append( self.alloc, event ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to append UI event : {}", .{ err });
      return;
    };
  }

  /// Pops the oldest queued UI event for game code to consume.
  pub fn popEvent( self : *UiContext ) ?UiEvent
  {
    if( !self.isInit ){ return null; }
    if( self.events.items.len == 0 ){ return null; }

    return self.events.orderedRemove( 0 );
  }

  pub inline fn clearEvents( self : *UiContext ) void
  {
    self.events.clearRetainingCapacity();
  }

  pub inline fn getEventCount( self : *const UiContext ) usize
  {
    return self.events.items.len;
  }


  // ================================ LAYOUT ================================

  /// Applies the parent layout mode to visible direct children, then recurses.
  fn layoutChildren( self : *UiContext, parentId : UiId ) void
  {
    const parentSnapshot = self.getNode( parentId ) orelse return;

    const parentBounds = parentSnapshot.bounds;
    const layout       = parentSnapshot.layout;
    const padding      = parentSnapshot.padding;
    const gap          = parentSnapshot.gap;
    const isScrollArea = parentSnapshot.isScrollArea();

    if( isScrollArea )
    {
      const contentHeight = self.measureScrollContentHeight( parentId );
      const maxScroll = @max( 0.0, contentHeight - parentBounds.getSizeY() );

      if( self.getNodePtr( parentId ))| parent |
      {
        parent.scrollContentHeight = contentHeight;
        parent.scrollY = utl.clmp( parent.scrollY, 0.0, maxScroll );
      }
    }

    // Scroll areas keep child bounds in normal layout space, then shift them vertically by scrollY.
    const scrollY = if( self.getNode( parentId ))| parent | parent.scrollY else 0.0;
    const childYOffset = if( isScrollArea ) -scrollY else 0.0;

    switch( layout )
    {
      .vertical =>
      {
        var topLeft = parentBounds.getTopLeft().add( .new( padding, padding + childYOffset ));
        const contentWidth = @max( 0.0, parentBounds.getSizeX() - ( padding * 2.0 ));

        for( 0..self.nodes.items.len )| i |
        {
          const id = self.nodes.items[ i ].id;
          if( !self.isLayoutChild( id, parentId )){ continue; }

          var size = self.nodes.items[ i ].desiredSize;
          if( size.x <= 0.0 ){ size.x = contentWidth; }

          self.nodes.items[ i ].bounds = boxFromTopLeft( topLeft, size );
          topLeft.y += size.y + gap;

          self.layoutChildren( id );
        }
      },

      .horizontal =>
      {
        var topLeft = parentBounds.getTopLeft().add( .new( padding, padding + childYOffset ));
        const contentHeight = @max( 0.0, parentBounds.getSizeY() - ( padding * 2.0 ));

        for( 0..self.nodes.items.len )| i |
        {
          const id = self.nodes.items[ i ].id;
          if( !self.isLayoutChild( id, parentId )){ continue; }

          var size = self.nodes.items[ i ].desiredSize;
          if( size.y <= 0.0 ){ size.y = contentHeight; }

          self.nodes.items[ i ].bounds = boxFromTopLeft( topLeft, size );
          topLeft.x += size.x + gap;

          self.layoutChildren( id );
        }
      },

      .absolute, .floating =>
      {
        const parentTopLeft = parentBounds.getTopLeft().add( .new( 0.0, childYOffset ));

        for( 0..self.nodes.items.len )| i |
        {
          const id = self.nodes.items[ i ].id;
          if( !self.isLayoutChild( id, parentId )){ continue; }

          var childBox = self.nodes.items[ i ].localBox;
          if( childBox.scale.isZero() ){ childBox.scale = self.nodes.items[ i ].desiredSize.mulVal( 0.5 ); }

          childBox.center = parentTopLeft.add( childBox.center );
          self.nodes.items[ i ].bounds = childBox;

          self.layoutChildren( id );
        }
      },
    }
  }

  fn measureScrollContentHeight( self : *const UiContext, parentId : UiId ) f64
  {
    const parent = self.getNode( parentId ) orelse return 0.0;

    switch( parent.layout )
    {
      .vertical =>
      {
        var height = parent.padding * 2.0;
        var childCount : usize = 0;

        for( self.nodes.items )| *uiNode |
        {
          if( !self.isLayoutChild( uiNode.id, parentId )){ continue; }

          height += uiNode.desiredSize.y;
          childCount += 1;
        }

        if( childCount > 1 ){ height += parent.gap * @as( f64, @floatFromInt( childCount - 1 )); }
        return height;
      },

      else =>
      {
        var bottom = parent.bounds.getMinY() + parent.padding;

        for( self.nodes.items )| *uiNode |
        {
          if( !self.isLayoutChild( uiNode.id, parentId )){ continue; }

          const childBottom = uiNode.localBox.getMaxY() + uiNode.desiredSize.y + parent.padding;
          bottom = @max( bottom, childBottom );
        }

        return @max( parent.bounds.getSizeY(), bottom );
      },
    }
  }

  fn isLayoutChild( self : *const UiContext, child : UiId, parent : UiId ) bool
  {
    const uiNode = self.getNode( child ) orelse return false;
    if( !uiNode.isVisible ){ return false; }
    return uiNode.parent.isEq( parent );
  }


  // ================================ INPUT HELPERS ================================

  /// Finds the topmost pointer-capturing node under `mousePos`.
  fn findHovered( self : *const UiContext, mousePos : utl.Vec2 ) UiId
  {
    const activeModal = self.findActiveModal();

    var layerIdx : usize = UiLayer.count;
    while( layerIdx > 0 )
    {
      layerIdx -= 1;

      const layer = UiLayer.fromIndex( layerIdx );
      if( !layer.isInputLayer() ){ continue; }

      // Later nodes on the same layer are rendered later, so scan backward for topmost hit.
      var i = self.nodes.items.len;
      while( i > 0 )
      {
        i -= 1;

        const uiNode = &self.nodes.items[ i ];
        if( uiNode.layer != layer ){ continue; }
        if( !uiNode.capturesPointer() ){ continue; }
        if( !self.isVisibleInTree( uiNode.id )){ continue; }
        // Active modals block non-descendant hit tests behind them.
        if( activeModal.isValid() and !self.isDescOrSelf( uiNode.id, activeModal )){ continue; }
        if( !uiNode.bounds.isOnPoint( mousePos )){ continue; }
        if( !self.isPointInsideClipAncestors( uiNode.id, mousePos )){ continue; }

        return uiNode.id;
      }
    }

    return .{};
  }

  fn findActiveModal( self : *const UiContext ) UiId
  {
    var i = self.nodes.items.len;
    while( i > 0 )
    {
      i -= 1;

      const uiNode = &self.nodes.items[ i ];
      if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
      if( !uiNode.isModal ){ continue; }
      if( !self.isVisibleInTree( uiNode.id )){ continue; }

      return uiNode.id;
    }

    return .{};
  }

  fn isPointInsideClipAncestors( self : *const UiContext, id : UiId, mousePos : utl.Vec2 ) bool
  {
    var cursor = id;
    while( self.getNode( cursor ))| uiNode |
    {
      if( !uiNode.parent.isValid() ){ return true; }

      const parent = self.getNode( uiNode.parent ) orelse return false;
      if( parent.isScrollArea() and !parent.bounds.isOnPoint( mousePos )){ return false; }

      cursor = uiNode.parent;
    }

    return false;
  }

  fn scrollHovered( self : *UiContext, mousePos : utl.Vec2, wheel : f64 ) bool
  {
    const activeModal = self.findActiveModal();

    var layerIdx : usize = UiLayer.count;
    while( layerIdx > 0 )
    {
      layerIdx -= 1;

      const layer = UiLayer.fromIndex( layerIdx );
      if( !layer.isInputLayer() ){ continue; }

      var i = self.nodes.items.len;
      while( i > 0 )
      {
        i -= 1;

        const uiNode = &self.nodes.items[ i ];
        if( uiNode.layer != layer ){ continue; }
        if( !uiNode.isScrollArea() ){ continue; }
        if( !uiNode.capturesPointer() ){ continue; }
        if( !self.isVisibleInTree( uiNode.id )){ continue; }
        if( activeModal.isValid() and !self.isDescOrSelf( uiNode.id, activeModal )){ continue; }
        if( !uiNode.bounds.isOnPoint( mousePos )){ continue; }
        if( !self.isPointInsideClipAncestors( uiNode.id, mousePos )){ continue; }

        const maxScroll = @max( 0.0, uiNode.scrollContentHeight - uiNode.bounds.getSizeY() );
        const oldScroll = uiNode.scrollY;
        self.nodes.items[ i ].scrollY = utl.clmp( uiNode.scrollY - ( wheel * scrollWheelStep ), 0.0, maxScroll );
        return !utl.isFltEq( oldScroll, self.nodes.items[ i ].scrollY );
      }
    }

    return false;
  }

  fn updateTooltipState( self : *UiContext ) void
  {
    if( !self.hovered.isEq( self.hoveredPrev ))
    {
      self.hoveredPrev       = self.hovered;
      self.hoverStarted      = if( self.hovered.isValid() ) Instant.now() else null;
      self.tooltipHoverReady = false;
      return;
    }

    const hoveredNode = self.getNode( self.hovered ) orelse
    {
      self.hoverStarted      = null;
      self.tooltipHoverReady = false;
      return;
    };

    if( hoveredNode.tooltipLen == 0 )
    {
      self.tooltipHoverReady = false;
      return;
    }

    if( self.hoverStarted == null ){ self.hoverStarted = Instant.now(); }

    // Tooltip readiness is render-only state; it does not create a node or consume input.
    self.tooltipHoverReady = self.hoverStarted.?.timeSince().value >= tooltipDelay.value;
  }

  fn updateSliderFromMouse( self : *UiContext, id : UiId ) void
  {
    const uiNode = self.getNodePtr( id ) orelse return;
    if( !uiNode.isSlider() ){ return; }

    const nextValue = self.sliderValueFromMouse( uiNode, self.input.mousePos );
    if( utl.isFltEq( uiNode.valueFlt, nextValue )){ return; }

    uiNode.valueFlt = nextValue;
    self.pushEvent( .{ .eType = .changed, .node = id, .valueFlt = nextValue });
  }

  fn moveNodeByMouseDelta( self : *UiContext, id : UiId ) void
  {
    if( self.input.mouseDelta.isZero() ){ return; }

    {
      const uiNode = self.getNodePtr( id ) orelse return;
      if( !uiNode.isMovable ){ return; }

      uiNode.localBox = uiNode.localBox.moveCenter( self.input.mouseDelta );
      uiNode.bounds   = uiNode.bounds.moveCenter(   self.input.mouseDelta );

      if( !uiNode.parent.isValid() )
      {
        // Top-level movable menus stay fully on-screen.
        uiNode.localBox.clampInArea( .{}, utl.getScreenSize() );
        uiNode.bounds = uiNode.localBox;
      }
    }

    self.layoutChildren( id );
  }

  fn sliderValueFromMouse( self : *const UiContext, uiNode : *const UiNode, mousePos : utl.Vec2 ) f64
  {
    const pad  = @max( 6.0, uiNode.padding );
    const minX = uiNode.bounds.getMinX() + pad;
    const maxX = uiNode.bounds.getMaxX() - pad;
    const width = @max( 1.0, maxX - minX );
    const t = utl.clmp(( mousePos.x - minX ) / width, 0.0, 1.0 );

    return self.clampSliderValue( uiNode, utl.lerp( uiNode.sliderMin, uiNode.sliderMax, t ));
  }

  fn clampSliderValue( self : *const UiContext, uiNode : *const UiNode, value : f64 ) f64
  {
    _ = self;

    const minValue = @min( uiNode.sliderMin, uiNode.sliderMax );
    const maxValue = @max( uiNode.sliderMin, uiNode.sliderMax );

    if( utl.isFltEq( minValue, maxValue )){ return minValue; }

    var out = utl.clmp( value, minValue, maxValue );
    if( uiNode.sliderStep > 0.0 )
    {
      out = minValue + ( @round(( out - minValue ) / uiNode.sliderStep ) * uiNode.sliderStep );
      out = utl.clmp( out, minValue, maxValue );
    }

    return out;
  }

  /// Closes transient nodes when a click lands outside them and outside their descendants.
  fn closeOutsideTransients( self : *UiContext, mousePos : utl.Vec2, hoveredId : UiId ) void
  {
    const activeModal = self.findActiveModal();

    // Close from front to back so nested transient menus disappear before their owners.
    var i = self.nodes.items.len;
    while( i > 0 )
    {
      i -= 1;

      const uiNode = &self.nodes.items[ i ];
      if( !uiNode.isAlive or !uiNode.isVisible     ){ continue; }
      if( !uiNode.closeOnOutside                   ){ continue; }
      // A modal only permits outside-close checks inside its own subtree.
      if( activeModal.isValid() and !self.isDescOrSelf( uiNode.id, activeModal )){ continue; }
      if( uiNode.bounds.isOnPoint( mousePos )      ){ continue; }
      if( self.isDescOrSelf( hoveredId, uiNode.id )){ continue; }

      const id = uiNode.id;
      self.closeNode( id );
    }
  }

  /// Closes the frontmost node that opted into Escape dismissal.
  fn closeTopEscapeNode( self : *UiContext ) bool
  {
    // Escape should affect the frontmost eligible popup/window first.
    var i = self.nodes.items.len;
    while( i > 0 )
    {
      i -= 1;

      const uiNode = &self.nodes.items[ i ];
      if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
      if( !uiNode.closeOnEscape ){ continue; }

      const id = uiNode.id;
      self.closeNode( id );
      return true;
    }

    return false;
  }

  /// Applies a node's built-in action and queues the matching event.
  fn triggerNode( self : *UiContext, id : UiId ) void
  {
    const uiNode = self.getNodePtr( id ) orelse return;
    if( !uiNode.isActionable() ){ return; }

    switch( uiNode.kind )
    {
      .button =>
      {
        self.pushEvent( .{ .eType = .clicked, .node = id, .valueBool = uiNode.valueBool });
      },

      .checkbox =>
      {
        uiNode.valueBool = !uiNode.valueBool;
        self.pushEvent( .{ .eType = .changed, .node = id, .valueBool = uiNode.valueBool });
      },

      else => {},
    }
  }

  fn hasModalNode( self : *const UiContext ) bool
  {
    return self.findActiveModal().isValid();
  }

  /// Checks parent links only; dependency links do not make descendants.
  fn isDescOrSelf( self : *const UiContext, child : UiId, ancestor : UiId ) bool
  {
    if( !child.isValid() or !ancestor.isValid() ){ return false; }
    if( child.isEq( ancestor )){ return true; }

    var cursor = child;
    while( self.getNode( cursor ))| uiNode |
    {
      if( !uiNode.parent.isValid()       ){ return false; }
      if(  uiNode.parent.isEq( ancestor )){ return true;  }

      cursor = uiNode.parent;
    }

    return false;
  }

  /// Checks whether this node and all parents are visible.
  fn isVisibleInTree( self : *const UiContext, id : UiId ) bool
  {
    var cursor = id;
    while( self.getNode( cursor ))| uiNode |
    {
      if( !uiNode.isVisible        ){ return false; }
      if( !uiNode.parent.isValid() ){ return true;  }

      cursor = uiNode.parent;
    }

    return false;
  }


  // ================================ RENDERING ================================

  /// Draws all visible screen-space UI nodes by layer, preserving storage order within each layer.
  pub fn drawScreen( self : *UiContext ) void
  {
    if( !self.isInit ){ return; }

    self.clipDepth = 0;

    for( 0..UiLayer.count )| layerIdx |
    {
      const layer = UiLayer.fromIndex( layerIdx );

      for( self.nodes.items )| *uiNode |
      {
        if( uiNode.layer != layer ){ continue; }
        if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
        if( !self.isVisibleInTree( uiNode.id )){ continue; }

        self.drawNodeClipped( uiNode );
      }
    }

    if( self.debugOverlayEnabled ){ self.drawDebugOverlay(); }
    self.drawTooltip();

    while( self.clipDepth > 0 ){ self.endClip(); }
  }

  fn drawNodeClipped( self : *UiContext, uiNode : *const UiNode ) void
  {
    if( self.getAncestorClipBox( uiNode.id ))| clipBox |
    {
      if( !uiNode.bounds.doesOverlap( clipBox )){ return; }
      if( self.beginClip( clipBox ))
      {
        self.drawNode( uiNode );
        self.endClip();
      }

      return;
    }

    if( self.hasClipAncestor( uiNode.id )){ return; }
    self.drawNode( uiNode );
  }

  fn getAncestorClipBox( self : *const UiContext, id : UiId ) ?utl.Box2
  {
    var cursor = id;
    var clipBox : ?utl.Box2 = null;

    while( self.getNode( cursor ))| uiNode |
    {
      if( !uiNode.parent.isValid() ){ break; }

      const parent = self.getNode( uiNode.parent ) orelse break;
      if( parent.isScrollArea() )
      {
        clipBox = if( clipBox )| oldClip | intersectBoxes( oldClip, parent.bounds ) else parent.bounds;
        if( clipBox == null ){ return null; }
      }

      cursor = uiNode.parent;
    }

    return clipBox;
  }

  fn hasClipAncestor( self : *const UiContext, id : UiId ) bool
  {
    var cursor = id;
    while( self.getNode( cursor ))| uiNode |
    {
      if( !uiNode.parent.isValid() ){ return false; }

      const parent = self.getNode( uiNode.parent ) orelse return false;
      if( parent.isScrollArea() ){ return true; }

      cursor = uiNode.parent;
    }

    return false;
  }

  fn beginClip( self : *UiContext, box : utl.Box2 ) bool
  {
    if( self.clipDepth >= self.clipStack.len )
    {
      utl.qlog( .WARN, 0, @src(), "UI clip stack overflow" );
      return false;
    }

    const clipped = if( self.clipDepth > 0 )
      intersectBoxes( self.clipStack[ self.clipDepth - 1 ], box ) orelse return false
    else
      box;

    if( clipped.getSizeX() <= 0.0 or clipped.getSizeY() <= 0.0 ){ return false; }

    self.clipStack[ self.clipDepth ] = clipped;
    self.clipDepth += 1;
    applyClipBox( clipped );
    return true;
  }

  fn endClip( self : *UiContext ) void
  {
    if( self.clipDepth == 0 ){ return; }

    utl.ray.endScissorMode();
    self.clipDepth -= 1;

    if( self.clipDepth > 0 ){ applyClipBox( self.clipStack[ self.clipDepth - 1 ] ); }
  }

  fn applyClipBox( box : utl.Box2 ) void
  {
    const topLeft = box.getTopLeft();
    const size    = box.getSize();

    utl.ray.beginScissorMode(
      roundToI32( topLeft.x ),
      roundToI32( topLeft.y ),
      roundToI32( @max( 1.0, size.x )),
      roundToI32( @max( 1.0, size.y ))
    );
  }

  fn roundToI32( value : f64 ) i32
  {
    return @intFromFloat( @round( value ));
  }

  fn intersectBoxes( a : utl.Box2, b : utl.Box2 ) ?utl.Box2
  {
    if( !a.doesOverlap( b )){ return null; }

    const min = utl.Vec2.new( @max( a.getMinX(), b.getMinX() ), @max( a.getMinY(), b.getMinY() ));
    const max = utl.Vec2.new( @min( a.getMaxX(), b.getMaxX() ), @min( a.getMaxY(), b.getMaxY() ));
    const size = max.sub( min );

    if( size.x <= 0.0 or size.y <= 0.0 ){ return null; }

    return boxFromTopLeft( min, size );
  }

  fn drawNode( self : *UiContext, uiNode : *const UiNode ) void
  {
    _ = self;

    switch( uiNode.kind )
    {
      .label =>
      {
        drawTextLeft(
          uiNode.getText(),
          .new( uiNode.bounds.getMinX(), uiNode.bounds.center.y ),
          uiNode.style.fontSize,
          uiNode.style.textCol
        );
      },

      .checkbox => drawCheckbox( uiNode ),
      .slider   => drawSlider( uiNode ),

      .button =>
      {
        drawBox(
          uiNode.bounds,
          uiNode.style.fillForState( uiNode.isHovered, uiNode.isPressed ),
          if( uiNode.isFocused ) uiNode.style.edgeFocusCol else uiNode.style.edgeCol,
          uiNode.style.lineWidth
        );

        drawTextCenter( uiNode.getText(), uiNode.bounds.center, uiNode.style.fontSize, uiNode.style.textCol );
      },

      else =>
      {
        drawBox(
          uiNode.bounds,
          uiNode.style.fillForState( uiNode.isHovered, uiNode.isPressed ),
          if( uiNode.isFocused ) uiNode.style.edgeFocusCol else uiNode.style.edgeCol,
          uiNode.style.lineWidth
        );

        if( uiNode.textLen > 0 )
        {
          const topLeft = uiNode.bounds.getTopLeft();
          drawTextLeft(
            uiNode.getText(),
            .new( topLeft.x + uiNode.padding, topLeft.y + uiNode.padding + ( uiNode.style.fontSize * 0.5 ) ),
            uiNode.style.fontSize,
            uiNode.style.textCol
          );
        }
      },
    }
  }

  fn drawSlider( uiNode : *const UiNode ) void
  {
    drawBox(
      uiNode.bounds,
      uiNode.style.fillForState( uiNode.isHovered, uiNode.isPressed ),
      if( uiNode.isFocused ) uiNode.style.edgeFocusCol else uiNode.style.edgeCol,
      uiNode.style.lineWidth
    );

    const pad  = @max( 8.0, uiNode.padding );
    const minX = uiNode.bounds.getMinX() + pad;
    const maxX = uiNode.bounds.getMaxX() - pad;
    const width = @max( 1.0, maxX - minX );
    const minValue = @min( uiNode.sliderMin, uiNode.sliderMax );
    const maxValue = @max( uiNode.sliderMin, uiNode.sliderMax );
    const denom = @max( utl.EPS, maxValue - minValue );
    const t = utl.clmp(( uiNode.valueFlt - minValue ) / denom, 0.0, 1.0 );

    const trackHeight = 6.0;
    const trackBox = boxFromTopLeft(
      .new( minX, uiNode.bounds.center.y - ( trackHeight * 0.5 )),
      .new( width, trackHeight )
    );

    drawBox( trackBox, utl.Colour.dGray, utl.Colour.transpa, 0.0 );

    const fillWidth = @max( 1.0, width * t );
    const fillBox = boxFromTopLeft(
      .new( minX, uiNode.bounds.center.y - ( trackHeight * 0.5 )),
      .new( fillWidth, trackHeight )
    );

    drawBox( fillBox, uiNode.style.accentCol, utl.Colour.transpa, 0.0 );

    const handleWidth  = 12.0;
    const handleHeight = @min( uiNode.bounds.getSizeY() - 8.0, 24.0 );
    const handleX = minX + ( width * t ) - ( handleWidth * 0.5 );
    const handleBox = boxFromTopLeft(
      .new( handleX, uiNode.bounds.center.y - ( handleHeight * 0.5 )),
      .new( handleWidth, handleHeight )
    );

    drawBox( handleBox, utl.Colour.nWhite, uiNode.style.edgeCol, 1.0 );

    if( uiNode.textLen > 0 )
    {
      drawTextLeft(
        uiNode.getText(),
        .new( uiNode.bounds.getMinX() + pad, uiNode.bounds.getMinY() + uiNode.style.fontSize ),
        uiNode.style.fontSize,
        uiNode.style.textCol
      );
    }
  }

  fn drawTooltip( self : *UiContext ) void
  {
    if( !self.tooltipHoverReady ){ return; }

    const hoveredNode = self.getNode( self.hovered ) orelse return;
    if( hoveredNode.tooltipLen == 0 ){ return; }

    const tooltipText = hoveredNode.getTooltip();
    const fontSize = 14.0;
    const padding  = 8.0;
    const textWidth = @max( 80.0, @as( f64, @floatFromInt( tooltipText.len )) * fontSize * 0.56 );
    const size = utl.Vec2.new( textWidth + ( padding * 2.0 ), fontSize + ( padding * 2.0 ));

    var box = boxFromTopLeft( self.input.mousePos.add( .new( 14.0, 18.0 )), size );
    box.clampInArea( .{}, utl.getScreenSize() );

    drawBox( box, utl.Colour.nBlack.setA( 245 ), utl.Colour.pGold, 1.0 );
    drawTextLeft(
      tooltipText,
      .new( box.getMinX() + padding, box.center.y ),
      fontSize,
      utl.Colour.nWhite
    );
  }

  fn drawDebugOverlay( self : *UiContext ) void
  {
    if( self.debugOverlayBounds ){ self.drawDebugBounds(); }

    const size = utl.Vec2.new( 286.0, 178.0 );
    var box = boxFromTopLeft( .new( utl.getScreenWidth() - size.x - 18.0, 18.0 ), size );
    box.clampInArea( .{}, utl.getScreenSize() );

    drawBox( box, utl.Colour.nBlack.setA( 218 ), utl.Colour.pTeal, 1.0 );

    var pos = box.getTopLeft().add( .new( 10.0, 18.0 ));
    const lineH = 17.0;
    const textCol = utl.Colour.nWhite;

    drawTextLeft( "UI debug", pos, 15.0, utl.Colour.pTeal ); pos.y += lineH;
    drawTextLeftFmt( "nodes: {d} live:{d} events:{d}", .{ self.nodes.items.len, self.getLiveNodeCount(), self.getEventCount() }, pos, 13.0, textCol ); pos.y += lineH;
    drawTextLeftFmt( "hover: {s}", .{ self.getNodeKindName( self.hovered ) }, pos, 13.0, textCol ); pos.y += lineH;
    drawTextLeftFmt( "focus: {s}", .{ self.getNodeKindName( self.focused ) }, pos, 13.0, textCol ); pos.y += lineH;
    drawTextLeftFmt( "pressed: {s}", .{ self.getNodeKindName( self.pressed ) }, pos, 13.0, textCol ); pos.y += lineH;
    drawTextLeftFmt( "wants mouse:{s} key:{s}", .{ if( self.wantsMouse() ) "yes" else "no", if( self.wantsKeyboard() ) "yes" else "no" }, pos, 13.0, textCol ); pos.y += lineH;
    drawTextLeftFmt( "modal: {s}", .{ self.getNodeKindName( self.findActiveModal() ) }, pos, 13.0, textCol ); pos.y += lineH;
  }

  fn getLiveNodeCount( self : *const UiContext ) usize
  {
    var count : usize = 0;

    for( self.nodes.items )| *uiNode |
    {
      if( uiNode.isAlive ){ count += 1; }
    }

    return count;
  }

  fn drawDebugBounds( self : *UiContext ) void
  {
    for( self.nodes.items )| *uiNode |
    {
      if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
      if( !self.isVisibleInTree( uiNode.id )){ continue; }

      drawBox( uiNode.bounds, utl.Colour.transpa, layerDebugColor( uiNode.layer ), 1.0 );
    }
  }

  fn layerDebugColor( layer : UiLayer ) utl.Colour
  {
    return switch( layer )
    {
      .hud     => utl.Colour.lGray,
      .panel   => utl.Colour.pTeal,
      .popup   => utl.Colour.pGold,
      .modal   => utl.Colour.pOrange,
      .tooltip => utl.Colour.nWhite,
    };
  }

  fn drawCheckbox( uiNode : *const UiNode ) void
  {
    drawBox(
      uiNode.bounds,
      uiNode.style.fillForState( uiNode.isHovered, uiNode.isPressed ),
      if( uiNode.isFocused ) uiNode.style.edgeFocusCol else uiNode.style.edgeCol,
      uiNode.style.lineWidth
    );

    const topLeft = uiNode.bounds.getTopLeft();
    const markSize = @min( 18.0, uiNode.bounds.scale.y * 1.25 );
    const markBox = boxFromTopLeft(
      .new( topLeft.x + uiNode.padding, uiNode.bounds.center.y - ( markSize * 0.5 )),
      .new( markSize, markSize )
    );

    drawBox( markBox, utl.Colour.black, uiNode.style.edgeCol, 1.0 );

    if( uiNode.valueBool )
    {
      const innerTopLeft = markBox.getTopLeft().add( .new( 4.0, 4.0 ));
      utl.sDraw.basicRect( innerTopLeft, .new( markSize - 8.0, markSize - 8.0 ), uiNode.style.accentCol );
    }

    drawTextLeft(
      uiNode.getText(),
      .new( topLeft.x + uiNode.padding + markSize + 10.0, uiNode.bounds.center.y ),
      uiNode.style.fontSize,
      uiNode.style.textCol
    );
  }

  fn drawBox( box : utl.Box2, fillCol : utl.Colour, edgeCol : utl.Colour, lineWidth : f64 ) void
  {
    const topLeft = box.getTopLeft();
    const size    = boxSize( box );

    utl.sDraw.basicRect(      topLeft, size, fillCol );
    if( lineWidth > 0.0 ){ utl.sDraw.basicRectPerim( topLeft, size, edgeCol, lineWidth ); }
  }

  fn drawTextLeft( str : []const u8, pos : utl.Vec2, fontSize : f64, col : utl.Colour ) void
  {
    var buf : [ 256 ]u8 = undefined;
    const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return;

    utl.sDraw.textLeft( zStr, pos, fontSize, col );
  }

  fn drawTextCenter( str : []const u8, pos : utl.Vec2, fontSize : f64, col : utl.Colour ) void
  {
    var buf : [ 256 ]u8 = undefined;
    const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return;

    utl.sDraw.textCenter( zStr, pos, fontSize, col );
  }

  fn drawTextLeftFmt( comptime fmt : []const u8, args : anytype, pos : utl.Vec2, fontSize : f64, col : utl.Colour ) void
  {
    var buf : [ 256 ]u8 = undefined;
    const str = std.fmt.bufPrint( &buf, fmt, args ) catch return;

    drawTextLeft( str, pos, fontSize, col );
  }
};

pub const UiManager = UiContext;
