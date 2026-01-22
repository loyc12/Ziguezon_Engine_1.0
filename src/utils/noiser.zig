const std = @import( "std" );
const def = @import( "defs" );

const Vec2    = def.Vec2;
const Coords2 = def.Coords2;

//const Angle = def.Angle;
//const VecA  = def.VecA;
//const Vec3  = def.Vec3;

const GRAD_BITS  = 8;
const GRAD_COUNT = def.pow2( GRAD_BITS );

pub const gradients : [ GRAD_COUNT ]Vec2 = blk:
{
  var table : [ GRAD_COUNT ]Vec2 = undefined;

  const tau = def.TAU;

  var i : usize = 0;
  while( i < GRAD_COUNT ) : ( i += 1 )
  {
    const angle = tau * (( @as( f32, i ) + 0.5 ) / @as( f32, GRAD_COUNT ));
    table[ i ] =
    .{
      .x = @cos( angle ),
      .y = @sin( angle ),
    };
  }

  break :blk table;
};


inline fn quinticFade( t : f32 ) f32 // f(t) = 6t⁵ − 15t⁴ + 10t³ for t between 0.0 and 1.0
{
  return( t * t * t * ( t * (( t * 6 ) - 15 ) + 10 ));
}

fn hash2( seed : u64, coords : Coords2 ) u64
{
  var h = seed;

  h ^= @as( u64, @bitCast( @as( i64, coords.x ))) *% 0x9E3779B185EBCA87;
  h ^= @as( u64, @bitCast( @as( i64, coords.y ))) *% 0xC2B2AE3D27D4EB4F;

  h ^= h >> 27;
  h *%= 0x94D049BB133111EB;

  return ( h ^ ( h >> 31 ));
}

//inline fn toFloat( val : u64 ) f32
//{
//  const denom: f32 = @floatFromInt( std.math.maxInt( u64 ));
//  return @as( f32, @floatFromInt( val )) / denom;
//}

fn gradDotProd( seed : u64, coords : Coords2, cellPos : Vec2 ) f32
{
  const h = hash2( seed, coords );

  const g = gradients[ @as( usize, @intCast( h & ( GRAD_COUNT - 1 )))];

  return( g.x * cellPos.x + g.y * cellPos.y );
}



// ================================ NOISE 2D STRUCT ================================

pub const Noise2D = struct
{
  seed : u64,

  warpCount    : u32 = 1,   // >= 0   : The amount of successive warp passes
  warpStrenght : f32 = 1.0, // >= 0.0 : The strenght of the input position warping

  octaveCount : u32 = 4,   // > 0       : The amount of fractal layer                    ( layerCount      )
  persistence : f32 = 0.5, // 0.0 - 1.0 : The relative strenght of each successive layer ( amplitudeFactor )
  lacunarity  : f32 = 2.0, // > 1.0     : The relative scale of each successive layer    ( frequencyFactor )

  pub fn simpleSample( self : Noise2D, pos : Vec2 ) f32
  {
    return( def.R2 * self.baseSample( pos )); // NOTE : Compensating for output range of [-~0.707, +~0.707]
  }

  inline fn baseSample( self : Noise2D, pos : Vec2 ) f32
  {
    const coords : Coords2 =
    .{
      .x = @intFromFloat( @floor( pos.x )),
      .y = @intFromFloat( @floor( pos.y )),
    };

    const cellPos = pos.sub( coords.toVec2() );

    const u = quinticFade( cellPos.x );
    const v = quinticFade( cellPos.y );

  // NOTE : Debug implementation to test quinticFade() & hash2() only ( no gradient interpolation )
  //const n00 = toFloat( hash2( self.seed, pos.toCoords2().add( .{ .x = 0, .y = 0 })));
  //const n10 = toFloat( hash2( self.seed, pos.toCoords2().add( .{ .x = 1, .y = 0 })));
  //const n01 = toFloat( hash2( self.seed, pos.toCoords2().add( .{ .x = 0, .y = 1 })));
  //const n11 = toFloat( hash2( self.seed, pos.toCoords2().add( .{ .x = 1, .y = 1 })));

    const n00 = gradDotProd( self.seed, coords.add( .{ .x = 0, .y = 0 }), cellPos.sub( .{ .x = 0, .y = 0 }) );
    const n10 = gradDotProd( self.seed, coords.add( .{ .x = 1, .y = 0 }), cellPos.sub( .{ .x = 1, .y = 0 }) );
    const n01 = gradDotProd( self.seed, coords.add( .{ .x = 0, .y = 1 }), cellPos.sub( .{ .x = 0, .y = 1 }) );
    const n11 = gradDotProd( self.seed, coords.add( .{ .x = 1, .y = 1 }), cellPos.sub( .{ .x = 1, .y = 1 }) );

    const nx0 = def.lerp( n00, n10, u );
    const nx1 = def.lerp( n01, n11, u );

    return def.lerp( nx0, nx1, v );
  }


  pub fn warpedSample( self : Noise2D, pos : Vec2 ) f32
  {
    return( self.simpleSample( self.warpPos( pos )));
  }

  inline fn warpPos( self : Noise2D, pos : Vec2 ) Vec2
  {
    var tmp : Vec2 = pos;

    var i : u32 = 0;

    while( i < self.warpCount )
    {
      tmp = self.baseWarpPos( tmp );
      i += 1;
    }

    return tmp;
  }

  inline fn baseWarpPos( self : Noise2D, pos : Vec2 ) Vec2
  {
    if( self.warpStrenght == 0.0 ) return pos;

    const wx = self.baseSample( pos.add( .{ .x = 79.0, .y = 67.0 }));
    const wy = self.baseSample( pos.add( .{ .x = 53.0, .y = 97.0 }));

    return pos.add( .{ .x = wx * self.warpStrenght, .y = wy * self.warpStrenght });
  }


  pub fn warpedFractalSample( self : Noise2D, pos : Vec2 ) f32
  {
    var value     : f32 = 0.0;
    var maxAmp    : f32 = 0.0;

    var amplitude : f32 = 1.0;
    var frequency : f32 = 1.0;

    var i : u32 = 0;
    while( i < self.octaveCount )
    {
      const v = self.simpleSample( self.warpPos( pos.mulVal( frequency ) ));

      value  += amplitude * v;
      maxAmp += amplitude;

      amplitude *= self.persistence;
      frequency *= self.lacunarity;

      i += 1;
    }

    // Normalize to roughly [-1, 1]
    return( value / maxAmp );
  }

  pub fn simpleFractalSample( self : Noise2D, pos : Vec2 ) f32
  {
    var value     : f32 = 0.0;
    var maxAmp    : f32 = 0.0;

    var amplitude : f32 = 1.0;
    var frequency : f32 = 1.0;

    var i : u32 = 0;
    while( i < self.octaveCount )
    {
      const v = self.simpleSample( pos.mulVal( frequency ));

      value  += amplitude * v;
      maxAmp += amplitude;

      amplitude *= self.persistence;
      frequency *= self.lacunarity;

      i += 1;
    }

    // Normalize to roughly [-1, 1]
    return( value / maxAmp );
  }
};