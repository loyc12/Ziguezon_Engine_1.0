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

  pub const maxCornerCount = 8;
};

pub const BevelType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  NONE,      // No cutout / bevelless

//CURVE_OUT, // Convex  circular cutout
  HALF_OUT,  // Concave triangular cutout

  DIAGONAL,  // Diagonal cutout ( chamfer )

  HALF_IN,   // Convex  triangular cutout
//CURVE_INT, // Concave circular cutout

  CUTOUT,    // Full cuttout


};

const BevelArray = [ InterfaceShape.maxCornerCount ]BevelType;

fn getEmptyBevelArray() BevelArray { comptime return .{ .NONE, .NONE, .NONE, .NONE, .NONE, .NONE, .NONE, .NONE }; }


const VertexArray = [ InterfaceShape.maxCornerCount ]Vec2;

fn getEmptyVertexArray() VertexArray { comptime return .{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} }; }


// ================================ INTERFACER STRUCT ================================

pub const Interfacer2D = struct
{

  pos    : VecA,
  scale  : Vec2 = .new( 128, 128 ),
  layer  : u16  = 1,

  shape      : InterfaceShape = .RECT,

  fillCol    : def.Colour     = .nWhite,
  edgeCol    : def.Colour     = .lGray,
  lineCol    : def.Colour     = .nBlack,

  lineWidth  : f64            = 1,
  edgeWidth  : f64            = 8,

  bevelTypes : BevelArray     = getEmptyBevelArray(),

  shapeVerts1 : VertexArray   = getEmptyVertexArray(), // Outer corners
  bevelVerts1 : VertexArray   = getEmptyVertexArray(), // Bevel start point
  bevelVerts2 : VertexArray   = getEmptyVertexArray(), // Bevel end point
  shapeVerts2 : VertexArray   = getEmptyVertexArray(), // Inner corners

  isActive   : bool           = true,
  isSelected : bool           = false,



  pub inline fn getCornerCount( self : *const Interfacer2D ) u8 { return self.shape.getCornerCount(); }

  pub fn hasAnyBevel( self : *const Interfacer2D ) bool
  {
    if( self.edgeWidth < def.EPS ){ return false; }

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
      const angle : Angle = .newRad( draw_a + ( step_a * @as( f32, @floatFromInt( i ))));

      const rPos = Vec2.fromAngleScaled( angle, draw_s ).rot( self.pos.a );

      self.shapeVerts1[ i ] = self.pos.toVec2().add( rPos );
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
      var edgeDirs  : [ InterfaceShape.maxCornerCount ]Vec2 = undefined;
      var edgeNorms : [ InterfaceShape.maxCornerCount ]Vec2 = undefined;

      // Precompute edge directions and normals (edge i ~~ shapeVerts1[ i ] -> shapeVerts1[ i + 1 ])
      for( 0..n )| i |
      {
        const iNext    = ( i + 1 ) % n;
        const dir      = self.shapeVerts1[ iNext ].sub( self.shapeVerts1[ i ] ).norm();

        edgeDirs[  i ] = dir;
        edgeNorms[ i ] = Vec2.new( dir.y, -dir.x );
      }

      // Inner corners + bevel vertices in a single pass
      for( 0..n )| i |
      {
        const iPrev = ( i + n - 1 ) % n;

        // Edge A (arriving): edge iPrev  ( iPrev -> i )
        // Edge B (leaving) : edge i      ( i -> iNext )
        const eA_dir  = edgeDirs[ iPrev ];
        const eA_norm = edgeNorms[ iPrev ];
        const eA_pt   = self.shapeVerts1[ iPrev ].sub( eA_norm.mulVal( self.edgeWidth ));

        const eB_dir  = edgeDirs[ i ];
        const eB_norm = edgeNorms[ i ];
        const eB_pt   = self.shapeVerts1[ i ].sub( eB_norm.mulVal( self.edgeWidth ));

        // Intersect inset edges to find inner corner
        const cross = eA_dir.x * eB_dir.y - eA_dir.y * eB_dir.x;

        const inner = if( @abs( cross ) < def.EPS )
          self.shapeVerts1[ i ].sub( eA_norm.mulVal( self.edgeWidth ))
        else blk:
        {
          const d = eB_pt.sub( eA_pt );
          const t = ( d.x * eB_dir.y - d.y * eB_dir.x ) / cross;
          break :blk eA_pt.add( eA_dir.mulVal( t ));
        };

        self.shapeVerts2[ i ] = inner;

        // Project inner corner perpendicularly onto the two outer edges meeting at corner i
        const toInner = inner.sub( self.shapeVerts1[ i ] );

        self.bevelVerts1[ i ] = self.shapeVerts1[ i ].add( eA_dir.mulVal( toInner.dot( eA_dir )));
        self.bevelVerts2[ i ] = self.shapeVerts1[ i ].add( eB_dir.mulVal( toInner.dot( eB_dir )));
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
      drawer.drawPolygonLinesPlus( p0, self.scale, a0, self.lineCol, def.G_ST.Graphic_Ellipse_Facets, self.lineWidth );
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

          drawer.drawLine( vec1, vec2, self.lineCol, self.lineWidth );

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

        drawer.drawBasicTria( vec0, vec2, vec1, self.fillCol );

        vec1 = vec2;
      }
    }

    // Draw edge rect + line
    {
      for( 0..n )| iPrev |
      {
        const iNext = ( iPrev + 1 ) % n;

        const vec1 = self.bevelVerts2[ iPrev ]; // Edge's leftmost  outer vertex
        const vec2 = self.shapeVerts2[ iPrev ]; // Edge's leftmost  inner vertex
        const vec3 = self.shapeVerts2[ iNext ]; // Edge's rightmost inner vertex
        const vec4 = self.bevelVerts1[ iNext ]; // Edge's rightmost outer vertex

        drawer.drawBasicQuad( vec1, vec2, vec3, vec4, self.edgeCol );
        drawer.drawLine( vec1, vec4, self.lineCol, self.lineWidth );
      }
    }

    // Draw bevels + line
    {
      for( 0..n )| i |
      {
        const vec1 = self.bevelVerts1[ i ]; // Corner's left  vertex
        const vec2 = self.shapeVerts2[ i ]; // Corner's inner vertex
        const vec3 = self.bevelVerts2[ i ]; // Corner's right vertex
        const vec4 = self.shapeVerts1[ i ]; // Corner's outer vertex

        switch( self.bevelTypes[ i ])
        {
          .NONE =>
          {
            drawer.drawBasicQuad( vec1, vec2, vec3, vec4, self.edgeCol );
            drawer.drawLine( vec4, vec1, self.lineCol, self.lineWidth );
            drawer.drawLine( vec4, vec3, self.lineCol, self.lineWidth );
          },

          .DIAGONAL =>
          {
            drawer.drawBasicTria( vec1, vec2, vec3, self.edgeCol );
            drawer.drawLine( vec1, vec3, self.lineCol, self.lineWidth );
          },
          .CUTOUT =>
          {
            drawer.drawLine( vec2, vec1, self.lineCol, self.lineWidth );
            drawer.drawLine( vec2, vec3, self.lineCol, self.lineWidth );
          },

          .HALF_IN =>
          {
            const vec5 = vec2.add( vec2 ).add( vec2 ).add( vec4 ).mulVal( 0.25 );

            drawer.drawBasicTria( vec1, vec2, vec5, self.edgeCol );
            drawer.drawBasicTria( vec2, vec3, vec5, self.edgeCol );
            drawer.drawLine( vec5, vec1, self.lineCol, self.lineWidth );
            drawer.drawLine( vec5, vec3, self.lineCol, self.lineWidth );
          },
          .HALF_OUT =>
          {
            const vec5 = vec2.add( vec4 ).add( vec4 ).add( vec4 ).mulVal( 0.25 );

            drawer.drawBasicTria( vec1, vec2, vec5, self.edgeCol );
            drawer.drawBasicTria( vec2, vec3, vec5, self.edgeCol );
            drawer.drawLine( vec5, vec1, self.lineCol, self.lineWidth );
            drawer.drawLine( vec5, vec3, self.lineCol, self.lineWidth );
          },

        //else => // TODO : draw inner and outer curved bevels
        //{
        //  def.qlog( .ERROR, 0, @src(), "UNIMPLEMENTED" );
        //}
        }
      }
    }
  }
};
