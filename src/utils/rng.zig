const std = @import( "std" );
const def = @import( "defs" );

const RandType : type = std.Random.Xoshiro256;

pub const randomiser = struct
{
  prng : RandType   = undefined,
  rng  : std.Random = undefined,

  pub fn randInit( self : *randomiser ) void { self.seedInit( def.timer.getNow() ); }
  pub fn seedInit( self : *randomiser, seed : i128 ) void
  {
    const val : u128 = @intCast( seed );
    const top : u64  = @intCast( val & 0xFFFFFFFFFFFFFFFF0000000000000000 );
    const bot : u64  = @intCast( val & 0x0000000000000000FFFFFFFFFFFFFFFF );

    self.prng = RandType.init( top + bot ); // Reseeding the prng

    // Reinitializing the rng wrapper with the new prng
    self.rng = std.Random.init( &self.prng, std.Random.Xoshiro256.fill );
  }

  pub fn getVal( self : *randomiser, t : type ) t
  {
    switch( @typeInfo( t ))
    {
      .int     => return self.rng.randomInt( t ),
      .float   => return self.rng.randomFloat( t ),
      .@"enum" => return self.rng.randomEnum( t ),
      else => @compileError("Unsupported type for random value generation"),
    }
  }

  pub fn getVec2( self : *randomiser ) def.vec2
  {
    var tmp = def.vec2{ .x = self.rng.float( f32 ), .y = self.rng.float( f32 ) };

    // Scale to range [-1, 1]
    tmp.x = ( tmp.x * 2.0 ) - 1.0;
    tmp.y = ( tmp.y * 2.0 ) - 1.0;

    return tmp;
  }

  pub fn getVec2Scaled( self : *randomiser, scale : def.vec2, offset : def.vec2 ) def.vec2
  {
    const tmp = self.getVec2();
    return def.vec2{ .x = ( tmp.x * scale.x ) + offset.x, .y = ( tmp.y * scale.y ) + offset.y };
  }
};