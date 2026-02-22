const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;
const Vec3 = def.Vec3;

const PI = def.PI;


// NOTE : All scaling via "s" param assumes the shape is sitting upright on its base ( line or face )
//        This means Y is height, and X & Z are widths
//        For 3D pyrams / prisms, Z is used as the Y for baseShape scaling


// ================================ 2D GEOMETRIES ================================

pub const Geom2D = enum( u8 )
{
  // NOTE : for polygons, "s" param scales the circumradius in X and Y
  ///       Aka : Affine-stretched regular polygon ( ellipse-affine model )

  RECT, // Square / Rectangle

  TRIA, // Triangle
  DIAM, // Diamond / Rhombus
  PENT, // Pentagon
  HEXA, // Hexagon
  HEPT, // Heptagon
  OCTA, // Octagon
  DECA, // Decagon
  DODE, // Dodecagon

  ELLI, // Circle / Ellipse ( aproximated via a high facet count polygon )


  // V = E

  pub inline fn getVertCount( self : Geom2D ) u16 { return self.getEdgeCount(); }
  pub inline fn getEdgeCount( self : Geom2D ) u16 // Aka "N"
  {
    return switch( self )
    {
      .RECT => 4,
      .TRIA => 3,
      .DIAM => 4,
      .PENT => 5,
      .HEXA => 6,
      .OCTA => 8,
      .HEPT => 7,
      .DECA => 10,
      .DODE => 12,
      .ELLI => def.G_ST.Graphic_Ellipse_Facets, // 64 by default
    };
  }

  // Sum of all edges
  pub inline fn getPerim( self : Geom2D, s : Vec2 ) f32
  {
    switch( self )
    {
      .RECT => return ( s.X + s.Y ) * 2,
      .ELLI =>
      {
        if( @abs( s.X - s.Y ) < def.EPS ) // Circle circumference from radius
        {
          return 2.0 * PI * s.X;
        }
        else // Ramanujan's 2nd ellipse perimeter approximation ( Relative error <≈ 0.0003% )
        {
          const sum = s.X + s.Y;
          const dif = s.X - s.Y;

          // Ellipticity parameter
          const h = ( dif * dif ) / ( sum * sum );

          // Ramanujan correction factor
          const C = 1.0 + ( 3.0 * h ) / ( 10.0 + @sqrt( 4.0 - 3.0 * h ));

          return C * PI * sum;
        }
      },

      else =>
      {
        const N : f32 = @floatFromInt( self.getEdgeCount() );

        if( @abs( s.X - s.Y ) < def.EPS ) // Regular polygon perimeter from circumradius ( trigonometric form )
        {
          return ( 2.0 * N ) * s.X * @sin( PI / N );
        }
        else // Chebyshev ellipse correction heuristic for affine regular polygon perimeter ( Relative error <≈ 1% for exentricity of 10 )
        {
          const sum = s.X + s.Y;
          const dif = s.X - s.Y;

          // Geometric mean radius
          const mR = @sqrt( s.X * s.Y );

          // Ellipticity parameter
          const h1 = ( dif * dif ) / ( sum * sum );

          // Chebyshev correction factor
          const h2 = h1 * h1;
          const h3 = h1 * h2;
          const h4 = h1 * h3;

          const C = 1.0 + ( 0.25 * h1 ) - ( 0.0625 * h2 ) - ( 0.015625 * h3 ) + ( 0.00390625 * h4 );

          return C * ( 2.0 * N ) * mR * @sin( PI / N );
        }
      },
    }
  }

  pub inline fn getArea( self : Geom2D, s : Vec2 ) f32
  {
    switch( self )
    {
      .RECT => return s.X * s.Y,
      .ELLI => return PI * s.X * s.Y,
      else  =>
      {
        const N : f32 = @floatFromInt( self.getEdgeCount() );

        if( @abs( s.X - s.Y ) < def.EPS ) // Regular polygon area from circumradius ( trigonometric form )
        {
          return N * s.X * s.X * @sin( PI / N ) * @cos( PI / N );
        }
        else // Affine-stretched polygon area ( exact )
        {
          const sin2piN = @sin( 2 * PI / N );
          return 0.5 * N * s.X * s.Y * sin2piN;
        }
      },
    }
  }
};


// ================================ 3D GEOMETRIES ================================

const Geom3D = enum( u8 )
{
  TETRA, // Tetrahedron  ( 4  triangles )
  CUBE,  // Hexahedron   ( 6  squares )
  OCTA,  // Octahedron   ( 8  triangles )
  DODE,  // Dodecahedron ( 12 pentagons)
  ICOSA, // Icosahedron  ( 20 triangles)

  SPHER, // Spheroid
  TORUS, // Donut

  CONE,  // Cone     ( regular or skewed )
  CYLIN, // Cylinder ( regular or skewed )

  PRISM, // Arbitrary prism made of two parallel & identical Geom2D faces


  // F + V = E + 2

  pub inline fn getVertCount( self : Geom3D, baseShape : ?Geom2D ) u16
  {
    switch( self )
    {
      .TETRA => return 4,
      .CUBE  => return 8,
      .OCTA  => return 6,
      .DODE  => return 20,
      .ICOSA => return 12,

      .SPHER => return 0,
      .TORUS => return 0,
      .CONE  => return 1,
      .CYLIN => return 0,

      else => if( baseShape != null )
      {
        if( self == .PYRAM ){ return baseShape.?.getEdgeCount() + 1; } // N + 1
        if( self == .PRISM ){ return baseShape.?.getEdgeCount() * 2; } // 2N
      }
    }

    // TODO : log error

    return 0;
  }

  pub inline fn getEdgeCount( self : Geom3D, baseShape : ?Geom2D ) u16
  {
    switch( self )
    {
      .TETRA => return 6,
      .CUBE  => return 12,
      .OCTA  => return 12,
      .DODE  => return 30,
      .ICOSA => return 30,

      .SPHER => return 0,
      .TORUS => return 0,
      .CONE  => return 1,
      .CYLIN => return 2,

      else => if( baseShape != null )
      {
        if( self == .PYRAM ){ return baseShape.?.getEdgeCount() * 2; } // 2N
        if( self == .PRISM ){ return baseShape.?.getEdgeCount() * 3; } // 3N
      }
    }

    // TODO : log error

    return 0;
  }

  pub inline fn getFaceCount( self : Geom3D, baseShape : ?Geom2D ) u16
  {
    switch( self )
    {
      .TETRA => return 4,
      .CUBE  => return 6,
      .OCTA  => return 8,
      .DODE  => return 12,
      .ICOSA => return 20,

      .SPHER => return 1,
      .TORUS => return 1,
      .CONE  => return 2,
      .CYLIN => return 3,

      else => if( baseShape != null )
      {
        if( self == .PYRAM ){ return baseShape.?.getEdgeCount() + 1; } // N + 1
        if( self == .PRISM ){ return baseShape.?.getEdgeCount() + 2; } // N + 2
      }
    }

    // TODO : log error

    return 0;
  }

  // Sum of all edges
  pub inline fn getPerim( self : Geom3D, s : Vec3, baseShape : ?Geom2D ) f32
  {
    switch( self )
    {
      .TETRA => return ,
      .CUBE  => return 4.0 * ( s.X + s.Y + s.Z ),
      .OCTA  => return ,
      .DODE  => return ,
      .ICOSA => return ,

      .SPHER => return 0,
      .TORUS => return 0,
      .CONE  => return Geom2D.ELLI.getPerim( .new( s.X, s.Z )),
      .CYLIN => return Geom2D.ELLI.getPerim( .new( s.X, s.Z )) * 2.0,

      else => if( baseShape != null )
      {
        if( self == .PYRAM )
        {
          const bP = baseShape.?.getPerim( .new( s.X, s.Z )); // TODO : Compensate for slanting
          const bV = baseShape.?.getEdgeCount() * s.Y;

          return (( 2.0 * bP ) + ( s.Y * bV )) * 0.5;
        }
        if( self == .PRISM )
        {
          const bP = baseShape.?.getPerim( .new( s.X, s.Z ));
          const bV = baseShape.?.getEdgeCount() * s.Y;

          return ( 2.0 * bP ) + ( s.Y * bV );
        }
      }
    }

    // TODO : log error

    return 0;
  }

  // Sum of all faces
  pub inline fn getArea( self : Geom3D, s : Vec3, baseShape : ?Geom2D ) f32
  {
    switch( self )
    {
      .TETRA => return ,
      .CUBE  => return 2.0 * (( s.X * s.Y ) + ( s.X * s.Z ) + ( s.Y * s.Z )),
      .OCTA  => return ,
      .DODE  => return ,
      .ICOSA => return ,

      .SPHER => return 4.0 * PI * s.X * s.Y * s.Z, // TODO : find better aprox / test for spheroid
      .TORUS => return ,
      .CONE  => return ,
      .CYLIN => return ,

      else => if( baseShape != null )
      {
        if( self == .PYRAM )
        {
          const bP = baseShape.?.getPerim( .new( s.X, s.Z ));
          const bA = baseShape.?.getArea(  .new( s.X, s.Z ));

          return (( 2.0 * bA ) + ( s.Y * bP )) * 0.5; // TODO : Compensate for slanting
        }
        if( self == .PRISM )
        {
          const bP = baseShape.?.getPerim( .new( s.X, s.Z ));
          const bA = baseShape.?.getArea(  .new( s.X, s.Z ));

          return ( 2.0 * bA ) + ( s.Y * bP );
        }
      }
    }

    // TODO : log error

    return 0;
  }

  pub inline fn getVolume( self : Geom3D, s : Vec3, baseShape : ?Geom2D ) f32
  {
    switch( self )
    {
      .TETRA => return ,
      .CUBE  => return s.X * s.Y * s.Z,
      .OCTA  => return ,
      .DODE  => return ,
      .ICOSA => return ,

      .SHPER => return ( 4.0 / 3.0 ) * PI * s.X * s.Y * s.Z,
      .TORUS => return ,
      .CONE  => return ,
      .CYLIN => return ,

      else => if( baseShape != null )
      {
        if( self == .PYRAM ){ return s.Y * baseShape.?.getArea( .new( s.X, s.Z )) / 3.0; }
        if( self == .PRISM ){ return s.Y * baseShape.?.getArea( .new( s.X, s.Z ));       }
      }
    }

    // TODO : log error

    return 0;
  }
};