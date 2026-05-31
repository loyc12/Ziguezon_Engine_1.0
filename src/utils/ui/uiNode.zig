const std   = @import( "std" );
const def   = @import( "defs" );
const types = @import( "uiTypes.zig" );

const UiId       = types.UiId;
const UiNodeKind = types.UiNodeKind;
const UiLayer    = types.UiLayer;
const UiLayout   = types.UiLayout;
const UiStyle    = types.UiStyle;
const UiNodeOpts = types.UiNodeOpts;


// ================================ UI NODE ================================

pub const UiNode = struct
{
  pub const textBufLen : usize = 128;
  pub const tooltipBufLen : usize = 160;

  id  : UiId = .{},
  gen : u32  = 0,

  kind      : UiNodeKind = .panel,
  parent    : UiId       = .{},
  dependsOn : UiId       = .{},

  localBox    : def.Box2 = .{},
  bounds      : def.Box2 = .{},
  desiredSize : def.Vec2 = .new( 160.0, 30.0 ),

  layout  : UiLayout = .absolute,
  layer   : UiLayer  = .panel,
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
  valueFlt  : f64     = 0.0,

  sliderMin  : f64 = 0.0,
  sliderMax  : f64 = 1.0,
  sliderStep : f64 = 0.0,

  scrollY             : f64 = 0.0,
  scrollContentHeight : f64 = 0.0,

  style     : UiStyle = .{},

  text    : [ textBufLen ]u8 = [_]u8{ 0 } ** textBufLen,
  textLen : usize            = 0,

  tooltip    : [ tooltipBufLen ]u8 = [_]u8{ 0 } ** tooltipBufLen,
  tooltipLen : usize               = 0,


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
      .layer       = if( opts.layer )| layer | layer else UiLayer.defaultFor( kind, opts.isModal ),
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
      .valueFlt  = opts.valueFlt,

      .sliderMin  = opts.sliderMin,
      .sliderMax  = opts.sliderMax,
      .sliderStep = opts.sliderStep,

      .scrollY = opts.scrollY,

      .style     = if( opts.style )| style | style else UiStyle.forKind( kind ),
    };

    node.setText( opts.text );
    node.setTooltip( opts.tooltip );
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

  pub fn setTooltip( self : *UiNode, str : []const u8 ) void
  {
    const len = @min( str.len, self.tooltip.len );

    if( len > 0                ){ @memcpy( self.tooltip[ 0..len ], str[ 0..len ] ); }
    if( len < self.tooltip.len ){ @memset( self.tooltip[ len..  ], 0             ); }

    self.tooltipLen = len;
  }

  pub inline fn getTooltip( self : *const UiNode ) []const u8
  {
    return self.tooltip[ 0..self.tooltipLen ];
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

  pub inline fn isSlider( self : *const UiNode ) bool
  {
    return self.kind == .slider;
  }

  pub inline fn isScrollArea( self : *const UiNode ) bool
  {
    return self.kind == .scrollArea;
  }
};
