const eng = @import( "engine" );
const utl = @import( "utils" );

const ray     = utl.ray;
const Vec2    = utl.Vec2;
const Angle   = utl.Angle;
const Colour  = utl.Colour;
const RayRect = utl.RayRect;


pub fn GetDrawer( comptime Transform : type ) type
{
  return struct
  {
    const Self = @This();

    pub const BASE_LINE_WIDTH : f64 = 2.0; // TODO : Move to engine settings


    // ================ BASIC DRAWING FUNCTIONS ================

    pub inline fn pixel( pos : Vec2, col : Colour ) void
    {
      ray.drawPixelV( Transform.toRay( pos ), col.toRayCol() );
    }
    pub inline fn macroPixel( pos : Vec2, size : f64, col : Colour ) void
    {
      ray.drawRectangleV( Transform.toRay( pos ), @floatCast( size ), col.toRayCol() );
    }

    pub inline fn basicLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f64 ) void
    {
      ray.drawLineEx( Transform.toRay( p1 ), Transform.toRay( p2 ), @floatCast( width ), col.toRayCol() );
    }
    // pub fn dotedLine( p1 : Vec2, p2 : Vec2, col : Colour, width : f64, spacinf : f64 ) void

    pub inline fn basicCircle( pos : Vec2, radius : f64, col : Colour ) void
    {
      ray.drawCircleV( Transform.toRay( pos ), @floatCast( radius), col.toRayCol() );
    }
    pub inline fn basicCirclePerim( pos : Vec2, radius : f64, col : Colour ) void // TODO : Add line thickness
    {
      ray.drawCircleLinesV( Transform.toRay( pos ), @floatCast( radius ), col.toRayCol() );
    }

    pub inline fn basicElli( pos : Vec2, radii : Vec2, col : Colour ) void
    {
      ray.drawEllipseV( Transform.toRay( pos ), @floatCast( radii.x ), @floatCast( radii.y ), col.toRayCol() );
    }
    pub inline fn basicElliPerim( pos : Vec2, radii : Vec2, col : Colour ) void // TODO : Add line thickness
    {
      ray.drawEllipseLinesV( Transform.toRay( pos ), @floatCast( radii.x ), @floatCast( radii.y ), col.toRayCol() );
    }

    pub inline fn basicRect( pos : Vec2, size : Vec2, col : Colour ) void
    {
      ray.drawRectangleV( Transform.toRay( pos ), size.toRayVec2(), col.toRayCol() );
    }
    pub inline fn basicRectPerim( pos : Vec2, size : Vec2, col : Colour, width : f64  ) void
    {
      const rayPos = Transform.toRay( pos );

      ray.drawRectangleLinesEx(
        RayRect
        {
          .x      = rayPos.x,
          .y      = rayPos.y,
          .width  = @floatCast( size.x ),
          .height = @floatCast( size.y )
        },
        @floatCast( width ),
        col.toRayCol()
      );
    }

    pub inline fn basicTria( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour ) void
    {
      ray.drawTriangle( Transform.toRay( p1 ), Transform.toRay( p2 ), Transform.toRay( p3 ), col.toRayCol() );
    }
    pub inline fn basicTriaPerim( p1 : Vec2, p2 : Vec2, p3 : Vec2, col : Colour, width : f64 ) void
    {
      ray.drawLineEx( Transform.toRay( p1 ), Transform.toRay( p2 ), @floatCast( width ), col.toRayCol() );
      ray.drawLineEx( Transform.toRay( p2 ), Transform.toRay( p3 ), @floatCast( width ), col.toRayCol() );
      ray.drawLineEx( Transform.toRay( p3 ), Transform.toRay( p1 ), @floatCast( width ), col.toRayCol() );
    }

    pub inline fn basicQuad( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour ) void
    {
      ray.drawTriangle( Transform.toRay( p1 ), Transform.toRay( p2 ), Transform.toRay( p3 ), col.toRayCol() );
      ray.drawTriangle( Transform.toRay( p3 ), Transform.toRay( p4 ), Transform.toRay( p1 ), col.toRayCol() );
    }
    pub inline fn basicQuadPerim( p1 : Vec2, p2 : Vec2, p3 : Vec2, p4 : Vec2, col : Colour, width : f64  ) void
    {
      ray.drawLineEx( Transform.toRay( p1 ), Transform.toRay( p2 ), @floatCast( width ), col.toRayCol() );
      ray.drawLineEx( Transform.toRay( p2 ), Transform.toRay( p3 ), @floatCast( width ), col.toRayCol() );
      ray.drawLineEx( Transform.toRay( p3 ), Transform.toRay( p4 ), @floatCast( width ), col.toRayCol() );
      ray.drawLineEx( Transform.toRay( p4 ), Transform.toRay( p1 ), @floatCast( width ), col.toRayCol() );
    }

    pub inline fn basicPoly( pos : Vec2, radius : f64, a : Angle, col : Colour, sides : u16 ) void
    {
      ray.drawPoly( Transform.toRay( pos ), @intCast( sides ), @floatCast( radius ), @floatCast( a.toDeg() ), col.toRayCol() );
    }
    pub inline fn basicPolyPerim( pos : Vec2, radius : f64, a : Angle, col : Colour, sides : u16, width : f64 ) void // TODO : Add line thickness
    {
      ray.drawPolyLinesEx( Transform.toRay( pos ), @intCast( sides ), @floatCast( radius ), @floatCast( a.toDeg() ), @floatCast( width ), col.toRayCol() );
    }


    // ================ ADVANCED DRAWING FUNCTIONS ================

    pub inline fn tria( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, 3 ); }
    pub inline fn diam( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, 4 ); }
    pub inline fn pent( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, 5 ); }
    pub inline fn hexa( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, 6 ); }
    pub inline fn octa( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, 8 ); }
    pub inline fn elli( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, eng.G_ST.Graphic_Ellipse_Facets ); }


    // Draws a rectangle centered at a given position with specified rotation (rad), colour and size, and scaled in x/y by radii
    pub inline fn rect( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void
    {
      const p1 = pos.add( Vec2.new(  radii.x,  radii.y ).rot( a ));
      const p2 = pos.add( Vec2.new(  radii.x, -radii.y ).rot( a ));
      const p3 = pos.add( Vec2.new( -radii.x, -radii.y ).rot( a ));
      const p4 = pos.add( Vec2.new( -radii.x,  radii.y ).rot( a ));

      Self.basicQuad( p1, p2, p3, p4, col );
    }
    pub inline fn rectPerim( pos : Vec2, radii : Vec2, a : Angle, col : Colour, width : f64 ) void
    {
      const p1 = pos.add( Vec2.new(  radii.x,  radii.y ).rot( a ));
      const p2 = pos.add( Vec2.new(  radii.x, -radii.y ).rot( a ));
      const p3 = pos.add( Vec2.new( -radii.x, -radii.y ).rot( a ));
      const p4 = pos.add( Vec2.new( -radii.x,  radii.y ).rot( a ));

      Self.basicQuadPerim( p1, p2, p3, p4, col, width );
    }


    // Draws a polygon centered at a given position with specified rotation (rad), colour and facet count, and scaled in x/y by radii
    pub fn poly( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16 ) void
    {
      if( sides < 1 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a polygon with 0 sides" );
        return;
      }

      const N : f32 = @floatFromInt( sides );
      const sideStepAngle = Angle.newRad( utl.TAU / N );
      const rP0 = Vec2.new( radii.x, 0.0 ).rot( a );

      if( sides < 3 ) // NOTE : only for radius or diametre lines
      {
        const rP1 = Vec2.fromAngleScaled( sideStepAngle, radii ).rot( a );

        if( sides == 1 ){ Self.basicLine( pos, pos.add( rP1 ), col, BASE_LINE_WIDTH ); }
        else { Self.basicLine( pos.add( rP1.flp() ), pos.add( rP1 ), col, BASE_LINE_WIDTH ); }
      }
      else if( !radii.isIso() ) // NOTE : slower, but accounts for non isoscalar polygons
      {
        var rP1 = Vec2.fromAngleScaled( sideStepAngle, radii ).rot( a );

        for( 2..sides )| i | // Starting at two since each triangle needs 3 points to draw ( 0, 1, 2 )
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i ));
          const rP2 = Vec2.fromAngleScaled( angle, radii ).rot( a );

          Self.basicTria( pos.add( rP0 ), pos.add( rP2 ), pos.add( rP1 ), col );
          rP1 = rP2;
        }
      }
      else // NOTE : slightly faster, but requires isoscalar polygons
      {
        var rP1 = rP0.rot( sideStepAngle );

        for( 2..sides )| i | // Starting at two since each triangle needs 3 points to draw ( 0, 1, 2 )
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i ));
          const rP2 = rP0.rot( angle );

          Self.basicTria( pos.add( rP0 ), pos.add( rP2 ), pos.add( rP1 ), col );
          rP1 = rP2;
        }
      }
    }
    pub fn polyPerim( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, width : f64 ) void
    {
      if( sides < 1 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a polygon with 0 sides" );
        return;
      }

      const N : f32 = @floatFromInt( sides );
      const sideStepAngle = Angle.newRad( utl.TAU / N );
      const rP0 = Vec2.new( radii.x, 0.0 ).rot( a );

      if( sides < 3 ) // NOTE : only for radius or diametre lines
      {
        const rP1 = Vec2.fromAngleScaled( sideStepAngle, radii ).rot( a );

        if( sides == 1 ){ Self.basicLine( pos, pos.add( rP1 ), col, BASE_LINE_WIDTH ); }
        else { Self.basicLine( pos.add( rP1.flp() ), pos.add( rP1 ), col, BASE_LINE_WIDTH ); }
      }
      else if( !radii.isIso() ) // NOTE : slower, but accounts for non isoscalar polygons
      {
        var rP1 = rP0;

        for( 0..sides )| i |
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i + 1 ));
          const rP2 = Vec2.fromAngleScaled( angle, radii ).rot( a );

          Self.basicLine( pos.add( rP1 ), pos.add( rP2 ), col, width );
          rP1 = rP2;
        }
      }
      else // NOTE : slightly faster, but requires isoscalar polygons
      {
        var rP1 = rP0;

        for( 0..sides )| i |
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i + 1 ));
          const rP2 = rP0.rot( angle );

          Self.basicLine( pos.add( rP1 ), pos.add( rP2 ), col, width );
          rP1 = rP2;
        }
      }
    }


    pub fn star( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, skipFactor : u16 ) void
    {
      if( sides < 5 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with fewer than 5 vertices" );
        return;
      }

      if( skipFactor == 1 )
      {
        utl.qlog( .WARN, 0, @src(), "Not a star : drawing a polygon instead" );
        Self.poly( pos, radii, a, col, sides );
        return;
      }

      const N : f32 = @floatFromInt( sides );
      const sideStepAngle : Angle = Angle.newRad( utl.TAU / N );

      // Precompute all vertex positions
      var verts : [ 32 ]Vec2 = undefined; // 32 is enough for all defined star shapes FOR NOW

      if( !radii.isIso() ) // NOTE : slower, but accounts for non isoscalar polygons
      {
        for( 0..sides )| i |
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i ));
          verts[ i ]  = Vec2.fromAngleScaled( angle, radii ).rot( a );
        }
      }
      else // NOTE : slightly faster, but requires isoscalar polygons
      {
        for( 0..sides )| i |
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i ));
          verts[ i ]  = Vec2.new( radii.x, 0.0 ).rot( a.add( angle ));
        }
      }

      // Connect vertices by skipFactor step, drawing lines between them
      // NOTE : We need to traverse enough steps to close all sub-paths

      const gcdenom = utl.gcd( @as( u32, sides ), @as( u32, skipFactor )); // TODO : Implement me
      const pathLen = @divFloor( sides, gcdenom ); // Number of vertices per sub-path

      for( 0..gcdenom )| startIdx |
      {
        var idx1 : usize = startIdx;

        for( 0..pathLen )| _ |
        {
          const idx2 = ( idx1 + skipFactor ) % sides;
          Self.basicTria( pos, pos.add( verts[ idx2 ]), pos.add( verts[ idx1 ] ), col );
          idx1 = idx2;
        }
      }
    }
    pub fn starPerim( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, skipFactor : u16, width : f64 ) void
    {
      if( sides < 5 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with fewer than 5 vertices" );
        return;
      }

      if( skipFactor == 1 )
      {
        utl.qlog( .WARN, 0, @src(), "Not a star : drawing a polygon instead" );
        Self.polyPerim( pos, radii, a, col, sides, width );
        return;
      }

      const N : f32 = @floatFromInt( sides );
      const sideStepAngle : Angle = Angle.newRad( utl.TAU / N );

      // Precompute all vertex positions
      var verts : [ 32 ]Vec2 = undefined; // 32 is enough for all defined star shapes FOR NOW

      if( !radii.isIso() ) // NOTE : slower, but accounts for non isoscalar polygons
      {
        for( 0..sides )| i |
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i ));
          verts[ i ]  = Vec2.fromAngleScaled( angle, radii ).rot( a );
        }
      }
      else // NOTE : slightly faster, but requires isoscalar polygons
      {
        for( 0..sides )| i |
        {
          const angle = sideStepAngle.mulVal( @floatFromInt( i ));
          verts[ i ]  = Vec2.new( radii.x, 0.0 ).rot( a.add( angle ));
        }
      }

      // Connect vertices by skipFactor step, drawing lines between them
      // NOTE : We need to traverse enough steps to close all sub-paths

      const gcdenom = utl.gcd( @as( u32, sides ), @as( u32, skipFactor )); // TODO : Implement me
      const pathLen = @divFloor( sides, gcdenom ); // Number of vertices per sub-path

      for( 0..gcdenom )| startIdx |
      {
        var idx1 : usize = startIdx;

        for( 0..pathLen )| _ |
        {
          const idx2 = ( idx1 + skipFactor ) % sides;
          Self.basicLine( pos.add( verts[ idx2 ]), pos.add( verts[ idx1 ] ), col, width );
          idx1 = idx2;
        }
      }
    }


    // ================ TEXTURE DRAWING FUNCTIONS ================

    pub inline fn texture( image : ray.Texture2D, pos : Vec2, a : Angle, scale : Vec2, col : Colour ) void
    {
      ray.drawTextureEx( image, Transform.toRay( pos ), @floatCast( a.toDeg() ), @floatCast( scale.x ), col.toRayCol() );
    }

    pub inline fn textureCentered( image : ray.Texture2D, pos : Vec2, a : Angle, scale : Vec2, col : Colour ) void
    {
      const halfWidth  = @as( f64, @floatFromInt( image.width  )) * scale.x / 2.0;
      const halfHeight = @as( f64, @floatFromInt( image.height )) * scale.y / 2.0;
      Self.texture( image, .{ .x = pos.x - halfWidth, .y = pos.y - halfHeight }, a, scale, col );
    }

    // TODO : fix potential transform issues with rayrects
    pub inline fn texturePro( image : ray.Texture2D, source : RayRect, dest : RayRect, origin : Vec2, a : Angle, col : Colour ) void
    {
      ray.drawTexturePro( image, source, dest, origin.toRayVec2(), @floatCast( a.toDeg() ), col.toRayCol() );
    }
  };
}
