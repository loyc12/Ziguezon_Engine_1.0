const std = @import( "std" );
const def = @import( "defs" );


const gdf = @import( "../gameDefs.zig"    );
const ecn = gdf.ecn;

const VesType = gdf.VesType;
const ResType = gdf.ResType;
const InfType = gdf.InfType;
const IndType = gdf.IndType;


pub const ConstructTag = enum( u4 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

//ves,
  inf,
  ind,
};

pub const Construct = union( ConstructTag ) // Union of buildable things
{
//ves : VesType,
  inf : InfType,
  ind : IndType,


  pub fn getMass( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getMetric_f64( .MASS ),
      .inf => | infType | infType.getMetric_f64( .MASS ),
      .ind => | indType | indType.getMetric_f64( .MASS ),
    };
  }

  pub fn getAreaCost( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves =>             0.0,
      .inf => | infType | infType.getMetric_f64( .AREA_COST ),
      .ind => | indType | indType.getMetric_f64( .AREA_COST ),
    };
  }

  pub fn getPartCost( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getMetric_f64( .PART_COST ),
      .inf => | infType | infType.getMetric_f64( .PART_COST ),
      .ind => | indType | indType.getMetric_f64( .PART_COST ),
    };
  }

  pub fn getCapacity( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves => | vesType | vesType.getMetric_f64( .CAPACITY ),
      .inf => | infType | infType.getMetric_f64( .CAPACITY ),
      .ind =>             0,
    };
  }

  pub fn canBeBuiltIn( c : Construct, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    return switch( c )
    {
    //.ves =>             true,
      .inf => | infType | infType.canBeBuiltIn( loc, hasAtmo ),
      .ind => | indType | indType.canBeBuiltIn( loc, hasAtmo ),
    };
  }
};
