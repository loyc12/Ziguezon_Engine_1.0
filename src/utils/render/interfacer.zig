const std  = @import( "std" );
const def  = @import( "defs" );

const Box2    = def.Box2;
const Vec2    = def.Vec2;
const VecA    = def.VecA;
const Angle   = def.Angle;

const drawer  = def.drwS_u;


pub const InterfaceShape = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  ELLI,  // Ellipse

  TRI_R, // Points right
  TRI_D, // Points down
  TRI_L, // Points left
  TRI_U, // Points up

  RECT,  // Flat side up
  DIAM,  // Pointy side up

  HEX_F, // Flat side up
  HEX_P, // Pointy side up

  OCT_F, // Flat side up
  OCT_P, // Pointy side up


  pub fn getCornerCount( self : InterfaceShape ) u8
  {
    return switch( self )
    {
      .ELLI                          => 0,
      .TRI_U, .TRI_D, .TRI_L, .TRI_R => 3,
      .RECT,  .DIAM                  => 4,
      .HEX_F, .HEX_P                 => 6,
      .OCT_F, .OCT_P                 => 8, // Max bevel count
    };
  }
};

pub const BevelType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  NONE,      // no cutout
  CUTOUT,    // Straight angle cuttout
  DIAGONAL,  // linear cutout ( chamfer )
  CURVE_OUT, // convex circular cutout
  CURVE_INT, // Concave circular cutout
};

const maxBevelCount = 8;
const BevelArray    = [ maxBevelCount ]BevelType;

fn getEmptyBevelArray() BevelArray { comptime return .{ .NONE, .NONE, .NONE, .NONE, .NONE, .NONE, .NONE, .NONE }; }


const VertexArray = [ maxBevelCount ]Vec2;

fn getEmptyVertexArray() VertexArray { comptime return .{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} }; }


// ================================ INTERFACER STRUCT ================================

pub const Interfacer2D = struct
{
  pos    : VecA,
  scale  : Vec2 = .new( 128, 128 ),
  layer  : u16  = 1,

  shape      : InterfaceShape = .RECT,
  fillCol    : def.Colour     = .nWhite,
  edgeCol    : def.Colour     = .nBlack,
  edgeWidth  : f64            = 1,

  bevelTypes : BevelArray     = getEmptyBevelArray(),
  bevelDepth : f64            = 8,

  shapeVerts1 : VertexArray   = getEmptyVertexArray(), // Outer corners
  bevelVerts1 : VertexArray   = getEmptyVertexArray(), // Bevel start point
  bevelVerts2 : VertexArray   = getEmptyVertexArray(), // Bevel end point
  shapeVerts2 : VertexArray   = getEmptyVertexArray(), // Inner corners

  isActive   : bool           = true,
  isSelected : bool           = false,



  pub inline fn getCornerCount( self : *const Interfacer2D ) u8 { return self.shape.getCornerCount(); }

  pub fn hasAnyBevel( self : *const Interfacer2D ) bool
  {
    if( self.bevelDepth < def.EPS ){ return false; }

    for( 0..self.shape.getCornerCount() )| b |
    {
      if( self.bevelTypes[ b ] != .NONE ){ return true; }
    }

    return false;
  }

  pub fn updateShapeVertices( self : *Interfacer2D ) void
  {
    if( self.shape == .ELLI ){ return; }

    const n      : u8  = self.shape.getCornerCount();
    const n_f    : f32 = @floatFromInt( n );
    const step_a : f32 = def.TAU / n_f; // Angle between each vertex, in radians

    const a0 = self.pos.a;              // Interface angle
    const p0 = self.pos.toVec2();       // Interface centerpoint

    var draw_a : f32  = 0.0;
    var draw_s : Vec2 = self.scale;

    // Adjust starting angle and scale based on shape variant
    switch( self.shape )
    {
      .TRI_D  => { draw_a = def.DtR(   90 ); },
      .TRI_L  => { draw_a = def.DtR(  180 ); },
      .TRI_U  => { draw_a = def.DtR(  270 ); },

      .RECT   =>
      {
        draw_a = def.DtR(   45 );
        draw_s = draw_s.mulVal( def.R2 );
      },

      .HEX_F  => { draw_a = def.DtR(   30 ); },
      .OCT_P  => { draw_a = def.DtR( 22.5 ); },

      else    => {},
    }

    // Compute outer vertices
    for( 0..n )| i |
    {
      const angle = a0.addRad( draw_a + ( step_a * @as( f32, @floatFromInt( i ))));

      self.shapeVerts1[ i ] = p0.add( .fromAngleScaled( angle, draw_s ));
    }

     // Compute other vertices if need be
    if( !self.hasAnyBevel())
    {
      for( 0..n )| i |
      {
        self.bevelVerts1[ i ] = self.shapeVerts1[ i ];
        self.bevelVerts2[ i ] = self.shapeVerts1[ i ];
        self.shapeVerts2[ i ] = self.shapeVerts1[ i ];
      }
    }
    else
    {
      for( 0..n )| i |
      {
        const iPrev = ( i + n - 1 ) % n;
        const iNext = ( i + 1     ) % n;

        const offsetA = self.shapeVerts1[ iPrev ].sub( self.shapeVerts1[ i ] ).normToLen( self.bevelDepth );
        const offsetB = self.shapeVerts1[ iNext ].sub( self.shapeVerts1[ i ] ).normToLen( self.bevelDepth );

        self.bevelVerts1[ i ] = self.shapeVerts1[ i ].add( offsetA );
        self.bevelVerts2[ i ] = self.shapeVerts1[ i ].add( offsetB );
        self.shapeVerts2[ i ] = self.shapeVerts1[ i ].add( offsetA ).add( offsetB );
      }
    }
  }

  pub fn drawSelf( self : *const Interfacer2D ) void
  {
    const p0 = self.pos.toVec2(); // Shape center pos
    const a0 = self.pos.a;        // Shape base angle

    // Ellipses cannot have bevels
    if( self.shape == .ELLI )
    {
      drawer.drawPolygonPlus(      p0, self.scale, a0, self.fillCol, def.G_ST.Graphic_Ellipse_Facets                 );
      drawer.drawPolygonLinesPlus( p0, self.scale, a0, self.edgeCol, def.G_ST.Graphic_Ellipse_Facets, self.edgeWidth );
      return;
    }

    const n : u8 = self.shape.getCornerCount();

    if( !self.hasAnyBevel() ) // No bevels: draw filled shape + outline from xcdddddddddddddddd-++outer verts
    {
      {
        const vec0 = self.shapeVerts1[ 0 ];
        var   vec1 = self.shapeVerts1[ 1 ];

        for( 2..n )| i |
        {
          const vec2 = self.shapeVerts1[ i ];

          drawer.drawBasicTria( vec0, vec2, vec1, self.fillCol );

          vec1 = vec2;
        }
      }
      {
        var vec1 = self.shapeVerts1[ n - 1 ];

        for( 0..n )| i |
        {
          const vec2 = self.shapeVerts1[ i ];

          drawer.drawLine( vec1, vec2, self.edgeCol, self.edgeWidth );

          vec1 = vec2;
        }
      }
      return;
    }
    // ================ ELSE ( if bevels ) ================

    // Draw inner filled shape
    {
      const vec0 = self.shapeVerts2[ 0 ];
      var   vec1 = self.shapeVerts2[ 1 ];

      for( 2..n )| i |
      {
        const vec2 = self.shapeVerts2[ i ];

        drawer.drawBasicTria( vec0, vec2, vec1, .red );

        vec1 = vec2;
      }
    }

    // Draw edge rect + line
    {
      for( 0..n )| iPrev |
      {
        const iNext = ( iPrev + 1 ) % n;

        const vec1 = self.bevelVerts2[ iPrev ]; // Edge's leftmost  outer corner
        const vec2 = self.shapeVerts2[ iPrev ]; // Edge's leftmost  inner corner
        const vec3 = self.shapeVerts2[ iNext ]; // Edge's rightmost inner corner
        const vec4 = self.bevelVerts1[ iNext ]; // Edge's rightmost outer corner

        drawer.drawBasicQuad( vec1, vec2, vec3, vec4, self.fillCol );
        drawer.drawLine( vec1, vec4, self.edgeCol, self.edgeWidth );
      }
    }

    // Draw bevels + line
    {
      for( 0..n )| i |
      {
        const vec1 = self.bevelVerts1[ i ]; // Bevel's left  corner
        const vec2 = self.shapeVerts2[ i ]; // Bevel's inner corner
        const vec3 = self.bevelVerts2[ i ]; // Bevel's right corner
        const vec4 = self.shapeVerts1[ i ]; // Bevel's outer corner

        switch( self.bevelTypes[ i ])
        {
          .NONE =>
          {
            drawer.drawBasicQuad( vec1, vec2, vec3, vec4, self.fillCol );
            drawer.drawLine( vec4, vec1, self.edgeCol, self.edgeWidth );
            drawer.drawLine( vec4, vec3, self.edgeCol, self.edgeWidth );
          },
          .CUTOUT =>
          {
            drawer.drawLine( vec2, vec1, self.edgeCol, self.edgeWidth );
            drawer.drawLine( vec2, vec3, self.edgeCol, self.edgeWidth );
          },
          .DIAGONAL =>
          {
            drawer.drawBasicTria( vec1, vec2, vec3, self.fillCol );
            drawer.drawLine( vec1, vec3, self.edgeCol, self.edgeWidth );
          },
          else => // TODO : draw inner and outer curved bevels
          {
            def.qlog( .ERROR, 0, @src(), "UNIMPLEMENTED" );
          }
        }
      }
    }
  }
};
