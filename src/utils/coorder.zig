const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const VecR = def.VecR;
const Vec3 = def.Vec3;

pub const Coords2 = struct
{
  x : i32 = 0,
  y : i32 = 0,

  // ================ GENERATION ================

  pub fn new( x : i32, y : i32 ) Coords2 { return Coords2{ .x = x, .y = y }; }

  pub fn toVec2( self : Coords2 )          Vec2 { return Vec2{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y )}; }
  pub fn toVecR( self : Coords2, r : f32 ) VecR { return VecR{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y ), .z = r }; }
  pub fn toVec3( self : Coords2, z : f32 ) Vec3 { return Vec3{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y ), .z = z }; }

  // ================ COMPARISONS ================

  pub fn isPos(  self : Coords2 ) bool { return self.x >= 0 and self.y >= 0; }
  pub fn isZero( self : Coords2 ) bool { return self.x == 0 and self.y == 0; }

  pub fn areEq(   self : Coords2, other : Coords2 ) bool { return self.x == other.x and self.y == other.y; }
  pub fn areDiff( self : Coords2, other : Coords2 ) bool { return self.x != other.x or  self.y != other.y; }

  // ================ OPERATIONS ================

  pub fn add( self : Coords2, other : Coords2 ) Coords2 { return Coords2{ .x = self.x + other.x, .y = self.y + other.y }; }
  pub fn sub( self : Coords2, other : Coords2 ) Coords2 { return Coords2{ .x = self.x - other.x, .y = self.y - other.y }; }

  pub fn addVal( self : Coords2, val : i32 ) Coords2 { return Coords2{ .x = self.x + val, .y = self.y + val }; }
  pub fn subVal( self : Coords2, val : i32 ) Coords2 { return Coords2{ .x = self.x - val, .y = self.y - val }; }

  pub fn mulVal( self : Coords2, f : f32 ) Coords2
  {
    return Coords2{
      .x = @intFromFloat( @round( @as( f32, @floatFromInt( self.x )) * f )),
      .y = @intFromFloat( @round( @as( f32, @floatFromInt( self.y )) * f )),
    };
  }

  pub fn divVal( self : Coords2, f : f32 ) ?Coords2
  {
    if( f == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Coords2.div()" );
      return null;
    }
    return Coords2{
      .x = @intFromFloat( @round( @as( f32, @floatFromInt( self.x )) / f )),
      .y = @intFromFloat( @round( @as( f32, @floatFromInt( self.y )) / f )),
    };
  }
};

pub const Coords3 = struct
{
  x : i32 = 0,
  y : i32 = 0,
  z : i32 = 0,

  // ================ GENERATION ================

  pub fn new( x : i32, y : i32, z : i32 ) Coords3 { return Coords3{ .x = x, .y = y, .z = z }; }

  pub fn toVec3( self : Coords3 ) Vec3
  {
    return Vec3{
      .x = @floatFromInt( self.x ),
      .y = @floatFromInt( self.y ),
      .z = @floatFromInt( self.z ),
    };
  }

  // ================ COMPARISONS ================

  pub fn isPos(  self : Coords3 ) bool { return self.x >= 0 and self.y >= 0 and self.z >= 0; }
  pub fn isZero( self : Coords3 ) bool { return self.x == 0 and self.y == 0 and self.z == 0; }

  pub fn areEq(   self : Coords3, other : Coords3 ) bool { return self.x == other.x and self.y == other.y and self.z == other.z; }
  pub fn areDiff( self : Coords3, other : Coords3 ) bool { return self.x != other.x or  self.y != other.y or  self.z != other.z; }

  // ================ OPERATIONS ================

  pub fn add( self : Coords3, other : Coords3 ) Coords3 { return Coords3{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z }; }
  pub fn sub( self : Coords3, other : Coords3 ) Coords3 { return Coords3{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z }; }

  pub fn addVal( self : Coords3, val : i32 ) Coords3 { return Coords3{ .x = self.x + val, .y = self.y + val, .z = self.z - val }; }
  pub fn subVal( self : Coords3, val : i32 ) Coords3 { return Coords3{ .x = self.x - val, .y = self.y - val, .z = self.z - val }; }

  pub fn mulVal( self : Coords3, f : f32 ) Coords3
  {
    return Coords3{
      .x = @intFromFloat( @round( @as( f32, @floatFromInt( self.x )) * f )),
      .y = @intFromFloat( @round( @as( f32, @floatFromInt( self.y )) * f )),
      .z = @intFromFloat( @round( @as( f32, @floatFromInt( self.z )) * f )),
    };
  }

  pub fn divVal( self : Coords3, f : f32 ) ?Coords3
  {
    if( f == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Coords3.div()" );
      return null;
    }
    return Coords3{
      .x = @intFromFloat( @round( @as( f32, @floatFromInt( self.x )) / f )),
      .y = @intFromFloat( @round( @as( f32, @floatFromInt( self.y )) / f )),
      .z = @intFromFloat( @round( @as( f32, @floatFromInt( self.z )) / f )),
    };
  }
};

