const std = @import( "std" );
const def = @import( "defs" );

const CompTransform = @import( "entityTransform.zig" );
const CompCollide   = @import( "entityCollision.zig" );
const CompRender    = @import( "entityRender.zig" );

const Uuid     = def.uuid.Uuid;
const flagType = def.uuid.flagType;

pub const e_shape = enum
{
  NONE, // No shape defined ( will not be rendered )
  LINE, // Line ( from center to forward, scaled )
  RECT, // Square / Rectangle
  STAR, // Triangle Star ( two overlaping triangles, pointing along the y axis )
  DSTR, // Diamond Star  ( two overlaping diamong,   pointing along the y axis )
  ELLI, // Circle / Ellipse ( aproximated via a high facet count polygon )

  TRIA, // Triangle ( equilateral, pointing towards -y ( up ))
  DIAM, // Square / Diamond ( rhombus )
  PENT, // Pentagon  ( regular )
  HEXA, // Hexagon   ( regular )
  OCTA, // Octagon   ( regular )
  DODE, // Dodecagon ( regular )
};

pub const entity2 = struct
{
  uuid      : Uuid = Uuid.getNullUuid(),
  transform : ?CompTransform = null,
  collide   : ?CompCollide   = null,
  render    : ?CompRender    = null,


  // ================ INITIALIZATION FUNCTIONS ================

  pub inline fn initWithDefaults() entity2 { return initWithFlags( flagType.ACTIVE | flagType.MOBILE | flagType.COLLIDE | flagType.RENDER ); }

  pub fn initWithFlags( flags : u12 ) ?entity2
  {
    def.qlog( .TRACE, 0, @src(), "Attempting to initialize an entity via flags " );

    if( Uuid.getNewUUID( flags ))| val |
    {
      def.log( .DEBUG, 0, @src(), "Creating new entity with ID {d} and flags {x}", .{ val.getId(), flags } );
      return .{
        .uuid      = val,
        .transform = if( val.getFlag( .MOBILE  )) CompTransform.init() else null,
        .collide   = if( val.getFlag( .COLLIDE )) CompCollide.init()   else null,
        .render    = if( val.getFlag( .RENDER  )) CompRender.init()    else null,
      };
    }
    else
    {
      def.qlog( .ERROR, 0, @src(), "Failed to create a new entity UUID : aborting entity initialization" );
      return null;
    }
  }

  pub inline fn initFromCopy( other : *const entity2 ) ?entity2
  {
    def.log( .TRACE, 0, @src(), "Attempting to copy existing entity with ID {d}", .{ other.uuid.getId() });

    if( Uuid.getNewUUID( other.uuid.getAllFlags() )) | val |
    {
      def.log( .DEBUG, 0, @src(), "Creating new entity from copy with ID {d} and flags {x}", .{ val.getId(), other.uuid.getAllFlags() });
      return
      .{
        .uuid      =     val,
        .transform = if( val.getComponent( .MOBILE  ))| *t | *t else null,
        .collide   = if( val.getComponent( .COLLIDE ))| *c | *c else null,
        .render    = if( val.getComponent( .RENDER  ))| *r | *r else null,
      };
    }
    else
    {
      def.qlog( .ERROR, 0, @src(), "Failed to create a new entity UUID from copy" );
      return null;
    }
  }


  // ================ COMPONENT ACCESSORS ================

  pub fn getComponent( self : *const entity2, comp : def.uuid.flagType ) ?*anyopaque
  {
    def.log( .TRACE, 0, @src(), "Getting component of type {s} for entity {d}", .{ @tagName( comp ), self.uuid.getId() });

    switch( comp )
    {
      .MOBILE  => if( self.transform )| *t | return t else null,
      .COLLIDE => if( self.collide   )| *c | return c else null,
      .RENDER  => if( self.render    )| *r | return r else null,

      else =>
      {
        def.log( .ERROR, 0, @src(), "No component associated with flagType {s} for entity {d}", .{ @tagName( comp ), self.uuid.getId() });
        return null;
      }
    }
  }

  pub inline fn hasComponent( self : *const entity2, comp : def.uuid.flagType ) bool
  {
    return switch( comp )
    {
      .MOBILE  => self.transform != null,
      .COLLIDE => self.collide   != null,
      .RENDER  => self.render    != null,
      else     => false,
    };
  }

  pub inline fn getTransform( self: *const entity2 ) ?*CompTransform { return if( self.transform )| *t | t else null; }
  pub inline fn getCollide(   self: *const entity2 ) ?*CompCollide   { return if( self.collide   )| *c | c else null; }
  pub inline fn getRender(    self: *const entity2 ) ?*CompRender    { return if( self.render    )| *r | r else null; }

  pub inline fn setTransform( self: *entity2, transform: ?CompTransform ) void
  {
    if( transform ){ self.transform = transform; }
    else{            self.transform = null;      }
  }
  pub inline fn setCollide( self: *entity2, collide: ?CompCollide ) void
  {
    if( collide ){ self.collide = collide; }
    else{        self.collide = null;      }
  }
  pub inline fn setRender( self: *entity2, render: ?CompRender ) void
  {
    if( render ){ self.render = render; }
    else{         self.render = null;   }
  }
};



