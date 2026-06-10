const eng = @import( "engine" );
const utl = @import( "utils" );

const ray     = utl.ray;
const Vec2    = utl.Vec2;
const Angle   = utl.Angle;
const Colour  = utl.Colour;
const RayRect = utl.RayRect;

const MAX_POLY_SIDES = 256;


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
    pub inline fn elli( pos : Vec2, radii : Vec2, a : Angle, col : Colour ) void { Self.poly( pos, radii, a, col, eng.G_CNFGS.Graphic_Ellipse_Facets ); }


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

    pub fn calcPolyVertices( radii : Vec2, a : Angle, sides : u16, out : []Vec2 ) bool
    {
      // Validation pass
      if( sides == 0 )
      {
        utl.qlog(.ERROR, 0, @src(), "Cannot draw a polygon with 0 sides");
        return false;
      }

      const count : usize = @intCast( sides );

      if( count > out.len )
      {
        utl.qlog(.ERROR, 0, @src(), "Polygon side count exceeds temporary vertex buffer");
        return false;
      }

      // Special cases
      if( sides <= 2 )
      {
        const p = Vec2.new( radii.x, 0.0 ).rot( a );

                          out[ 0 ] = p;
        if( sides == 2 ){ out[ 1 ] = p.flp(); }

        return true;
      }

      // General cases
      const n : f32 = @floatFromInt( sides );
      const angleStep = Angle.newRad( utl.TAU / n );

      if ( radii.isIso() )
      {
        const p0 = Vec2.new( radii.x, 0.0 ).rot( a );

        for( 0..count )| i |
        {
          const angle = angleStep.mulVal( @floatFromInt( i ));
          out[ i ] = p0.rot( angle );
        }
      }
      else
      {
        for( 0..count )| i |
        {
          const angle = angleStep.mulVal( @floatFromInt( i ));
          out[ i ] = Vec2.fromAngleScaled( angle, radii ).rot( a );
        }
      }

      return true;
    }


    // Draws a polygon centered at a given position with specified rotation (rad), colour and facet count, and scaled in x/y by radii
    pub fn poly( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16 ) void
    {
      var verts : [ MAX_POLY_SIDES ]Vec2 = undefined;

      if( !calcPolyVertices( radii, a, sides, verts[ 0.. ]))
      {
        utl.qlog( .ERROR, 0, @src(), "Failed to fill vertex array" );
        return;
      }

      // Special cases
      if( sides <= 2 )
      {
        const p1 = pos.add( verts[ 0 ]);
        var   p2 = pos;

        if( sides == 2 ){ p2 = p2.add( verts[ 1 ]); }

        basicLine( p1, p2, col, BASE_LINE_WIDTH );
        return;
      }

      // General case
      const count : usize = @intCast( sides );

      const p0 = pos.add( verts[ 0 ]);
      var   p1 = Vec2.new( 0, 0 );
      var   p2 = pos.add( verts[ 1 ]);

      for( 2..count )| i | // Triangle fan using vertex 0 as the fixed anchor
      {
        p1 = p2;
        p2 = pos.add( verts[ i ]);

        basicTria( p0, p2, p1, col );
      }
    }
    pub fn polyPerim( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, width : f64 ) void
    {
      var verts : [ MAX_POLY_SIDES ]Vec2 = undefined;

      if( !calcPolyVertices( radii, a, sides, verts[ 0.. ]))
      {
        utl.qlog( .ERROR, 0, @src(), "Failed to fill vertex array" );
        return;
      }

      // Special cases
      if( sides <= 2 )
      {
        const p1 = pos.add( verts[ 0 ]);
        var   p2 = pos;

        if( sides == 2 ){ p2 = p2.add( verts[ 1 ]); }

        basicLine( p1, p2, col, width );
        return;
      }

      // General case
      const count : usize = @intCast( sides );

      var p1 = pos.add( verts[ count - 1 ]);
      var p2 = pos.add( verts[ 0 ]);

      basicLine( p1, p2, col, width );

      for( 1..count )| i | // Drawing each remaining edge individually
      {
        p1 = p2;
        p2 = pos.add( verts[ i ]);

        basicLine( p1, p2, col, width );
      }
    }


    pub fn polyStar( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, skipFactor : u16 ) void
    {
      if( sides < 5 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with fewer than 5 vertices" );
        return;
      }
      if( skipFactor == 0 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with a skip factor of 0" );
        return;
      }
      if( skipFactor >= sides )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with a skipFactor equal or greater than sides : use modulo for that" );
        return;
      }

      const skip  : usize = @intCast( @min( skipFactor, sides - skipFactor ));

      if( skip == 1 )
      {
        utl.qlog( .TRACE, 0, @src(), "Not a star : drawing a polygon instead" );

        poly( pos, radii, a, col, sides );
        return;
      }

      const count : usize = @intCast( sides );

      var verts : [ MAX_POLY_SIDES ]Vec2 = undefined;

      if( !calcPolyVertices( radii, a, sides, verts[ 0.. ] ))
      {
        utl.qlog( .ERROR, 0, @src(), "Failed to fill vertex array" );
        return;
      }

      const gcdenom_u32 = utl.gcd( @as( u32, @intCast( sides )), @as( u32, @intCast( skip )));
      const gcdenom : usize = @intCast( gcdenom_u32 );
      const pathLen : usize = count / gcdenom;

      for( 0..gcdenom )| startIdx |
      {
        var idx1 : usize = startIdx;

        for( 0..pathLen )| _ |
        {
          const idx2 = ( idx1 + skip ) % count;

          basicTria( pos, pos.add( verts[ idx2 ]), pos.add( verts[ idx1 ]), col );

          idx1 = idx2;
        }
      }
    }
    pub fn polyStarPerim( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, skipFactor : u16, width : f64 ) void
    {
      if( sides < 5 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with fewer than 5 vertices" );
        return;
      }
      if( skipFactor == 0 )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with a skip factor of 0" );
        return;
      }
      if( skipFactor >= sides )
      {
        utl.qlog( .ERROR, 0, @src(), "Cannot draw a star with a skipFactor equal or greater than sides : use modulo for that" );
        return;
      }

      const skip  : usize = @intCast( @min( skipFactor, sides - skipFactor ));

      if( skip == 1 )
      {
        utl.qlog( .TRACE, 0, @src(), "Not a star : drawing a polygon instead" );

        polyPerim( pos, radii, a, col, sides, width );
        return;
      }

      const count : usize = @intCast( sides );

      var verts : [ MAX_POLY_SIDES ]Vec2 = undefined;

      if( !calcPolyVertices( radii, a, sides, verts[ 0.. ] ))
      {
        utl.qlog( .ERROR, 0, @src(), "Failed to fill vertex array" );
        return;
      }

      const gcdenom_u32 = utl.gcd( @as( u32, @intCast( sides )), @as( u32, @intCast( skip )));
      const gcdenom : usize = @intCast( gcdenom_u32 );
      const pathLen : usize = count / gcdenom;

      for( 0..gcdenom )| startIdx |
      {
        var idx1 : usize = startIdx;

        for( 0..pathLen )| _ |
        {
          const idx2 = ( idx1 + skip ) % count;

          basicLine( pos.add( verts[ idx2 ]), pos.add( verts[ idx1 ]), col, width );

          idx1 = idx2;
        }
      }
    }

    pub fn polySpokes( pos : Vec2, radii : Vec2, a : Angle, col : Colour, sides : u16, width : f64 ) void
    {
      var verts : [ MAX_POLY_SIDES ]Vec2 = undefined;

      if( !calcPolyVertices( radii, a, sides, verts[ 0.. ] ))
      {
        utl.qlog( .ERROR, 0, @src(), "Failed to fill vertex array" );
        return;
      }

      const count : usize = @intCast( sides );

      for( 0..count )| i |
      {
        basicLine(
          pos,
          pos.add( verts[ i ]),
          col,
          width,
        );
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
