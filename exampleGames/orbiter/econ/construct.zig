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

//vesT,
  infT,
  indT,
};

pub const Construct = union( ConstructTag ) // Union of buildable things
{
//vesT : VesType,
  infT : InfType,
  indT : IndType,


  pub fn canBeBuiltIn( c : Construct, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    return switch( c )
    {
    //.vesT => | v | v.canBeBuiltIn( loc, hasAtmo ),
      .infT => | f | f.canBeBuiltIn( loc, hasAtmo ),
      .indT => | d | d.canBeBuiltIn( loc, hasAtmo ),
    };
  }

  pub fn getMass( c : Construct ) f64
  {
    return switch( c )
    {
    //.vesT => | v | v.getMetric_f64( .MASS ),
      .infT => | f | f.getMetric_f64( .MASS ),
      .indT => | d | d.getMetric_f64( .MASS ),
    };
  }

  pub fn getAreaCost( c : Construct ) f64
  {
    return switch( c )
    {
    //.vesT =>  0.0,
      .infT => | f | f.getMetric_f64( .AREA_COST ),
      .indT => | d | d.getMetric_f64( .AREA_COST ),
    };
  }

  pub fn getAssemblyCost( c : Construct ) f64
  {
    return switch( c )
    {
    //.vesT => | v | v.getMetric_f64( .BLD_COST ),
      .infT => | f | f.getMetric_f64( .CSTR_COST ),
      .indT => | d | d.getMetric_f64( .CSTR_COST ),
    };
  }

  pub fn getCapacity( c : Construct ) f64
  {
    return switch( c )
    {
    //.vesT => | v | v.getMetric_f64( .CAPACITY ),
      .infT => | f | f.getMetric_f64( .CAPACITY ),
      .indT =>  0.0,
    };
  }

  pub fn getResBldCost( c : Construct, resT : ResType ) f64
  {
    return switch( c )
    {
    //.vesT => | v | v.getResMetric_f64( .BUILD, resT ),
      .infT => | f | f.getResMetric_f64( .BUILD, resT ),
      .indT => | d | d.getResMetric_f64( .BUILD, resT ),
    };
  }
  pub fn getResMntCost( c : Construct, resT : ResType ) f64
  {
    return switch( c )
    {
    //.vesT => | v | v.getResMetric_f64( .MAINT, resT ), // Paid after arrival based on travel duration
      .infT => | f | f.getResMetric_f64( .MAINT, resT ), // Paid continually based on usage
      .indT => | d | d.getResMetric_f64( .MAINT, resT ), // Paid continually based on activity
    };
  }
};
