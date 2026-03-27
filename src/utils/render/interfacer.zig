const std  = @import( "std" );
const def  = @import( "defs" );

const Box2    = def.Box2;
const Vec2    = def.Vec2;
const VecA    = def.VecA;
const Angle   = def.Angle;

const drawer  = def.drwS_u;


pub const InterfaceShape = enum
{
  ELLI,  // Ellipse

  TRI_R, // Points right
  TRI_D, // Points down
  TRI_L, // Points left
  TRI_U, // Points up

  DIAM,  // Pointy side up
  RECT,  // Flat side up

  HEX_P, // Pointy side up
  HEX_F, // Flat side up

  OCT_P, // Pointy side up
  OCT_F, // Flat side up


  pub fn getCornerCount( self : InterfaceShape ) usize
  {
    return switch( self )
    {
      .ELLI                          => 0,
      .TRI_U, .TRI_D, .TRI_L, .TRI_R => 3,
      .RECT,  .DIAM                  => 4,
      .HEX_F, .HEX_P                 => 6,
      .OCT_F, .OCT_P                 => 8,

    };
  }
};

pub const BevelType = enum
{
  NONE,      // no cutout
  CUTOUT,    // Straight angle cuttout
  DIAGONAL,  // linear cutout ( chamfer )
  CURVE_OUT, // convex circular cutout
  CURVE_INT, // Concave circular cutout
};

const maxBevelCount = 8;
const BevelArray    = [ maxBevelCount ]BevelType;

fn getEmptyBevelArray() BevelArray { return .{ .NONE, .NONE, .NONE, .NONE, .NONE, .NONE, .NONE, .NONE }; }


// ================================ INTERFACER STRUCT ================================

pub const Interfacer2D = struct
{
  pos    : VecA,
  scale  : Vec2 = .new( 128, 128 ),
  layer  : u16  = 1,

  shape    : InterfaceShape = .RECT,
  fillCol  : def.Colour     = .nWhite,
  edgeCol  : def.Colour     = .nBlack,
  edgeWidth : f64           = 1,

  bevelTypes : BevelArray = getEmptyBevelArray(),
  bevelDepth : f64        = 8,

  isActive   : bool = true,
  isSelected : bool = false,


  fn hasAnyBevel( self : *const Interfacer2D ) bool
  {
    if( self.bevelDepth < def.EPS ){ return false; }

    for( 0..self.shape.getCornerCount() )| b |
    {
      if( self.bevelTypes[ b ] != .NONE ){ return true; }
    }

    return false;
  }

  pub fn drawSelf( self : *const Interfacer2D ) void
  {
    // Ellipses cannot have bevels
    if( self.shape == .ELLI or !self.hasAnyBevel() )
    {
      // Draw full shape
      switch( self.shape )
      {
        .ELLI  => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a, self.fillCol, def.G_ST.Graphic_Ellipse_Facets ),

        .TRI_R => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(   0 ), self.fillCol, 4 ),
        .TRI_D => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(  90 ), self.fillCol, 4 ),
        .TRI_L => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 180 ), self.fillCol, 4 ),
        .TRI_U => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 270 ), self.fillCol, 4 ),

        .DIAM  => drawer.drawPolygonPlus(   self.pos.toVec2(), self.scale, self.pos.a, self.fillCol, 4 ),
        .RECT  => drawer.drawRectanglePlus( self.pos.toVec2(), self.scale, self.pos.a, self.fillCol ),

        .HEX_P => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(  0 ), self.fillCol, 6 ),
        .HEX_F => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 60 ), self.fillCol, 6 ),

        .OCT_P => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(  0 ), self.fillCol, 8 ),
        .OCT_F => drawer.drawPolygonPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 45 ), self.fillCol, 8 ),
      }

      // Draw full outline
      switch( self.shape )
      {
        .ELLI  => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a, self.edgeCol, def.G_ST.Graphic_Ellipse_Facets, self.edgeWidth ),

        .TRI_R => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(   0 ), self.edgeCol, 3, self.edgeWidth ),
        .TRI_D => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(  90 ), self.edgeCol, 3, self.edgeWidth ),
        .TRI_L => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 180 ), self.edgeCol, 3, self.edgeWidth ),
        .TRI_U => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 270 ), self.edgeCol, 3, self.edgeWidth ),

        .DIAM  => drawer.drawPolygonLinesPlus(   self.pos.toVec2(), self.scale, self.pos.a, self.edgeCol, 4, self.edgeWidth ),
        .RECT  => drawer.drawRectangleLinesPlus( self.pos.toVec2(), self.scale, self.pos.a, self.edgeCol, self.edgeWidth ),

        .HEX_P => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(  0 ), self.edgeCol, 6, self.edgeWidth ),
        .HEX_F => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 60 ), self.edgeCol, 6, self.edgeWidth ),

        .OCT_P => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg(  0 ), self.edgeCol, 8, self.edgeWidth ),
        .OCT_F => drawer.drawPolygonLinesPlus( self.pos.toVec2(), self.scale, self.pos.a.addDeg( 45 ), self.edgeCol, 8, self.edgeWidth ),
      }

      return;
    }

    const n = self.shape.getCornerCount();  // Shape vertex count
    var  a0 = self.pos.a;                   // Shape initial angle
    var  s2 = self.scale;                   // outer shape scale
    var  s1 = s2.subVal( self.bevelDepth ); // inner shape scale

    // Draw center shape ( minus bevel depth ), offsetting starting angle appropriately
    switch( self.shape )
    {
      .ELLI  => // Cannot happen
      {
        def.qlog( .ERROR, 0, @src(), "How did you even get here ???" );
        return;
      },

      .TRI_R =>
      {
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 4 );
      },
      .TRI_D =>
      {
        a0 = a0.addDeg( 90 );
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 4 );
      },
      .TRI_L =>
      {
        a0 = a0.addDeg( 180 );
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 4 );
      },
      .TRI_U =>
      {
        a0 = a0.addDeg( 270 );
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 4 );
      },

      .DIAM  =>
      {
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 4 );
      },
      .RECT  =>
      {
        // Scale increased so the rect isn't squashed when drawn via drawPoly
        s1 = s1.mulVal( def.R2 );
        s2 = s2.mulVal( def.R2 );

        a0 = a0.addDeg( 45 );
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 4 );
      },

      .HEX_P =>
      {
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 6 );
      },
      .HEX_F =>
      {
        a0 = a0.addDeg( 30 );
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 6 );
      },

      .OCT_P =>
      {
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 6 );
      },
      .OCT_F =>
      {
        a0 = a0.addDeg( 22.5 );
        drawer.drawPolygonPlus( self.pos.toVec2(), s1, a0, self.fillCol, 6 );
      },
    }

    const n_f    : f64 = @floatFromInt( n );
    const aDelta : f64 = def.TAU / n_f;

    // Shape angles
    var a1 = a0;
    var a2 = undefined;

    // Bevel angles
    var a1_b = a1.subRad( aDelta * 0.5 );
    var a2_b = undefined;

    // Edge corner points
    var p1 : Vec2 = .fromAngleScaled( a0 , s1 ); // inner corner 1 ( bevel     origin   )
    var p2 : Vec2 = .fromAngleScaled( a0 , s2 ); // outer corner 1 ( bevelless midpoint )

    var p3 : Vec2 = undefined;                   // inner corner 2
    var p4 : Vec2 = undefined;                   // outer corner 2

    // Iterating over every side / vertex
    for( 0..n )| b |
    {
      a2   = a1.addRad(   aDelta );
      a2_b = a1_b.addRad( aDelta );

      p3 = .fromAngleScaled( a2 , s1 );
      p4 = .fromAngleScaled( a2 , s2 );

      // Drawing the edge
      drawer.drawBasicQuad( p1, p2, p3, p4, self.fillCol );
      drawer.drawLine( p2, p4, self.fillCol, self.edgeWidth );

      // Drawing the bevel
      switch( self.bevelTypes[ b ])
      {
        .NONE =>
        {
          const p1_b = p1.add( .fromAngle( a1_b ).mulVal( self.bevelDepth ));
          const p2_b = p1.add( .fromAngle( a2_b ).mulVal( self.bevelDepth ));

          drawer.drawBasicTria( p1, p1_b, p2, self.fillCol );
          drawer.drawBasicTria( p1, p2, p2_b, self.fillCol );

          drawer.drawLine( p1_b, p2, self.fillCol, self.edgeWidth );
          drawer.drawLine( p2_b, p2, self.fillCol, self.edgeWidth );
        },

        .CUTOUT =>
        {
          const p1_b = p1.add( .fromAngle( a1_b ).mulVal( self.bevelDepth ));
          const p2_b = p1.add( .fromAngle( a2_b ).mulVal( self.bevelDepth ));

          drawer.drawLine( p1, p1_b, self.fillCol, self.edgeWidth );
          drawer.drawLine( p1, p2_b, self.fillCol, self.edgeWidth );
        },

        .DIAGONAL =>
        {
          const p1_b = p1.add( .fromAngle( a1_b ).mulVal( self.bevelDepth ));
          const p2_b = p1.add( .fromAngle( a2_b ).mulVal( self.bevelDepth ));

          drawer.drawBasicTria( p1, p1_b, p2_b, self.fillCol );
          drawer.drawLine( p1_b, p2_b, self.fillCol, self.edgeWidth );
        },

        else => // TODO : draw inner and outer curved bevels
        {
          def.qlog( .ERROR, 0, @src(), "UNIMPLEMENTED" );
        }
      }

      // Reusing old angles for next iteration
      p1 = p3;
      p2 = p4;

      a1   = a2;
      a1_b = a2_b;
    }
  }
};
