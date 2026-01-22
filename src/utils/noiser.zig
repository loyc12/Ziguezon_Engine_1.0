const std = @import( "std" );
const def = @import( "defs" );

const Vec2    = def.Vec2;
const Coords2 = def.Coords2;

//const Angle = def.Angle;
//const VecA  = def.VecA;
//const Vec3  = def.Vec3;

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

inline fn toFloat( val : u64 ) f32
{
  const denom: f32 = @floatFromInt( std.math.maxInt( u64 ));
  return @as( f32, @floatFromInt( val )) / denom;
}

const gradients = [ _ ][ 2 ]f32
{
  .{ 1,  0 }, .{ -1,  0 },
  .{ 0,  1 }, .{  0, -1 },
  .{ 1,  1 }, .{ -1,  1 },
  .{ 1, -1 }, .{ -1, -1 },
};

fn gradDotProd( seed : u64, coords : Coords2, cellPos : Vec2 ) f32
{
  const h = hash2( seed, coords );
  const g = gradients[ h & 0b111 ];

  return( g[ 0 ] * cellPos.x + g[ 1 ] * cellPos.y );
}

// ================================ NOISE 2D STRUCT ================================

pub const Noise2D = struct
{
  seed : u64,

  pub fn sample( self : Noise2D, pos : Vec2 ) f32
  {
    const coords : Coords2 =
    .{
      .x = @intFromFloat( @floor( pos.x )),
      .y = @intFromFloat( @floor( pos.y )),
    };

    const cellPos = pos.sub( coords.toVec2() );

    const u = quinticFade( cellPos.x );
    const v = quinticFade( cellPos.y );

  // NOTE : Debug implementation to show sample() results without gradient dot product
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
};