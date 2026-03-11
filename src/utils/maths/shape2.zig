const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;
const Vec3 = def.Vec3;

const PI = def.PI;


// NOTE : All scaling via "s" param assumes the shape is sitting upright on its base ( line or face )
//        This means Y is for height, and X is for width ( X, Y are scalling factors, not radius )


// Ramanujan ellipse perimeter correction factor ( dimensionless )
inline fn getRamanujanFactor( a : f32, b : f32 ) f32
{
  const sum = a + b;
  const dif = a - b;

  if ( sum < def.EPS ) return 1.0;
  if ( dif < def.EPS ) return 1.0;

  // Ellipticity parameter
  const h = ( dif * dif ) / ( sum * sum );

  // Ramanujan correction factor
  return 1.0 + ( 3.0 * h ) / ( 10.0 + @sqrt( 4.0 - ( 3.0 * h )));
}


// ================================ 2D SHAPES ================================

pub const Shape2D = enum( u8 )
{
  // NOTE : for polygons, "s" param scales the circumradius in X and Y
  ///       Aka : Affine-stretched regular polygon ( ellipse-affine model )

  // Special shapes

  RLIN, // Radius line
  DLIN, // Diameter line
  RECT, // Square / Rectangle

  // Affine polygons

  TRIA, // Triangle
  DIAM, // Diamond / Rhombus
  PENT, // Pentagon
  HEPT, // Heptagon
  HEXA, // Hexagon
  OCTA, // Octagon
  DECA, // Decagon
  DODE, // Dodecagon

  ELLI, // Circle / Ellipse ( aproximated via a high facet count polygon )

  // Star shapes

  STR5,
  STR6, // previously HSTR
  STR7,
  STR8, // previously DSTR
  STR9,
  STR10,
  STR12,

  pub inline fn getSkipFactor( self : Shape2D ) u16
  {
    return switch( self )
    {
      .STR5  => 2, // {5/2} pentagram
      .STR6  => 2, // {6/2} hexagram
      .STR7  => 2, // {7/2} heptagram
      .STR8  => 3, // {8/3} octagram
      .STR9  => 3, // {9/3}
      .STR10 => 4, // {10/3}
      .STR12 => 5, // {12/4}
      else   => 1, // Regular polygons
    };
  }

  pub inline fn isLine( self : Shape2D ) bool
  {
    return switch( self )
    {
      .RLIN, .DLIN => true,
      else => false,
    };
  }
  pub inline fn isPoly( self : Shape2D ) bool
  {
    return switch( self )
    {
      .TRIA, .DIAM, .PENT, .HEPT, .HEXA, .OCTA, .DECA, .DODE, .ELLI => true,
      else => false,
    };
  }
  pub inline fn isStar( self : Shape2D ) bool
  {
    return switch( self )
    {
      .STR5, .STR6, .STR7, .STR8, .STR9, .STR10, .STR12 => true,
      else => false,
    };
  }


  // V = E

  pub inline fn getVertCount( self : Shape2D ) u16
  {
    if( self == .RLIN or self == .DLIN ){ return 2; }
    else { return self.getEdgeCount(); }
  }
  pub inline fn getEdgeCount( self : Shape2D ) u16 // Aka "N"
  {
    return switch( self )
    {
      // Special shapes
      .RLIN => 1,
      .DLIN => 1,
      .RECT => 4,

      // Affine polygons
      .TRIA => 3,
      .DIAM => 4,
      .PENT => 5,
      .HEXA => 6,
      .HEPT => 7,
      .OCTA => 8,
      .DECA => 10,
      .DODE => 12,
      .ELLI => def.G_ST.Graphic_Ellipse_Facets, // 64 by default

      // Star shapes
      .STR5  => 5,
      .STR6  => 6,
      .STR7  => 7,
      .STR8  => 8,
      .STR9  => 9,
      .STR10 => 10,
      .STR12 => 12,
    };
  }

  // Sum of all edges
  pub inline fn getPerim( self : Shape2D, s : Vec2 ) f32
  {
    const rX = 0.5 * s.X;
    const rY = 0.5 * s.Y;

    switch( self )
    {
      .RLIN => return 0.5 * ( rX  + rY  ),
      .DLIN => return 0.5 * ( s.X + s.Y ),
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
        const N : f32 = @floatFromInt( self.getEdgeCount()  );
        const k : f32 = @floatFromInt( self.getSkipFactor() );

        // Mean radius ellipse perimeter
        const rM   = ( rX + rY ) * 0.5;
        const regP = ( 2.0 * N ) * rM * @sin( k * PI / N );
      //const regP = ( 2.0 * N ) * rM * @sin( PI / N );

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

  pub inline fn getArea( self : Shape2D, s : Vec2 ) f32
  {
    const rX = 0.5 * s.X;
    const rY = 0.5 * s.Y;

    switch( self )
    {
      .RLIN, .DLIN => return 0.0,
      .RECT        => return s.X * s.Y,
      .ELLI        => return PI * ( rX * rY ),
      else => // Exact formula for regular and affine polygon's area
      {
        const N : f32 = @floatFromInt( self.getEdgeCount()  );
        const k : f32 = @floatFromInt( self.getSkipFactor() );

        return ( N / 2.0 ) * ( rX * rY ) * @sin( 2.0 * k * PI / N );
      //return ( N / 2.0 ) * ( rX * rY ) * @sin( 2.0 * PI / N );
      },
    }
  }

  pub inline fn isValidBaseShape( self : ?Shape2D ) bool
  {
    if( self == null ){ return false; }

    switch( self.? )
    {
      .RLIN, .DLIN, =>
      {
        def.log( .WARN, 0, @src(), "Lines are not valid base shapes for 3D geometries" );
        return false;
      },

      .STR5, .STR6, .STR7, .STR8, .STR9, .STR10, .STR12 =>
      {
          def.log( .WARN, 0, @src(), "Stars are not valid base shapes for 3D geometries" );
          return false;
      },

      else => { return true; }
    }
  }
};
