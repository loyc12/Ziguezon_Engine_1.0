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
    return switch( self )
    {
      .RECT => ( s.X + s.Y ) * 2,
      else  => ,// Use polygon formula ( no exact one for ellipses
    };
  }

  pub inline fn getArea( self : Geom2D, s : Vec2 ) f32
  {
    return switch( self )
    {
      .RECT => s.X * s.Y,
      .ELLI => PI * s.X * s.Y,
      else  => ,// Use polygon formula
    };
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

  pub inline fn getVertCount( self : Geom2D, baseShape : ?Geom2D ) u16
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

  pub inline fn getEdgeCount( self : Geom2D, baseShape : ?Geom2D ) u16
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

  pub inline fn getFaceCount( self : Geom2D, baseShape : ?Geom2D ) u16
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
  pub inline fn getPerim( self : Geom2D, s : Vec3, baseShape : ?Geom2D ) f32
  {

  }

  // Sum of all faces
  pub inline fn getArea( self : Geom2D, s : Vec3, baseShape : ?Geom2D ) f32
  {

  }

  pub inline fn getVolume( self : Geom2D, s : Vec3, baseShape : ?Geom2D ) f32
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