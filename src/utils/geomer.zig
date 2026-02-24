const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;
const Vec3 = def.Vec3;

const PI = def.PI;


// NOTE : All scaling via "s" param assumes the shape is sitting upright on its base ( line or face )
//        This means Y is hfor eight, and X & Z are for widths ( X, Y, Z are scalling factors, not radius )
//        For 3D pyrams / prisms, Z is used as the Y for baseShape scaling


// Ramanujan ellipse perimeter correction factor ( dimensionless )
pub inline fn getRamanujanFactor( a : f32, b : f32 ) f32
{
  const sum =   a + b;
  const dif =   a - b;

  if ( sum < def.EPS ) return 1.0;
  if ( dif < def.EPS ) return 1.0;

  // Ellipticity parameter
  const h = ( dif * dif ) / ( sum * sum );

  // Ramanujan correction factor
  return 1.0 + ( 3.0 * h ) / ( 10.0 + @sqrt( 4.0 - ( 3.0 * h )));
}


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
    const rX = 0.5 * s.X;
    const rY = 0.5 * s.Y;

    switch( self )
    {
      .RECT => return 2.0 * ( s.X + s.Y ),
      .ELLI =>
      {
        const regP = PI * ( rX + rY );

        if( @abs( rX - rY ) < def.EPS ) // Circle circumference from radius
        {
          return regP;
        }
        else // Ramanujan's 2nd ellipse perimeter approximation ( Relative error <= 0.0003% )
        {
          return regP * getRamanujanFactor( rX, rY );
        }
      },

      else =>
      {
        const N : f32 = @floatFromInt( self.getEdgeCount() );

        // Mean radius ellipse perimeter
        const rM   = ( rX + rY ) * 0.5;
        const regP = ( 2.0 * N ) * rM * @sin( PI / N );

        if( @abs( rX - rY ) < def.EPS ) // Regular polygon perimeter from circumradius ( trigonometric form )
        {
          return regP;
        }
        else // Affine regular polygon perimeter approximation via Ramanujan factor
        {
          return regP * getRamanujanFactor( rX, rY );
        }
      },
    }
  }

  pub inline fn getArea( self : Geom2D, s : Vec2 ) f32
  {
    const rX = 0.5 * s.X;
    const rY = 0.5 * s.Y;

    switch( self )
    {
      .RECT => return s.X * s.Y,
      .ELLI => return PI * ( rX * rY ),
      else  => // Exact formula for regular and affine polygon's area
      {
        const N : f32 = @floatFromInt( self.getEdgeCount() );

        return ( N / 2.0 ) * ( rX * rY ) * @sin( 2 * PI / N );
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
//TORUS, // Donut ( needs a second radius to work )

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
//    .TORUS => return 0,
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
//    .TORUS => return 0,
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
//    .TORUS => return 1,
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

  // Sum of all boundary edges
  pub inline fn getPerim( self : Geom3D, s : Vec3, baseShape : ?Geom2D ) f32
  {
    const r = s.mulVal( 0.5 );

    switch( self )
    {
      .TETRA => return ,
      .CUBE  => return 2.0 * ( s.X + s.Y + s.Z ),
      .OCTA  => return ,
      .DODE  => return ,
      .ICOSA => return ,

      .SPHER => return 0,
//    .TORUS => return 0,
      .CONE  => return Geom2D.ELLI.getPerim( .new( s.X, s.Z )),
      .CYLIN => return Geom2D.ELLI.getPerim( .new( s.X, s.Z )) * 2.0,

      else => if( baseShape != null )
      {
        const N : f32 = @floatFromInt( baseShape.?.getEdgeCount() );
        const bP      = baseShape.?.getPerim( .new( s.X, s.Z ));

        if( self == .PYRAM )
        {
          const sH = @sqrt(( s.Y * s.Y ) + ( r.X * r.Z ));
          const sP = N * sH;

          return bP + sP;
        }
        if( self == .PRISM )
        {
          const sP = N * s.Y;

          return bP + bP + sP;
        }
      }
    }

    // TODO : log error

    return 0;
  }

  // Sum of all faces
  pub inline fn getArea( self : Geom3D, s : Vec3, baseShape : ?Geom2D ) f32
  {
    const r = s.mulVal( 0.5 );

    switch( self )
    {
      .TETRA => { return 0.0; }, // TODO : implement me
      .CUBE  => { return 2.0 * (( s.X * s.Y ) + ( s.X * s.Z ) + ( s.Y * s.Z )); },
      .OCTA  => { return 0.0; }, // TODO : implement me
      .DODE  => { return 0.0; }, // TODO : implement me
      .ICOSA => { return 0.0; }, // TODO : implement me

      .SPHER =>// TODO : Knud Thomsen ellipsoid surface area approximation ( Relative error <= 1.178% )
      {
        const p = 1.6075;

        const a = def.pow( r.X, p );
        const b = def.pow( r.Y, p );
        const c = def.pow( r.Z, p );

        return ( 4.0 * PI ) * def.pow((( a * b ) + ( a * c ) + ( b * c )) / 3.0, 1.0 / p ) ;
      },

      .CONE  =>
      {
        const sH = @sqrt(( s.Y * s.Y ) + ( r.X * r.Z ));
        const sA = Geom2D.ELLI.getPerim( .new( s.X, s.Z )) * sH;
        const bA = Geom2D.ELLI.getArea(  .new( s.X, s.Z ));

        return  bA + sA;
      },

      .CYLIN =>
      {
        const sA = Geom2D.ELLI.getPerim( .new( s.X, s.Z )) * s.Y;
        const bA = Geom2D.ELLI.getArea(  .new( s.X, s.Z ));

        return bA + bA + sA;
      },

      else => if( baseShape != null )
      {
        const bA = baseShape.?.getArea( .new( s.X, s.Z ));

        if( self == .PYRAM )
        {
          const N : f32 = @floatFromInt( baseShape.?.getEdgeCount() );
          const bP      = baseShape.?.getPerim( .new( s.X, s.Z ));

          // Exact lateral slant height via stacked pytagorean
          const sW = bP / N;
          const sH = @sqrt(( s.Y * s.Y ) + ( r.X * r.Z ) - (( sW * 0.5 ) * ( sW * 0.5 )));
          const sA = baseShape.?.getPerim( .new( s.X, s.Z )) * sH / 2.0;

          return bA + sA;
        }
        if( self == .PRISM )
        {
          const sA = baseShape.?.getPerim( .new( s.X, s.Z )) * s.Y;

          return bA + bA + sA;
        }
      }
    }

    // TODO : log error

    return 0;
  }

  pub inline fn getVolume( self : Geom3D, s : Vec3, baseShape : ?Geom2D ) f32
  {
    const r = s.mulVal( 0.5 );

    switch( self )
    {
      .TETRA => { return 0.0; }, // TODO : implement me
      .CUBE  => { return s.X * s.Y * s.Z; },
      .OCTA  => { return 0.0; }, // TODO : implement me
      .DODE  => { return 0.0; }, // TODO : implement me
      .ICOSA => { return 0.0; }, // TODO : implement me

      .SHPER => return ( 4.0 / 3.0 ) * PI * r.X * r.Y * r.Z,

      .CONE, .CYLIN =>
      {
        const bA = Geom2D.ELLI.getArea( .new( s.X, s.Z ));

        if( self == .CONE  ){ return s.Y * bA / 3.0; }
        if( self == .CYLIN ){ return s.Y * bA;       }
      },

      else => if( baseShape != null )
      {
        const bA = baseShape.?.getArea( .new( s.X, s.Z ));

        if( self == .PYRAM ){ return s.Y * bA / 3.0; }
        if( self == .PRISM ){ return s.Y * bA;       }
      }
    }

    // TODO : log error

    return 0;
  }
};