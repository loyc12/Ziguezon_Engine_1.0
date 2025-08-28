const std = @import( "std" );
const def = @import( "defs" );

const Angle = def.Angle;
const Vec2  = def.Vec2;
const VecA  = def.VecA;
const Vec3  = def.Vec3;

const RandType : type = std.Random.Xoshiro256;


// ================================ GLOBAL RANDOM NUMBER GENERATOR ================================

pub var G_RNG : randomiser = .{};

pub fn initGlobalRNG() void
{
  G_RNG.randInit();
  def.qlog( .INFO, 0, @src(), "Random number generator initialized" );
}

pub fn seedGlobalRNG( seed : i128 ) void
{
  G_RNG.seedInit( seed );
  def.qlog( .INFO, 0, @src(), "Random number generator seeded with {d}", .{ seed });
}


// ================================ RANDOMISER STRUCT ================================

pub const randomiser = struct
{
  prng : RandType   = undefined,
  rng  : std.Random = undefined,

  pub fn randInit( self : *randomiser ) void { self.seedInit( def.tmr_u.getNow() ); }
  pub fn seedInit( self : *randomiser, seed : i128 ) void
  {
    const val : u128 = @intCast( seed );
    const top : u64  = @intCast( val & 0xFFFFFFFFFFFFFFFF0000000000000000 );
    const bot : u64  = @intCast( val & 0x0000000000000000FFFFFFFFFFFFFFFF );

    self.prng = RandType.init( top + bot );

    // Reinitializing the rng wrapper with the new prng
    self.rng = std.Random.init( &self.prng, std.Random.Xoshiro256.fill );
  }

  pub fn getBool(  self : *randomiser ) bool { return self.rng.int( u1 ) == 1; }
  pub fn getInt(   self : *randomiser, comptime t : type ) t { return self.rng.int( t ); }
  pub fn getFloat( self : *randomiser, comptime t : type ) t { return self.rng.float( t ); }
  pub fn getVal(   self : *randomiser, comptime t : type ) t // for any type supported by std.rand
  {
    switch( @typeInfo( t ))
    {
      .bool    => return self.rng.int( u1 ) == 1, // true or false
      .int     => return self.rng.int(       t ), // from int_min to int_max
      .float   => return self.rng.float(     t ), // from 0.0 to 1.0
      .@"enum" => return self.rng.enumValue( t ), // from the enumeration values
      else => @compileError( "Unsupported type for random value generation" ),
    }
  }

  // Returns a random integer in the range [ min, max ] ( inclusive for both )
  pub fn getClampedInt( self : *randomiser, min : i32, max : i32 ) i32
  {

    var tmp : f32 = @floatFromInt( max - min ); // Getting the size of the range between [ min, max ]
    tmp += 1 - def.EPS;           // Adding ~1 to the range to include maximum value in the rounded down result
    tmp *= self.rng.float( f32 ); // Getting a random float in the range [ 0, range + ~1 ]
    tmp += @floatFromInt( min );  // Adding the minimum value to the random float to get the range [ min, max + ~1 ]

    return @as( i32, @intFromFloat( @floor( tmp ))); // Rounding down the value to get an integer in the range [ min, max ]
  }

  // Returns a random angle in radians in the range [ 0, 2*PI )
  pub fn getAngle( self : *randomiser ) Angle { return Angle.newRad( self.rng.float( f32 ) * def.TAU ); }

  pub fn getScaledAngle( self : *randomiser, scale : Angle, offset : Angle ) Angle
  {
    var tmp = self.rng.float( f32 ); // Get a random float in the range [ 0.0, 1.0 )

    tmp = ( tmp * 2.0 ) - 1.0;         // Scale to range [-1.0, 1.0 )
    tmp = ( tmp * scale.toRad() ) + offset.toRad(); // Scale and offset the value

    return Angle.newRad( tmp );
  }

  // Returns a random float in in range [ offset - scale, offset + scale ]
  pub fn getScaledFloat( self : *randomiser, scale : f32, offset : f32 ) f32
  {
    var tmp = self.rng.float( f32 );

    tmp = ( tmp * 2.0 ) - 1.0;      // Scale to range [-1, 1]
    return( tmp * scale ) + offset; // Scale and offset the value
  }

  // Returns a random unit vector ( length of 1 in a random direction )
  pub fn getVec2( self : *randomiser ) Vec2
  {
    const angle = self.getAngleRad();

    return Vec2{ .x = @cos( angle ), .y = @sin( angle ) };
  }

  // Returns a random vector scaled by the given scale and offset by a given amount
  pub fn getScaledVec2( self : *randomiser, scale : Vec2, offset : Vec2 ) Vec2
  {
    var tmp = self.getVec2(); // Get a random unit vector

    tmp.x *= scale.x;
    tmp.y *= scale.y;

    tmp.x += offset.x;
    tmp.y += offset.y;

    return tmp;
  }

  // Returns a random vector in 2D + rotation space ( length of 1 in a random direction and rotation )
  pub fn getVecA( self : *randomiser ) VecA
  {
    const a = self.getAngle();
    return VecA{ .x = a.cos(), .y = a.sin(), .a = self.getAngle() };
  }

  // Returns a random vector in 2D + rotation space scaled by the given scale and offset by a given amount
  pub fn getScaledVecA( self : *randomiser, scale : VecA, offset : VecA ) VecA
  {
    var tmp = self.getVecA(); // Get a random unit vector

    tmp.x *= scale.x;
    tmp.y *= scale.y;

    tmp.x += offset.x;
    tmp.y += offset.y;

    return tmp;
  }


  // Returns a random unit vector in 3D space ( length of 1 in a random direction )
  pub fn getVec3( self : *randomiser ) Vec3
  {
    const theta = self.rng.float( f32 ) * def.TAU; // [0, 2π)
    const z =   ( self.rng.float( f32 ) * 2.0 ) - 1.0;  // [-1, 1] // NOTE : Prevents the vector from being too close to the poles, garanteeing a uniform distribution in 3D space
    const r = @sqrt( 1.0 - z * z );

    return Vec3{
      .x = r * @cos( theta ),
      .y = r * @sin( theta ),
      .z = z,
    };
  }

  // Returns a random vector in 3D space scaled by the given scale and offset by a given amount
  pub fn getScaledVec3( self : *randomiser, scale : Vec3, offset : Vec3 ) Vec3
  {
    var tmp = self.getVec3(); // Get a random unit vector

    tmp.x *= scale.x;
    tmp.y *= scale.y;
    tmp.z *= scale.z;

    tmp.x += offset.x;
    tmp.y += offset.y;
    tmp.z += offset.z;

    return tmp;
  }

  pub fn getColour( self : *randomiser ) def.Colour
  {
    return def.Colour{
      .r = @intFromFloat( @floor( self.rng.float( f32 ) * 255.999 )),
      .g = @intFromFloat( @floor( self.rng.float( f32 ) * 255.999 )),
      .b = @intFromFloat( @floor( self.rng.float( f32 ) * 255.999 )),
      .a = 255,
    };
  }
};