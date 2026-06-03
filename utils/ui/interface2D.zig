const std  = @import( "std" );
const eng  = @import( "engine" );
const utl = @import( "utils" );

const Box2    = utl.Box2;
const Vec2    = utl.Vec2;
const VecA    = utl.VecA;
const Angle   = utl.Angle;

const drawer  = utl.sDraw;


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

pub const BevelArray = [ InterfaceShape.maxCornerCount ]f64;

fn getEmptyBevelArray() BevelArray { comptime return [_]f64{ 1.0 } ** InterfaceShape.maxCornerCount; }

fn getBevelDir( strength : f64 ) i2
{
  if( strength >  utl.EPS ){ return  1; } // Standard bevel (  1.0 = squared  special case )
  if( strength < -utl.EPS ){ return -1; } // Inverted bevel ( -1.0 = diagonal special case )
  return 0;                               // No bevel ( cutout )
}


const VertexArray = [ InterfaceShape.maxCornerCount ]Vec2;

fn getEmptyVertexArray() VertexArray { comptime return [_]Vec2{ .{} } ** InterfaceShape.maxCornerCount; }


// ================================ INTERFACER STRUCT ================================

pub const Interface2D = struct
{
  pos   : VecA,
  scale : Vec2 = .new( 128, 128 ),
  layer : u16  = 1,

  shape : InterfaceShape = .RECT,

  isActive  : bool = true,
  isInit    : bool = false,

  lineWidth : f64 = 1,
  edgeWidth : f64 = 8,

  fillCol : utl.Colour = .nWhite,
  edgeCol : utl.Colour = .lGray,
  lineCol : utl.Colour = .nBlack,

  bevelStrength : BevelArray = getEmptyBevelArray(),

  bevelVertsO : VertexArray  = getEmptyVertexArray(), // Outer corners
  bevelVertsL : VertexArray  = getEmptyVertexArray(), // Bevel start point
  bevelVertsR : VertexArray  = getEmptyVertexArray(), // Bevel end point
  bevelVertsI : VertexArray  = getEmptyVertexArray(), // Inner corners

  pub inline fn setShape( self : *Interface2D, newShape : InterfaceShape ) void
  {
    if( self.shape != newShape ){ self.isInit = false; }

    self.shape = newShape;
  }

  pub inline fn setBevelStrength( self : *Interface2D, bevelIdx : usize, newStrength : f64 ) void
  {
    const oldBevelStrength = self.bevelStrength[ bevelIdx ];

    if( !utl.isFltEq( oldBevelStrength, newStrength )){ self.isInit = false; }

    self.bevelStrength[ bevelIdx ] = newStrength;
  }

  pub inline fn getCornerCount( self : *const Interface2D ) u8 { return self.shape.getCornerCount(); }

  pub fn hasAnyBevel( self : *const Interface2D ) bool
  {
    if( self.shape == .ELLI      ){ return false; }
    if( self.edgeWidth < utl.EPS ){ return false; }

    for( 0..self.shape.getCornerCount() )| b |
    {
      if( !utl.isFltEq( self.bevelStrength[ b ], 1.0 )){ return true; }
    }

    return false;
  }

  pub fn updateShapeVertices( self : *Interface2D ) void
  {
    if( self.shape == .ELLI )
    {
      self.isInit = true;
      return;
    }

    const n      : u8  = self.shape.getCornerCount();
    const n_f    : f32 = @floatFromInt( n );
    const step_a : f32 = utl.TAU / n_f; // Angle between each vertex, in radians

    var draw_a : f32  = 0.0;
    var draw_s : Vec2 = self.scale;

    // Adjust starting angle and scale based on shape variant
    switch( self.shape )
    {
      .TRI_D => { draw_a = utl.DtR(  90 ); },
      .TRI_L => { draw_a = utl.DtR( 180 ); },
      .TRI_U => { draw_a = utl.DtR( 270 ); },

      .RECT  =>
      {
        draw_a = utl.DtR( 45 );
        draw_s = draw_s.mulVal( utl.R2 );
      },

      .HEX_F => { draw_a = utl.DtR( 30   ); },
      .OCT_P => { draw_a = utl.DtR( 22.5 ); },

      else   => {},
    }

    // Compute outer vertices
    for( 0..n )| i |
    {
      const angle : Angle = .newRad( draw_a + ( step_a * @as( f32, @floatFromInt( i ))));

      const rPos = Vec2.fromAngleScaled( angle, draw_s ).rot( self.pos.a );

      self.bevelVertsO[ i ] = self.pos.toVec2().add( rPos );
    }

    // Compute other vertices
    {
      var edgeDirs  : [ InterfaceShape.maxCornerCount ]Vec2 = undefined;
      var edgeNorms : [ InterfaceShape.maxCornerCount ]Vec2 = undefined;

      // Precompute edge directions and normals (edge i ~~ shapeVerts1[ i ] -> shapeVerts1[ i + 1 ])
      for( 0..n )| i |
      {
        const iNext    = ( i + 1 ) % n;
        const dir      = self.bevelVertsO[ iNext ].sub( self.bevelVertsO[ i ] ).norm();

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
        const eA_pt   = self.bevelVertsO[ iPrev ].sub( eA_norm.mulVal( self.edgeWidth ));

        const eB_dir  = edgeDirs[ i ];
        const eB_norm = edgeNorms[ i ];
        const eB_pt   = self.bevelVertsO[ i ].sub( eB_norm.mulVal( self.edgeWidth ));

        // Intersect inset edges to find inner corner
        const cross = eA_dir.x * eB_dir.y - eA_dir.y * eB_dir.x;

        const inner = if( utl.isFltZr( cross )) self.bevelVertsO[ i ].sub( eA_norm.mulVal( self.edgeWidth ))
        else blk:
        {
          const d = eB_pt.sub( eA_pt );
          const t = ( d.x * eB_dir.y - d.y * eB_dir.x ) / cross;
          break :blk eA_pt.add( eA_dir.mulVal( t ));
        };

        self.bevelVertsI[ i ] = inner;

        // Project inner corner perpendicularly onto the two outer edges meeting at corner i
        const toInner = inner.sub( self.bevelVertsO[ i ] );

        self.bevelVertsL[ i ] = self.bevelVertsO[ i ].add( eA_dir.mulVal( toInner.dot( eA_dir )));
        self.bevelVertsR[ i ] = self.bevelVertsO[ i ].add( eB_dir.mulVal( toInner.dot( eB_dir )));
      }
    }
    self.isInit = true;
  }

  pub fn drawSelf( self : *Interface2D ) void
  {
    const pos = self.pos.toVec2(); // Shape center pos
    const ang = self.pos.a;        // Shape base angle

    if( !self.isInit )
    {
      self.updateShapeVertices();
    }

    // Ellipses cannot have bevels
    if( self.shape == .ELLI )
    {
      const innerScale : Vec2 = self.scale.subVal( self.edgeWidth );

      drawer.poly(      pos, self.scale, ang, self.edgeCol, eng.G_CNFGS.Graphic_Ellipse_Facets                 );
      drawer.poly(      pos, innerScale, ang, self.fillCol, eng.G_CNFGS.Graphic_Ellipse_Facets                 );
      drawer.polyPerim( pos, self.scale, ang, self.lineCol, eng.G_CNFGS.Graphic_Ellipse_Facets, self.lineWidth );

      return;
    }

    const n : u8 = self.shape.getCornerCount();

    // Draw inner filled shape
    {
      const vec0 = self.bevelVertsI[ 0 ];
      var   vec1 = self.bevelVertsI[ 1 ];

      for( 2..n )| i |
      {
        const vec2 = self.bevelVertsI[ i ];

        drawer.basicTria( vec0, vec2, vec1, self.fillCol );

        vec1 = vec2;
      }
    }

    if( !self.hasAnyBevel() ) // No bevels : draw outlines assuming squared bevels
    {
      for( 0..n )| iPrev |
      {
        const iNext = ( iPrev + 1 ) % n;

        const vec1 = self.bevelVertsO[ iPrev ]; // Edge's leftmost  outer vertex
        const vec2 = self.bevelVertsI[ iPrev ]; // Edge's leftmost  inner vertex
        const vec3 = self.bevelVertsI[ iNext ]; // Edge's rightmost inner vertex
        const vec4 = self.bevelVertsO[ iNext ]; // Edge's rightmost outer vertex

        drawer.basicQuad( vec1, vec2, vec3, vec4, self.edgeCol );
        drawer.basicLine( vec1, vec4, self.lineCol, self.lineWidth );
      }
      return;
    }
    else // At least one non-trivial bevel : individually draw edges and bevels
    {

      for( 0..n )| iPrev | // Draw edge rect + line
      {
        const iNext = ( iPrev + 1 ) % n;

        const vec1 = self.bevelVertsR[ iPrev ]; // Edge's leftmost  outer vertex
        const vec2 = self.bevelVertsI[ iPrev ]; // Edge's leftmost  inner vertex
        const vec3 = self.bevelVertsI[ iNext ]; // Edge's rightmost inner vertex
        const vec4 = self.bevelVertsL[ iNext ]; // Edge's rightmost outer vertex

        drawer.basicQuad( vec1, vec2, vec3, vec4, self.edgeCol );
        drawer.basicLine( vec1, vec4, self.lineCol, self.lineWidth );
      }


      for( 0..n )| i | // Draw bevels + line
      {
        const v0  = self.bevelVertsI[ i ]; // Corner's inner vertex
        const v1  = self.bevelVertsL[ i ]; // Corner's left  vertex
        const v2  = self.bevelVertsR[ i ]; // Corner's right vertex
        const v12 = self.bevelVertsO[ i ]; // Corner's outer vertex

        if( utl.isFltEq( self.bevelStrength[ i ], 1.0 )) // Squared bevel
        {
          drawer.basicQuad( v1, v0, v2, v12,  self.edgeCol   );
          drawer.basicLine( v1, v12, self.lineCol, self.lineWidth );
          drawer.basicLine( v2, v12, self.lineCol, self.lineWidth );

          continue;
        }
        if( utl.isFltEq( self.bevelStrength[ i ], -1.0 )) // Diagonal bevel
        {
          drawer.basicTria( v1, v0, v2,      self.edgeCol   );
          drawer.basicLine( v1, v2, self.lineCol, self.lineWidth );

          continue;
        }

        const t : f64 = @abs( self.bevelStrength[ i ]); // NOTE : Can make lerp go past 1.0 strength. This is intended

        switch( getBevelDir( self.bevelStrength[ i ]))
        {
          1 => // Standard bevel ( notched )
          {
            const p0 = Vec2.lerp( v0, v12, t );

            drawer.basicTria( v1, v0, p0,      self.edgeCol   );
            drawer.basicTria( v0, v2, p0,      self.edgeCol   );
            drawer.basicLine( p0, v1, self.lineCol, self.lineWidth );
            drawer.basicLine( p0, v2, self.lineCol, self.lineWidth );
          },

         -1 => // Inverted Bevel ( split )
          {
            const p1 = Vec2.lerp( v1, v12, t );
            const p2 = Vec2.lerp( v2, v12, t );

            drawer.basicTria( v1, v0, p1,      self.edgeCol   );
            drawer.basicLine( p1, v0, self.lineCol, self.lineWidth );
            drawer.basicLine( p1, v1, self.lineCol, self.lineWidth );

            drawer.basicTria( v0, v2, p2,      self.edgeCol   );
            drawer.basicLine( p2, v0, self.lineCol, self.lineWidth );
            drawer.basicLine( p2, v2, self.lineCol, self.lineWidth );
          },

          0 => // No bevel ( cutout )
          {
            drawer.basicLine( v0, v1, self.lineCol, self.lineWidth );
            drawer.basicLine( v0, v2, self.lineCol, self.lineWidth );
          },

          else => unreachable
        }
      }
    }
  }
};
