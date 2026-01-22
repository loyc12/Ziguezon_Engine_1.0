const std = @import( "std" );
const def = @import( "defs" );

const Angle = def.Angle;
const Vec2  = def.Vec2;
const VecA  = def.VecA;
const Vec3  = def.Vec3;

const RandType : type = std.Random.Xoshiro256;


// ================================ GLOBAL RANDOM NUMBER GENERATOR ================================

pub var G_NSE : noiseGenerator = .{};

pub fn initGlobalNSE() void
{
  G_NSE.randInit();
  def.qlog( .INFO, 0, @src(), "Random number generator initialized\n" );
}

pub fn seedGlobalNSE( seed : i128 ) void
{
  G_NSE.seedInit( seed );
  def.qlog( .INFO, 0, @src(), "Random number generator seeded with {d}", .{ seed });
}


// ================================ NOISE GENERATOR STRUCT ================================

pub const noiseGenerator = struct
{
  prng : RandType   = undefined,
  rng  : std.Random = undefined,

  pub fn randInit( self : *noiseGenerator ) void { self.seedInit( def.getNow().value ); }
  pub fn seedInit( self : *noiseGenerator, seed : i128 ) void
  {
    const val : u128 = @intCast( seed );
    const top : u64  = @intCast(( val & 0xFFFFFFFFFFFFFFFF0000000000000000 ) >> 16 );
    const bot : u64  = @intCast(( val & 0x0000000000000000FFFFFFFFFFFFFFFF ));

    self.prng = RandType.init( top + bot );


    // Reinitializing the rng wrapper with the new prng
    self.rng = std.Random.init( &self.prng, std.Random.Xoshiro256.fill );
  }
};