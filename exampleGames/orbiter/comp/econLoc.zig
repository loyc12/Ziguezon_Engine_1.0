const std = @import( "std" );
const def = @import( "defs" );


pub const econLocCount = @typeInfo( EconLoc ).@"enum".fields.len;

pub const EconLoc = enum( u8 )
{
  pub inline fn toIdx( self : EconLoc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) EconLoc {  return @enumFromInt( @as( u8, @intCast( i ))); }

  GROUND, // Does not garantee breathable atmosphere
  ORBIT,
  L1,     // Lagrange Points
  L2,
  L3,
  L4,
  L5,

  pub inline fn toLagrange( self : EconLoc ) u4
  {
    return switch( self )
    {
      .L1  => 1,
      .L2  => 2,
      .L3  => 3,
      .L4  => 4,
      .L5  => 5,
      else => 0,
    };
  }
};