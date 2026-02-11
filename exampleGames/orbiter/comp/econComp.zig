const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const res = @import( "resource.zig" );


pub const econLocCount = @typeInfo( EconLoc ).@"enum".fields.len;

pub const EconLoc = enum( u8 )
{
  GROUND,
  ORBIT,
  L1, // Lagrange Points
  L2,
  L3,
  L4,
  L5,
};


pub const BuildOrder = struct
{
  infType  : inf.InfType,
  infCount : u32 = 0,
};


pub const EconComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location : EconLoc,

  population : u32 = 0,

  unusedArea : u32 = 0,
  urbanArea  : u32 = 0,
  arableArea : u32 = 0,

  resArray : [ res.resTypeCount ]u32 = std.mem.zeroes([ res.resTypeCount ]u32 ),
  infArray : [ inf.infTypeCount ]u32 = std.mem.zeroes([ inf.infTypeCount ]u32 ),


  // ================================ RESSOURCES ================================

  pub inline fn getResCount( self : *const EconComp, resType : .resType ) u32
  {
    return self.resArray[ @intFromEnum( resType )];
  }

  pub inline fn setResCount( self : *EconComp, resType : .resType, value : u32 ) void
  {
    self.resArray[ @intFromEnum( resType )] = value;
  }

  pub inline fn addResCount( self : *EconComp, resType : .resType, value : u32 ) void
  {
    self.resrArray[ @intFromEnum( resType )] += value;
  }

  pub inline fn subResCount( self : *EconComp, resType : .resType, value : u32 ) void
  {
    const count = @min( value, self.resArray[ @intFromEnum( resType )]);
    self.resArray[ @intFromEnum( resType )] -= @min( value, count );

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from econComp, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn getInfCount( self : *const EconComp, infType : .infType ) u32
  {
    return self.infArray[ @intFromEnum( infType )];
  }

  pub inline fn setInfCount( self : *EconComp, infType : .infType, value : u32 ) void
  {
    self.infArray[ @intFromEnum( infType )] = value;
  }

  pub inline fn addInfCount( self : *EconComp, infType : .infType, value : u32 ) void
  {
    self.infrArray[ @intFromEnum( infType )] += value;
  }

  pub inline fn subInfCount( self : *EconComp, infType : .infType, value : u32 ) void
  {
    const count = @min( value, self.infArray[ @intFromEnum( infType )]);
    self.infArray[ @intFromEnum( infType )] -= @min( value, count );

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} inf of type {s} from econComp, but only had {d} left", .{ value, @tagName( infType ), count });
    }
  }


  // ================================ PRODUCTION CYCLE ================================
};