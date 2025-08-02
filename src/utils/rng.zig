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
      .int     => return self.rng.int( t ),       // from int_min to int_max
      .float   => return self.rng.float( t ),     // from 0.0 to 1.0
      .@"enum" => return self.rng.enumValue( t ), // from the enumeration values
      else => @compileError("Unsupported type for random value generation"),
    }
  }

  // Returns a random integer in the range [ min, max ] ( inclusive for both )
  pub fn getClampedInt( self : *randomiser, min : i32, max : i32 ) i32
  {

    var tmp : f32 = @floatFromInt( max - min ); // Getting the size of the range between [ min, max ]
    tmp += 0.9999999;             // Adding ~1 to the range to include maximum value in the rounded down result
    tmp =* self.rng.float( f32 ); // Getting a random float in the range [ 0, range + ~1 ]
    tmp += @floatFromInt( min );  // Adding the minimum value to the random float to get the range [ min, max + ~1 ]

    const res : i32 = @intFromFloat( @floor( tmp )); // Rounding down the value to get an integer in the range [ min, max ]
    return res;
  }

  // Returns a random angle in radians in the range [ 0, 2*PI )
  pub fn getAngleRad( self : *randomiser ) f32 { return self.rng.float( f32 ) * std.math.tau; }

  // Returns a random angle in degrees in the range [ 0, 360 )
  pub fn getAngleDeg( self : *randomiser ) f32 { return self.rng.float( f32 ) * 360.0; }

  // Returns a random float in in range [ offset - scale, offset + scale ]
  pub fn getScaledFloat( self : *randomiser, scale : f32, offset : f32 ) f32
  {
    const tmp = self.rng.float( f32 );

    tmp =  ( tmp * 2.0 ) - 1.0;      // Scale to range [-1, 1]
    return ( tmp * scale ) + offset; // Scale and offset the value
  }

  // Returns a random unit vector ( length of 1 in a random direction )
  pub fn getVec2( self : *randomiser ) def.Vec2
  {
    const angle = self.getAngleRad();
    return def.Vec2{ .x = @cos( angle ), .y = @sin( angle ) };

  }

  // Returns a random vector scaled by the given scale and offset by a given amount
  pub fn getScaledVec2( self : *randomiser, scale : def.Vec2, offset : def.Vec2 ) def.Vec2
  {
    var tmp = self.getVec2(); // Get a random unit vector

    tmp.x *= scale.x;  // Scale the x component
    tmp.y *= scale.y;  // Scale the y component

    tmp.x += offset.x; // Offset the x component
    tmp.y += offset.y; // Offset the y component

    return tmp;
  }

  // Returns a random vector in 2D + rotation space ( length of 1 in a random direction and rotation )
  pub fn getVecR( self : *randomiser ) def.VecR
  {
    const angle = self.getAngleRad();
    return def.VecR{ .x = @cos( angle ), .y = @sin( angle ), .z = self.getAngleRad() };
  }

  // Returns a random vector in 2D + rotation space scaled by the given scale and offset by a given amount
  pub fn getScaledVecR( self : *randomiser, scale : def.VecR, offset : def.VecR ) def.VecR
  {
    var tmp = self.getVecR(); // Get a random unit vector

    tmp.x *= scale.x;  // Scale the x component
    tmp.y *= scale.y;  // Scale the y component
    tmp.z *= scale.z;  // Scale the rotation component

    tmp.x += offset.x; // Offset the x component
    tmp.y += offset.y; // Offset the y component
    tmp.z += offset.z; // Offset the rotation component

    return tmp;
  }


  // Returns a random unit vector in 3D space ( length of 1 in a random direction )
  pub fn getVec3( self : *randomiser ) def.Vec3
  {
    const theta = self.rng.float( f32 ) * std.math.tau; // [0, 2π)
    const z =   ( self.rng.float( f32 ) * 2.0 ) - 1.0;  // [-1, 1] // NOTE : Prevents the vector from being too close to the poles, garnteeing a uniform distribution in 3D space
    const r = @sqrt( 1.0 - z * z );

    return def.Vec3{
      .x = r * @cos( theta ),
      .y = r * @sin( theta ),
      .z = z,
    };
  }

  // Returns a random vector in 3D space scaled by the given scale and offset by a given amount
  pub fn getScaledVec3( self : *randomiser, scale : def.Vec3, offset : def.Vec3 ) def.Vec3
  {
    var tmp = self.getVec3(); // Get a random unit vector

    tmp.x *= scale.x;  // Scale the x component
    tmp.y *= scale.y;  // Scale the y component
    tmp.z *= scale.z;  // Scale the z component

    tmp.x += offset.x; // Offset the x component
    tmp.y += offset.y; // Offset the y component
    tmp.z += offset.z; // Offset the z component

    return tmp;
  }
};