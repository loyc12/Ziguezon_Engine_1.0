const std  = @import( "std" );
const utl = @import( "utils" );

const Vec2 = utl.Vec2;
const VecA = utl.VecA;
const Vec3 = utl.Vec3;

pub const Dir2 = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  SE, EA, NE, SO,
  NO, SW, WE, NW,

  pub const arr = [_]utl.Dir2{ .NO, .NE, .EA, .SE, .SO, .SW, .WE, .NW };

  pub fn getDebugColour( self : Dir2 ) utl.Colour
  {
    return switch( self )
    {
      .NW => utl.Colour.red,
      .WE => utl.Colour.purple,
      .SW => utl.Colour.blue,
      .SO => utl.Colour.cerul,
      .SE => utl.Colour.green,
      .EA => utl.Colour.yellow,
      .NE => utl.Colour.white,
      .NO => utl.Colour.pRed,
    };
  }

  pub fn getOpposite( self : Dir2 ) Dir2
  {
    return switch( self )
    {
      .SE => .NW,   .NW => .SE,
      .EA => .WE,   .WE => .EA,
      .NE => .SW,   .SW => .NE,
      .SO => .NO,   .NO => .SO,
    };
  }

  pub fn getNextClockwise( self : Dir2 ) Dir2
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

  pub fn getNextCounterClockwise( self : Dir2 ) Dir2
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

  pub inline fn swap( self : Coords2 ) Coords2 { return .{ .x = self.y, .y = self.x }; }

  // ================ COMPARISONS ================

  pub inline fn isPosi(  self : Coords2 ) bool { return self.x >= 0 and self.y >= 0; }
  pub inline fn isZero(  self : Coords2 ) bool { return self.x == 0 and self.y == 0; }
  pub inline fn isIso(   self : Coords2 ) bool { return self.x == self.y; }

  pub inline fn isEq(    self : Coords2, other : Coords2 ) bool { return self.x == other.x and self.y == other.y; }
  pub inline fn isDiff(  self : Coords2, other : Coords2 ) bool { return self.x != other.x or  self.y != other.y; }


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
    if( utl.isFltZr( f ))
    {
      utl.qlog( .ERROR, 0, @src(), "Division by zero in Coords2.div()" );
      return null;
    }
    return Coords2{
      .x = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.x )) / f )),
      .y = @intFromFloat( @trunc( @as( f32, @floatFromInt( self.y )) / f )),
    };
  }


  // ================= CONVERSION ================

  pub fn getNeighbour( self : Coords2, direction : Dir2 ) Coords2
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


  //  ================= MISC ================

  pub fn getParityColour( self : Coords2 ) utl.Colour
  {
    const parity = @mod( self.x, 2 ) + ( 2 * @mod( self.y, 2 ));

    return switch( parity )
    {
      0    => .nWhite,
      1    => .pGray,
      2    => .lGray,
      3    => .mGray,
      else => .magenta, // Won't ever be seen in normal usecase
    };
  }
};