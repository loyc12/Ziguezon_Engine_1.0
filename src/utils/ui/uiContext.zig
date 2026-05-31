const std   = @import( "std" );
const def   = @import( "defs" );
const input = @import( "uiInput.zig" );
const node  = @import( "uiNode.zig" );
const types = @import( "uiTypes.zig" );

pub const UiId        = types.UiId;
pub const UiNodeKind  = types.UiNodeKind;
pub const UiLayout    = types.UiLayout;
pub const UiEventType = types.UiEventType;
pub const UiEvent     = types.UiEvent;
pub const UiStyle     = types.UiStyle;
pub const UiNodeOpts  = types.UiNodeOpts;
pub const UiInput     = input.UiInput;

pub const boxFromTopLeft = types.boxFromTopLeft;
pub const boxSize        = types.boxSize;

const UiNode  = node.UiNode;


// ================================ UI CONTEXT ================================

pub const UiContext = struct
{
  alloc : std.mem.Allocator = undefined,

  nodes  : std.ArrayList( UiNode  ) = .empty,
  events : std.ArrayList( UiEvent ) = .empty,

  input : UiInput = .{},

  hovered : UiId = .{},
  pressed : UiId = .{},
  focused : UiId = .{},

  wantsMouseFlag    : bool = false,
  wantsKeyboardFlag : bool = false,

  isInit : bool = false,


  // ================================ INITIALIZATION ================================

  pub fn init( self : *UiContext, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Initializing UI manager..." );

    if( self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "UI manager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.nodes  = std.ArrayList( UiNode  ).empty;
    self.events = std.ArrayList( UiEvent ).empty;

    self.input   = .{};
    self.hovered = .{};
    self.pressed = .{};
    self.focused = .{};

    self.wantsMouseFlag    = false;
    self.wantsKeyboardFlag = false;

    self.isInit = true;
    def.qlog( .INFO, 0, @src(), "& UI manager initialized !" );
  }

  pub fn deinit( self : *UiContext ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Deinitializing UI manager..." );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "UI manager is uninitialized : returning" );
      return;
    }

    self.events.deinit( self.alloc );
    self.nodes.deinit(  self.alloc );

    self.input   = .{};
    self.hovered = .{};
    self.pressed = .{};
    self.focused = .{};

    self.wantsMouseFlag    = false;
    self.wantsKeyboardFlag = false;

    self.isInit = false;
    self.alloc  = undefined;

    def.qlog( .INFO, 0, @src(), "& UI manager deinitialized !" );
  }


  // ================================ FRAME LIFETIME ================================

  /// Reads this frame's raw input and clears transient hover/press rendering state.
  pub fn beginFrame( self : *UiContext ) void
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Failed to begin frame : UiContext uninitialized" );
      return;
    }

    self.input = UiInput.readRaylib();

    self.hovered = .{};
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
    if( self.getNodePtr( self.hovered ))| uiNode |{ uiNode.isHovered = true; }

    if( self.input.escapePressed )
    {
      if( self.closeTopEscapeNode() ){ self.wantsKeyboardFlag = true; }
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

      if( self.getNodePtr( oldPressed ))| uiNode |{ uiNode.isPressed = false; }

      if( oldPressed.isValid() )
      {
        self.wantsMouseFlag = true;

        if( oldPressed.isEq( self.hovered )){ self.triggerNode( oldPressed ); }
      }

      self.pressed = .{};
    }

    if( self.input.leftDown and self.pressed.isValid() ){ self.wantsMouseFlag = true; }
    if( self.input.mouseWheel != 0.0 and self.hovered.isValid() ){ self.wantsMouseFlag = true; }
    if( self.hovered.isValid() ){ self.wantsMouseFlag = true; }

    if( self.focused.isValid() ){ self.wantsKeyboardFlag = true; }
    if( self.hasModalNode() ){ self.wantsKeyboardFlag = true; }
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
      def.qlog( .WARN, 0, @src(), "Cannot create UI node : UI manager is uninitialized" );
      return null;
    }

    for( self.nodes.items, 0.. )| *slot, i |
    {
      if( slot.isAlive ){ continue; }

      // Bump generation so stale IDs from the previous occupant stop resolving.
      var gen = slot.gen +% 1;
      if( gen == 0 ){ gen = 1; }

      const id = UiId.fromIndexGen( @intCast( i ), gen );
      slot.* = UiNode.init( id, kind, opts );
      return id;
    }

    if( self.nodes.items.len >= @as( usize, UiId.invalidIndex ))
    {
      def.qlog( .ERROR, 0, @src(), "Cannot create UI node : node index limit reached" );
      return null;
    }

    const id = UiId.fromIndexGen( @intCast( self.nodes.items.len ), 1 );

    self.nodes.append( self.alloc, UiNode.init( id, kind, opts )) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to append UI node : {}", .{ err });
      return null;
    };

    return id;
  }

  pub inline fn createRoot(     self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .root,     opts ); }
  pub inline fn createPanel(    self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .panel,    opts ); }
  pub inline fn createLabel(    self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .label,    opts ); }
  pub inline fn createButton(   self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .button,   opts ); }
  pub inline fn createCheckbox( self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .checkbox, opts ); }
  pub inline fn createPopup(    self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .popup,    opts ); }
  pub inline fn createWindow(   self : *UiContext, opts : UiNodeOpts ) ?UiId { return self.createNode( .window,   opts ); }


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

  pub fn setBool( self : *UiContext, id : UiId, value : bool ) void
  {
    if( self.getNodePtr( id ))| uiNode |{ uiNode.valueBool = value; }
  }

  pub fn getBool( self : *const UiContext, id : UiId ) bool
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.valueBool; }
    return false;
  }

  pub fn setBox( self : *UiContext, id : UiId, box : def.Box2 ) void
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

  pub fn getParent( self : *const UiContext, id : UiId ) UiId
  {
    if( self.getNode( id ))| uiNode |{ return uiNode.parent; }
    return .{};
  }

  pub inline fn getHoveredId( self : *const UiContext ) UiId { return self.hovered; }
  pub inline fn getPressedId( self : *const UiContext ) UiId { return self.pressed; }
  pub inline fn getFocusedId( self : *const UiContext ) UiId { return self.focused; }

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
    {
      const uiNode = self.getNodePtr( id ) orelse return;

      valueBool = uiNode.valueBool;

      uiNode.isAlive   = false;
      uiNode.isVisible = false;
      uiNode.isHovered = false;
      uiNode.isPressed = false;
      uiNode.isFocused = false;
    }

    self.clearActiveRefs(   id );
    self.closeChildrenOf(   id );
    self.closeDependentsOf( id );

    self.pushEvent( .{ .eType = .closed, .node = id, .valueBool = valueBool });
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
      def.log( .ERROR, 0, @src(), "Failed to append UI event : {}", .{ err });
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
    const parent = self.getNode( parentId ) orelse return;

    const parentBounds = parent.bounds;
    const layout       = parent.layout;
    const padding      = parent.padding;
    const gap          = parent.gap;

    switch( layout )
    {
      .vertical =>
      {
        var topLeft = parentBounds.getTopLeft().add( .new( padding, padding ));
        const contentWidth = @max( 0.0, ( parentBounds.scale.x * 2.0 ) - ( padding * 2.0 ));

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
        var topLeft = parentBounds.getTopLeft().add( .new( padding, padding ));
        const contentHeight = @max( 0.0, ( parentBounds.scale.y * 2.0 ) - ( padding * 2.0 ));

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
        const parentTopLeft = parentBounds.getTopLeft();

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

  fn isLayoutChild( self : *const UiContext, child : UiId, parent : UiId ) bool
  {
    const uiNode = self.getNode( child ) orelse return false;
    if( !uiNode.isVisible ){ return false; }
    return uiNode.parent.isEq( parent );
  }


  // ================================ INPUT HELPERS ================================

  /// Finds the topmost pointer-capturing node under `mousePos`.
  fn findHovered( self : *const UiContext, mousePos : def.Vec2 ) UiId
  {
    // Later nodes are rendered later, so scan backward for topmost hit.
    var i = self.nodes.items.len;
    while( i > 0 )
    {
      i -= 1;

      const uiNode = &self.nodes.items[ i ];
      if( !uiNode.capturesPointer() ){ continue; }
      if( !self.isVisibleInTree( uiNode.id )){ continue; }
      if( !uiNode.bounds.isOnPoint( mousePos )){ continue; }

      return uiNode.id;
    }

    return .{};
  }

  /// Closes transient nodes when a click lands outside them and outside their descendants.
  fn closeOutsideTransients( self : *UiContext, mousePos : def.Vec2, hoveredId : UiId ) void
  {
    // Close from front to back so nested transient menus disappear before their owners.
    var i = self.nodes.items.len;
    while( i > 0 )
    {
      i -= 1;

      const uiNode = &self.nodes.items[ i ];
      if( !uiNode.isAlive or !uiNode.isVisible     ){ continue; }
      if( !uiNode.closeOnOutside                   ){ continue; }
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
    for( self.nodes.items )| *uiNode |
    {
      if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
      if( uiNode.isModal ){ return true; }
    }

    return false;
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

  /// Draws all visible screen-space UI nodes in storage order.
  pub fn drawScreen( self : *UiContext ) void
  {
    if( !self.isInit ){ return; }

    for( self.nodes.items )| *uiNode |
    {
      if( !uiNode.isAlive or !uiNode.isVisible ){ continue; }
      if( !self.isVisibleInTree( uiNode.id )){ continue; }

      self.drawNode( uiNode );
    }
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

    drawBox( markBox, def.Colour.black, uiNode.style.edgeCol, 1.0 );

    if( uiNode.valueBool )
    {
      const innerTopLeft = markBox.getTopLeft().add( .new( 4.0, 4.0 ));
      def.sDraw.basicRect( innerTopLeft, .new( markSize - 8.0, markSize - 8.0 ), uiNode.style.accentCol );
    }

    drawTextLeft(
      uiNode.getText(),
      .new( topLeft.x + uiNode.padding + markSize + 10.0, uiNode.bounds.center.y ),
      uiNode.style.fontSize,
      uiNode.style.textCol
    );
  }

  fn drawBox( box : def.Box2, fillCol : def.Colour, edgeCol : def.Colour, lineWidth : f64 ) void
  {
    const topLeft = box.getTopLeft();
    const size    = boxSize( box );

    def.sDraw.basicRect(      topLeft, size, fillCol );
    def.sDraw.basicRectPerim( topLeft, size, edgeCol, lineWidth );
  }

  fn drawTextLeft( str : []const u8, pos : def.Vec2, fontSize : f64, col : def.Colour ) void
  {
    var buf : [ 256 ]u8 = undefined;
    const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return;

    def.sDraw.textLeft( zStr, pos, fontSize, col );
  }

  fn drawTextCenter( str : []const u8, pos : def.Vec2, fontSize : f64, col : def.Colour ) void
  {
    var buf : [ 256 ]u8 = undefined;
    const zStr = std.fmt.bufPrintZ( &buf, "{s}", .{ str }) catch return;

    def.sDraw.textCenter( zStr, pos, fontSize, col );
  }
};

pub const UiManager = UiContext;
