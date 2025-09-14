const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const VecA = def.VecA;
const Vec3 = def.Vec3;

pub const e_dir_2 = enum( u8 )
{
  SE, EA, NE, SO,
  NO, SW, WE, NW,

  pub fn getDebugColour( self : e_dir_2 ) def.Colour
  {
    return switch( self )
    {
      .NW => def.Colour.red,
      .WE => def.Colour.purple,
      .SW => def.Colour.blue,
      .SO => def.Colour.sky_blue,
      .SE => def.Colour.green,
      .EA => def.Colour.yellow,
      .NE => def.Colour.white,
      .NO => def.Colour.pink,
    };
  }

  pub fn getOpposite( self : e_dir_2 ) e_dir_2
  {
    return switch( self )
    {
      .SE => .NW,   .NW => .SE,
      .EA => .WE,   .WE => .EA,
      .NE => .SW,   .SW => .NE,
      .SO => .NO,   .NO => .SO,
    };
  }

  pub fn getNextClockwise( self : e_dir_2 ) e_dir_2
  {
    return switch( self )
    {
      .SE => .EA,
      .EA => .NE,
      .NE => .NO,
      .NO => .NW,
      .NW => .WE,
      .WE => .SW,
      .SW => .SO,
      .SO => .SE,
    };
  }

  pub fn getNextCounterClockwise( self : e_dir_2 ) e_dir_2
  {
    return switch( self )
    {
      .SE => .SO,
      .SO => .SW,
      .SW => .WE,
      .WE => .NW,
      .NW => .NO,
      .NO => .NE,
      .NE => .EA,
      .EA => .SE,
    };
  }
};


pub const Coords2 = struct
{
  x : i32 = 0,
  y : i32 = 0,

  // ================ GENERATION ================

  pub inline fn new( x : i32, y : i32 ) Coords2 { return Coords2{ .x = x, .y = y }; }

  pub inline fn toVec2( self : Coords2 )          Vec2 { return Vec2{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y )}; }
  pub inline fn toVecA( self : Coords2, r : f32 ) VecA { return VecA{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y ), .z = r }; }
  pub inline fn toVec3( self : Coords2, z : f32 ) Vec3 { return Vec3{ .x = @floatFromInt( self.x ), .y = @floatFromInt( self.y ), .z = z }; }

  // ================ COMPARISONS ================

  pub inline fn isPosi(  self : Coords2 ) bool { return self.x >= 0 and self.y >= 0; }
  pub inline fn isZero(  self : Coords2 ) bool { return self.x == 0 and self.y == 0; }
  pub inline fn isIso(   self : Coords2 ) bool { return self.x == self.y; }

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

  // ================= CONVERSION ================
  pub fn getNeighbour( self : Coords2, direction : e_dir_2 ) Coords2
  {
    return switch( direction )
    {
      .SE => Coords2{ .x = self.x + 1, .y = self.y + 1 },
      .EA => Coords2{ .x = self.x + 1, .y = self.y     },
      .NE => Coords2{ .x = self.x + 1, .y = self.y - 1 },
      .SO => Coords2{ .x = self.x,     .y = self.y + 1 },

      .NO => Coords2{ .x = self.x,     .y = self.y - 1 },
      .SW => Coords2{ .x = self.x - 1, .y = self.y + 1 },
      .WE => Coords2{ .x = self.x - 1, .y = self.y     },
      .NW => Coords2{ .x = self.x - 1, .y = self.y - 1 },
    };
  }
};