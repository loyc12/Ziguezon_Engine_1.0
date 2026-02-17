const std = @import( "std" );
const def = @import( "defs" );


pub const powerSrcCount = @typeInfo( PowerSrc ).@"enum".fields.len;


pub const PowerSrc = enum( u8 )
{
  pub inline fn toIdx( self : PowerSrc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) PowerSrc { return @enumFromInt( @as( u8, @intCast( i ))); }

  GRID,
  SOLAR,
//NUCLEAR,
//BEAM,
};