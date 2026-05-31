const std   = @import( "std" );
const def   = @import( "defs" );
const types = @import( "uiTypes.zig" );

const UiId       = types.UiId;
const UiNodeKind = types.UiNodeKind;
const UiLayout   = types.UiLayout;
const UiStyle    = types.UiStyle;
const UiNodeOpts = types.UiNodeOpts;


// ================================ UI NODE ================================

pub const UiNode = struct
{
  pub const textBufLen : usize = 128;

  id  : UiId = .{},
  gen : u32  = 0,

  kind      : UiNodeKind = .panel,
  parent    : UiId       = .{},
  dependsOn : UiId       = .{},

  localBox    : def.Box2 = .{},
  bounds      : def.Box2 = .{},
  desiredSize : def.Vec2 = .new( 160.0, 30.0 ),

  layout  : UiLayout = .absolute,
  padding : f64      = 8.0,
  gap     : f64      = 6.0,

  isAlive        : bool = false,
  isVisible      : bool = true,
  isEnabled      : bool = true,
  isHovered      : bool = false,
  isPressed      : bool = false,
  isFocused      : bool = false,
  isModal        : bool = false,
  isDetachedRoot : bool = false,

  closeOnOutside : bool = false,
  closeOnEscape  : bool = false,

  valueBool : bool    = false,
  style     : UiStyle = .{},

  text    : [ textBufLen ]u8 = [_]u8{ 0 } ** textBufLen,
  textLen : usize            = 0,


  // ================================ CREATION ================================

  pub fn init( id : UiId, kind : UiNodeKind, opts : UiNodeOpts ) UiNode
  {
    var node : UiNode = .{
      .id          = id,
      .gen         = id.gen,
      .kind        = kind,
      .parent      = if( opts.parent    )| parent | parent else .{},
      .dependsOn   = if( opts.dependsOn )| dep    | dep    else .{},

      .localBox    = opts.box,
      .bounds      = opts.box,
      .desiredSize = opts.desiredSize,

      .layout      = opts.layout,
      .padding     = opts.padding,
      .gap         = opts.gap,

      .isAlive        = true,
      .isVisible      = opts.isVisible,
      .isEnabled      = opts.isEnabled,
      .isModal        = opts.isModal,
      .isDetachedRoot = opts.isDetachedRoot,

      .closeOnOutside = opts.closeOnOutside,
      .closeOnEscape  = opts.closeOnEscape,

      .valueBool = opts.valueBool,
      .style     = if( opts.style )| style | style else UiStyle.forKind( kind ),
    };

    node.setText( opts.text );
    return node;
  }


  // ================================ TEXT ================================

  /// Stores a truncated copy of `str` in the node-owned fixed text buffer.
  pub fn setText( self : *UiNode, str : []const u8 ) void
  {
    const len = @min( str.len, self.text.len );

    if( len > 0             ){ @memcpy( self.text[ 0..len ], str[ 0..len ] ); }
    if( len < self.text.len ){ @memset( self.text[ len..  ], 0             ); }

    self.textLen = len;
  }

  pub inline fn getText( self : *const UiNode ) []const u8
  {
    return self.text[ 0..self.textLen ];
  }


  // ================================ FLAGS ================================

  /// True when this node is alive and directly visible; parent visibility is checked separately.
  pub inline fn isValid( self : *const UiNode ) bool
  {
    return self.isAlive and self.isVisible;
  }

  pub inline fn hasParent( self : *const UiNode ) bool
  {
    return self.parent.isValid();
  }

  pub inline fn capturesPointer( self : *const UiNode ) bool
  {
    return switch( self.kind )
    {
      .label => false,
      else   => self.isAlive and self.isVisible and self.isEnabled,
    };
  }

  pub inline fn isActionable( self : *const UiNode ) bool
  {
    return switch( self.kind )
    {
      .button, .checkbox => true,
      else               => false,
    };
  }
};
