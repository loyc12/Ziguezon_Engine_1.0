const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const VecA = def.VecA;
const Vec3 = def.Vec3;


pub const e_dir_3 = enum( u8 )
{
  TSE, TEA, TNE, TSO,
  TNO, TSW, TWE, TNW,

  MSE, MEA, MNE, MSO,
  MNO, MSW, MWE, MNW,

  BSE, BEA, BNE, BSO,
  BNO, BSW, BWE, BNW,

  TOP, BOT,

  pub fn getOpposite( self : e_dir_3 ) e_dir_3
  {
    return switch( self )
    {
      .TSO => .BNO,   .BNO => .TSO,
      .TNO => .BSO,   .BSO => .TNO,
      .TWE => .BEA,   .BEA => .TWE,
      .TEA => .BWE,   .BWE => .TEA,

      .TSE => .BNW,   .BNW => .TSE,
      .TNE => .BSW,   .BSW => .TNE,
      .TSW => .BNE,   .BNE => .TSW,
      .TNW => .BSE,   .BSE => .TNW,

      .MSE => .MNW,   .MNW => .MSE,
      .MEA => .MWE,   .MWE => .MEA,
      .MNE => .MSW,   .MSW => .MNE,
      .MSO => .MNO,   .MNO => .MSO,

      .TOP => .BOT,   .BOT => .TOP,
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

  pub inline fn isPosi(  self : Coords3 ) bool { return self.x >= 0 and self.y >= 0 and self.z >= 0; }
  pub inline fn isZero(  self : Coords3 ) bool { return self.x == 0 and self.y == 0 and self.z == 0; }
  pub inline fn isIso(   self : Coords3 ) bool { return self.x == self.y and self.y == self.z; }

  pub inline fn isEq(     self : Coords3, other : Coords3 ) bool { return self.x == other.x and self.y == other.y and self.z == other.z; }
  pub inline fn isDiff(   self : Coords3, other : Coords3 ) bool { return self.x != other.x or  self.y != other.y or  self.z != other.z; }
  pub inline fn isInfXYZ( self : Coords3, other : Coords3 ) bool { return self.x <  other.x or  self.y <  other.y or  self.z < other.z; }
  pub inline fn isSupXYZ( self : Coords3, other : Coords3 ) bool { return self.x >  other.x or  self.y >  other.y or  self.z > other.z; }

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

  // ================= CONVERSION ================

  pub fn getNeighbour( self : Coords3, direction : e_dir_3 ) Coords3
  {
    return switch( direction )
    {
      .TSE => Coords3{ .x = self.x + 1, .y = self.y + 1, .z = self.z + 1 },
      .TEA => Coords3{ .x = self.x + 1, .y = self.y,     .z = self.z + 1 },
      .TNE => Coords3{ .x = self.x + 1, .y = self.y - 1, .z = self.z + 1 },
      .TSO => Coords3{ .x = self.x,     .y = self.y + 1, .z = self.z + 1 },

      .TNO => Coords3{ .x = self.x,     .y = self.y - 1, .z = self.z + 1 },
      .TSW => Coords3{ .x = self.x - 1, .y = self.y + 1, .z = self.z + 1 },
      .TWE => Coords3{ .x = self.x - 1, .y = self.y,     .z = self.z + 1 },
      .TNW => Coords3{ .x = self.x - 1, .y = self.y - 1, .z = self.z + 1 },


      .MSE => Coords3{ .x = self.x + 1, .y = self.y + 1, .z = self.z     },
      .MEA => Coords3{ .x = self.x + 1, .y = self.y,     .z = self.z     },
      .MNE => Coords3{ .x = self.x + 1, .y = self.y - 1, .z = self.z     },
      .MSO => Coords3{ .x = self.x,     .y = self.y + 1, .z = self.z     },

      .MNO => Coords3{ .x = self.x,     .y = self.y - 1, .z = self.z     },
      .MSW => Coords3{ .x = self.x - 1, .y = self.y + 1, .z = self.z     },
      .MWE => Coords3{ .x = self.x - 1, .y = self.y,     .z = self.z     },
      .MNW => Coords3{ .x = self.x - 1, .y = self.y - 1, .z = self.z     },


      .BSE => Coords3{ .x = self.x + 1, .y = self.y + 1, .z = self.z - 1 },
      .BEA => Coords3{ .x = self.x + 1, .y = self.y,     .z = self.z - 1 },
      .BNE => Coords3{ .x = self.x + 1, .y = self.y - 1, .z = self.z - 1 },
      .BSO => Coords3{ .x = self.x,     .y = self.y + 1, .z = self.z - 1 },

      .BNO => Coords3{ .x = self.x,     .y = self.y - 1, .z = self.z - 1 },
      .BSW => Coords3{ .x = self.x - 1, .y = self.y + 1, .z = self.z - 1 },
      .BWE => Coords3{ .x = self.x - 1, .y = self.y,     .z = self.z - 1 },
      .BNW => Coords3{ .x = self.x - 1, .y = self.y - 1, .z = self.z - 1 },


      .TOP => Coords3{ .x = self.x,     .y = self.y,     .z = self.z + 1 },
      .BOT => Coords3{ .x = self.x,     .y = self.y,     .z = self.z - 1 },
    };
  }
};

