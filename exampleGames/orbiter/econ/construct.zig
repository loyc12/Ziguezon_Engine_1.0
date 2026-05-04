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


  pub fn canBeBuiltIn( c : Construct, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    return switch( c )
    {
    //.ves => | v | v.canBeBuiltIn( loc, hasAtmo ),
      .inf => | f | f.canBeBuiltIn( loc, hasAtmo ),
      .ind => | d | d.canBeBuiltIn( loc, hasAtmo ),
    };
  }

  pub fn getMass( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves => | v | v.getMetric_f64( .MASS ),
      .inf => | f | f.getMetric_f64( .MASS ),
      .ind => | d | d.getMetric_f64( .MASS ),
    };
  }

  pub fn getAreaCost( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves =>  0.0,
      .inf => | f | f.getMetric_f64( .AREA_COST ),
      .ind => | d | d.getMetric_f64( .AREA_COST ),
    };
  }

  pub fn getAssemblyCost( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves => | v | v.getMetric_f64( .BLD_COST ),
      .inf => | f | f.getMetric_f64( .CSTR_COST ),
      .ind => | d | d.getMetric_f64( .CSTR_COST ),
    };
  }

  pub fn getCapacity( c : Construct ) f64
  {
    return switch( c )
    {
    //.ves => | v | v.getMetric_f64( .CAPACITY ),
      .inf => | f | f.getMetric_f64( .CAPACITY ),
      .ind =>  0.0,
    };
  }

  pub fn getResBldCost( c : Construct, res : ResType ) f64
  {
    return switch( c )
    {
    //.ves => | v | v.getResMetric_f64( .BUILD, res ),
      .inf => | f | f.getResMetric_f64( .BUILD, res ),
      .ind => | d | d.getResMetric_f64( .BUILD, res ),
    };
  }
  pub fn getResMntCost( c : Construct, res : ResType ) f64
  {
    return switch( c )
    {
    //.ves => | v | v.getResMetric_f64( .MAINT, res ), // Paid after arrival based on travel duration
      .inf => | f | f.getResMetric_f64( .MAINT, res ), // Paid continually based on usage
      .ind => | d | d.getResMetric_f64( .MAINT, res ), // Paid continually based on activity
    };
  }
};
