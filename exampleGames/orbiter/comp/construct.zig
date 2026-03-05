const std = @import( "std" );
const def = @import( "defs" );

const ves = @import( "vessel.zig" );
const res = @import( "resource.zig" );
const inf = @import( "infrastructure.zig" );
const ind = @import( "industry.zig" );

const ecn = @import( "economy.zig" );


const vesTypeCount = ves.vesTypeCount;
const resTypeCount = res.resTypeCount;
const infTypeCount = inf.infTypeCount;
const indTypeCount = ind.indTypeCount;

const VesType = ves.VesType;
const ResType = res.ResType;
const InfType = inf.InfType;
const IndType = ind.IndType;

const VesInstance = ves.VesInstance;
const ResInstance = res.ResInstance;
const InfInstance = inf.InfInstance;
const IndInstance = ind.IndInstance;


pub const ConstructTag = enum
{
//ves,
  inf,
  ind,
};

pub const Construct = union( ConstructTag ) // Union of buildable things
{
//ves : VesType,
  inf : InfType,
  ind : IndType,


  pub fn getMass( c : Construct ) f32
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getMass(),
      .inf => | infType | infType.getMass(),
      .ind => | indType | indType.getMass(),
    };
  }

  pub fn getAreaCost( c : Construct ) f32
  {
    return switch( c )
    {
    //.ves =>             0.0,
      .inf => | infType | infType.getAreaCost(),
      .ind => | indType | indType.getAreaCost(),
    };
  }

  pub fn getPartCost( c : Construct ) u64
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getPartCost(),
      .inf => | infType | infType.getPartCost(),
      .ind => | indType | indType.getPartCost(),
    };
  }

  pub fn getCapacity( c : Construct ) u64
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getCapacity(),
      .inf => | infType | infType.getCapacity(),
      .ind =>             0,
    };
  }

  pub fn canBeBuiltIn( c : Construct, loc : ecn.EconLoc, hasAtmo : bool ) bool
  {
    return switch( c )
    {
    //.ves =>             true,
      .inf => | infType | infType.canBeBuiltIn( loc, hasAtmo ),
      .ind => | indType | indType.canBeBuiltIn( loc, hasAtmo ),
    };
  }
};
