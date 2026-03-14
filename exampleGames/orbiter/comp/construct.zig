const std = @import( "std" );
const def = @import( "defs" );

const ecn = @import( "economy.zig" );

const gbl = @import( "../gameGlobals.zig" );

const vesTypeCount = gbl.vesTypeCount;
const resTypeCount = gbl.resTypeCount;
const infTypeCount = gbl.infTypeCount;
const indTypeCount = gbl.indTypeCount;

const VesType      = gbl.VesType;
const ResType      = gbl.ResType;
const InfType      = gbl.InfType;
const IndType      = gbl.IndType;


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
    //.ves => | vesType | vesType.getMetric( .MASS ),
      .inf => | infType | infType.getMetric( .MASS ),
      .ind => | indType | indType.getMetric( .MASS ),
    };
  }

  pub fn getAreaCost( c : Construct ) f32
  {
    return switch( c )
    {
    //.ves =>             0.0,
      .inf => | infType | infType.getMetric( .AREA_COST ),
      .ind => | indType | indType.getMetric( .AREA_COST ),
    };
  }

  pub fn getPartCost( c : Construct ) f32
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getMetric( .PART_COST ),
      .inf => | infType | infType.getMetric( .PART_COST ),
      .ind => | indType | indType.getMetric( .PART_COST ),
    };
  }

  pub fn getCapacity( c : Construct ) f32
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getMetric( .CAPACITY ),
      .inf => | infType | infType.getMetric( .CAPACITY ),
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
