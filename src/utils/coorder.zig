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

  pub inline fn new( x : i32, y : i32 ) Coords2 { return Coords2{ .x = x, .y = y }; }

  pub inline fn toVec2( self : Coords2 )          Vec2 { return Vec2{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y )}; }
  pub inline fn toVecR( self : Coords2, r : f32 ) VecR { return VecR{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y ), .z = r }; }
  pub inline fn toVec3( self : Coords2, z : f32 ) Vec3 { return Vec3{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y ), .z = z }; }

  // ================ COMPARISONS ================

  pub inline fn isPos(  self : Coords2 ) bool { return self.x >= 0 and self.y >= 0; }
  pub inline fn isZero( self : Coords2 ) bool { return self.x == 0 and self.y == 0; }

  pub inline fn isEq(    self : Coords2, other : Coords2 ) bool { return self.x == other.x and self.y == other.y; }
  pub inline fn isDiff(  self : Coords2, other : Coords2 ) bool { return self.x != other.x or  self.y != other.y; }
  pub inline fn isInfXY( self : Coords2, other : Coords2 ) bool { return self.x <  other.x or  self.y <  other.y; }
  pub inline fn isSupXY( self : Coords2, other : Coords2 ) bool { return self.x >  other.x or  self.y >  other.y; }

  // ================ OPERATIONS ================

  pub inline fn add( self : Coords2, other : Coords2 ) Coords2 { return Coords2{ .x = self.x + other.x, .y = self.y + other.y }; }
  pub inline fn sub( self : Coords2, other : Coords2 ) Coords2 { return Coords2{ .x = self.x - other.x, .y = self.y - other.y }; }

  pub inline fn addVal( self : Coords2, val : i32 ) Coords2 { return Coords2{ .x = self.x + val, .y = self.y + val }; }
  pub inline fn subVal( self : Coords2, val : i32 ) Coords2 { return Coords2{ .x = self.x - val, .y = self.y - val }; }

  pub inline fn mulVal( self : Coords2, f : f32 ) Coords2
  {
    return Coords2{
      .x = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.x )) * f )),
      .y = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.y )) * f )),
    };
  }

  pub inline fn divVal( self : Coords2, f : f32 ) ?Coords2
  {
    if( f == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Coords2.div()" );
      return null;
    }
    return Coords2{
      .x = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.x )) / f )),
      .y = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.y )) / f )),
    };
  }
};

pub const Coords3 = struct
{
  x : i32 = 0,
  y : i32 = 0,
  z : i32 = 0,

  // ================ GENERATION ================

  pub inline fn new( x : i32, y : i32, z : i32 ) Coords3 { return Coords3{ .x = x, .y = y, .z = z }; }

  pub inline fn toVec3( self : Coords3 ) Vec3
  {
    return Vec3{
      .x = @floatFromInt( self.x ),
      .y = @floatFromInt( self.y ),
      .z = @floatFromInt( self.z ),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPos(  self : Coords3 ) bool { return self.x >= 0 and self.y >= 0 and self.z >= 0; }
  pub inline fn isZero( self : Coords3 ) bool { return self.x == 0 and self.y == 0 and self.z == 0; }

  pub inline fn isEq(     self : Coords3, other : Coords3 ) bool { return self.x == other.x and self.y == other.y and self.z == other.z; }
  pub inline fn isDiff(   self : Coords3, other : Coords3 ) bool { return self.x != other.x or  self.y != other.y or  self.z != other.z; }
  pub inline fn isInfXYZ( self : Coords2, other : Coords2 ) bool { return self.x <  other.x or  self.y <  other.y or  self.z < other.z; }
  pub inline fn isSupXYZ( self : Coords2, other : Coords2 ) bool { return self.x >  other.x or  self.y >  other.y or  self.z > other.z; }

  // ================ OPERATIONS ================

  pub inline fn add( self : Coords3, other : Coords3 ) Coords3 { return Coords3{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z }; }
  pub inline fn sub( self : Coords3, other : Coords3 ) Coords3 { return Coords3{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z }; }

  pub inline fn addVal( self : Coords3, val : i32 ) Coords3 { return Coords3{ .x = self.x + val, .y = self.y + val, .z = self.z - val }; }
  pub inline fn subVal( self : Coords3, val : i32 ) Coords3 { return Coords3{ .x = self.x - val, .y = self.y - val, .z = self.z - val }; }

  pub inline fn mulVal( self : Coords3, f : f32 ) Coords3
  {
    return Coords3{
      .x = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.x )) * f )),
      .y = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.y )) * f )),
      .z = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.z )) * f )),
    };
  }

  pub inline fn divVal( self : Coords3, f : f32 ) ?Coords3
  {
    if( f == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Coords3.div()" );
      return null;
    }
    return Coords3{
      .x = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.x )) / f )),
      .y = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.y )) / f )),
      .z = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.z )) / f )),
    };
  }
};

