const std = @import( "std" );
const def = @import( "defs" );

const Vec3   = def.Vec3;
const Shape2D = def.Shape2D;

const PI = def.PI;


// NOTE : All scaling via "s" param assumes the shape is sitting upright on its base ( line or face )
//        This means Y is for height, and X & Z are for widths ( X, Y, Z are scalling factors, not radius )
//        For pyramidss / prisms, Z is used as the Y for baseShape scaling


// ================================ 3D SHAPES ================================

const Shape3D = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  TETRA, // Tetrahedron  ( 4  triangles )
  CUBE,  // Hexahedron   ( 6  squares )
  OCTA,  // Octahedron   ( 8  triangles )
  DODE,  // Dodecahedron ( 12 pentagons)
  ICOSA, // Icosahedron  ( 20 triangles)

  SPHER, // Spheroid
//TORUS, // Donut ( needs a second radius to work )

  CONE,  // Cone     ( regular or skewed )
  CYLIN, // Cylinder ( regular or skewed )

  PRISM, // Arbitrary prism made of two parallel & identical Shape2D faces


  // F + V = E + 2

  pub inline fn getVertCount( self : Shape3D, baseShape : ?Shape2D ) u16
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

  pub inline fn getEdgeCount( self : Shape3D, baseShape : ?Shape2D ) u16
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

      else => if( Shape2D.isValidBaseShape( baseShape ))
      {
        if( self == .PYRAM ){ return baseShape.?.getEdgeCount() * 2; } // 2N
        if( self == .PRISM ){ return baseShape.?.getEdgeCount() * 3; } // 3N
      }
    }

    // TODO : log error

    return 0;
  }

  pub inline fn getFaceCount( self : Shape3D, baseShape : ?Shape2D ) u16
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

      else => if( Shape2D.isValidBaseShape( baseShape ))
      {
        if( self == .PYRAM ){ return baseShape.?.getEdgeCount() + 1; } // N + 1
        if( self == .PRISM ){ return baseShape.?.getEdgeCount() + 2; } // N + 2
      }
    }

    // TODO : log error

    return 0;
  }

  // Sum of all boundary edges
  pub inline fn getPerim( self : Shape3D, s : Vec3, baseShape : ?Shape2D ) f64
  {
    const r = s.mulVal( 0.5 );

    switch( self )
    {
      .TETRA => return ,
      .CUBE  => return 2.0 * ( s.x + s.y + s.z ),
      .OCTA  => return ,
      .DODE  => return ,
      .ICOSA => return ,

      .SPHER => return 0,
//    .TORUS => return 0,
      .CONE  => return Shape2D.ELLI.getPerim( .new( s.x, s.z )),
      .CYLIN => return Shape2D.ELLI.getPerim( .new( s.x, s.z )) * 2.0,

      else => if( Shape2D.isValidBaseShape( baseShape ))
      {
        const N : f64 = @floatFromInt( baseShape.?.getEdgeCount() );
        const bP      = baseShape.?.getPerim( .new( s.x, s.z ));

        if( self == .PYRAM )
        {
          const sH = @sqrt(( s.y * s.y ) + ( r.x * r.z ));
          const sP = N * sH;

          return bP + sP;
        }
        if( self == .PRISM )
        {
          const sP = N * s.y;

          return bP + bP + sP;
        }
      }
    }

    // TODO : log error

    return 0;
  }

  // Sum of all faces
  pub inline fn getArea( self : Shape3D, s : Vec3, baseShape : ?Shape2D ) f64
  {
    const r = s.mulVal( 0.5 );

    switch( self )
    {
      .TETRA => { return 0.0; }, // TODO : implement me
      .CUBE  => { return 2.0 * (( s.x * s.y ) + ( s.x * s.z ) + ( s.y * s.z )); },
      .OCTA  => { return 0.0; }, // TODO : implement me
      .DODE  => { return 0.0; }, // TODO : implement me
      .ICOSA => { return 0.0; }, // TODO : implement me

      .SPHER =>// TODO : Knud Thomsen ellipsoid surface area approximation ( Relative error <= 1.178% )
      {
        const p = 1.6075;

        const a = def.pow( r.x, p );
        const b = def.pow( r.y, p );
        const c = def.pow( r.z, p );

        return ( 4.0 * PI ) * def.pow((( a * b ) + ( a * c ) + ( b * c )) / 3.0, 1.0 / p ) ;
      },

      .CONE  =>
      {
        const sH = @sqrt(( s.y * s.y ) + ( r.x * r.z ));
        const sA = Shape2D.ELLI.getPerim( .new( s.x, s.z )) * sH;
        const bA = Shape2D.ELLI.getArea(  .new( s.x, s.z ));

        return  bA + sA;
      },

      .CYLIN =>
      {
        const sA = Shape2D.ELLI.getPerim( .new( s.x, s.z )) * s.y;
        const bA = Shape2D.ELLI.getArea(  .new( s.x, s.z ));

        return bA + bA + sA;
      },

      else => if( Shape2D.isValidBaseShape( baseShape ))
      {
        const bA = baseShape.?.getArea( .new( s.x, s.z ));

        if( self == .PYRAM )
        {
          const N : f64 = @floatFromInt( baseShape.?.getEdgeCount() );
          const bP      = baseShape.?.getPerim( .new( s.x, s.z ));

          // Exact lateral slant height via stacked pytagorean
          const sW = bP / N;
          const sH = @sqrt(( s.y * s.y ) + ( r.x * r.z ) - (( sW * 0.5 ) * ( sW * 0.5 )));
          const sA = baseShape.?.getPerim( .new( s.x, s.z )) * sH / 2.0;

          return bA + sA;
        }
        if( self == .PRISM )
        {
          const sA = baseShape.?.getPerim( .new( s.x, s.z )) * s.y;

          return bA + bA + sA;
        }
      }
    }

    // TODO : log error

    return 0;
  }

  pub inline fn getVolume( self : Shape3D, s : Vec3, baseShape : ?Shape2D ) f64
  {
    const r = s.mulVal( 0.5 );

    switch( self )
    {
      .TETRA => { return 0.0; }, // TODO : implement me
      .CUBE  => { return s.x * s.y * s.z; },
      .OCTA  => { return 0.0; }, // TODO : implement me
      .DODE  => { return 0.0; }, // TODO : implement me
      .ICOSA => { return 0.0; }, // TODO : implement me

      .SHPER => return ( 4.0 / 3.0 ) * PI * r.x * r.y * r.z,

      .CONE, .CYLIN =>
      {
        const bA = Shape2D.ELLI.getArea( .new( s.x, s.z ));

        if( self == .CONE  ){ return s.y * bA / 3.0; }
        if( self == .CYLIN ){ return s.y * bA;       }
      },

      else => if( Shape2D.isValidBaseShape( baseShape ))
      {
        const bA = baseShape.?.getArea( .new( s.x, s.z ));

        if( self == .PYRAM ){ return s.y * bA / 3.0; }
        if( self == .PRISM ){ return s.y * bA;       }
      }
    }

    // TODO : log error

    return 0;
  }
};