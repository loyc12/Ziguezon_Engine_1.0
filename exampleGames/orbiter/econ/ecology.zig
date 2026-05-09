const std = @import( "std"  );
const def = @import( "defs" );


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const ecn = gdf.ecn;

const PowerSrc = gdf.PowerSrc;
const VesType  = gdf.VesType;
const ResType  = gdf.ResType;
const PopType  = gdf.PopType;
const InfType  = gdf.InfType;
const IndType  = gdf.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const popTypeC  = PopType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;



// Tune these to control how harshly each factor penalises the eco factor
// NOTE : 0.0 means no influence, 1.0 means maximal influence
const DEV_WEIGHT  : f64 = 0.2;
const POLL_WEIGHT : f64 = 0.9;

// Tune these to control how steeply the pollution factor rises
const NATURAL_CAPACITY   : f64 = 0.2; // Quantity of polution each unit area can absorbe for free // NOTE : increase if pollution is too harsh
const POLLUTION_MIDPOINT : f64 = 2.0; // rawRatio at which pollution factor == 0.5

// How far towards ecoTarget does ecoFactor move each update
const ECO_DAMPENING : f64 = 0.01;


pub const EcoState = struct
{
  surfaceArea : f64,

  development : f64 = 0.0,
  pollution   : f64 = 0.0,

  ecoTarget   : f64 = 1.0,
  ecoFactor   : f64 = 1.0,


  pub fn init( econ : *const ecn.Economy ) ?EcoState
  {
    if( !econ.hasEcology() )
    {
      def.qlog( .WARN, 0, @src(), "Cannot generate ecology : invalid economy" );
      return null;
    }

    return .{ .surfaceArea = econ.areaData.get( .CAP )};
  }

  pub inline fn logEco( self : *const EcoState ) void
  {
    def.qlog( .INFO, 0, @src(), "Loggin ecology :" );
    def.log(  .CONT, 0, @src(), "Development    : {d:.6}", .{ self.development });
    def.log(  .CONT, 0, @src(), "Pollution      : {d:.6}", .{ self.pollution   });
    def.log(  .CONT, 0, @src(), "Eco Factor     : {d:.6}", .{ self.ecoFactor   });
    def.log(  .CONT, 0, @src(), "Eco Target     : {d:.6}", .{ self.ecoTarget   });
  }

  /// Sets ecoFactor to the calculated ecoTarget
  /// Call this once all dependent metrics are set ( Ind, Inf, Pop, etc )
  pub inline fn seed( self : *EcoState, econ : *const ecn.Economy ) void
  {
    self.update( econ );
    self.ecoFactor = self.ecoTarget;
  }

  pub fn update( self : *EcoState, econ : *const ecn.Economy ) void
  {
    self.calcDevelopment( econ );
    self.calcPollution(   econ );

  // Each factor independently penalises thefinal factor multiplicatively

    const devPenalty  = 1.0 - ( self.development * DEV_WEIGHT  );
    const pollPenalty = 1.0 - ( self.pollution   * POLL_WEIGHT );

    const ecoFloor = ( 1.0 - DEV_WEIGHT ) * ( 1.0 - POLL_WEIGHT );
    const ecoRange =   1.0 - ecoFloor;

    self.ecoTarget = (( devPenalty * pollPenalty ) - ecoFloor ) / ecoRange;
    self.ecoTarget = def.clmp( self.ecoTarget, def.EPS, 1.0 - def.EPS );

    self.ecoFactor = def.lerp( self.ecoFactor, self.ecoTarget, ECO_DAMPENING );
  }

  inline fn calcDevelopment( self : *EcoState, econ : *const ecn.Economy ) void
  {
    // [ 0.0, 1.0 ]
    self.development = @min( 1.0, econ.areaData.get( .USED ) / self.surfaceArea );
  }

  inline fn calcPollution( self : *EcoState, econ : *const ecn.Economy ) void
  {
    var pollutionAmount : f64 = 0.0;

    // Pop pollution
    for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );

      var tmp  = popT.getMetric_f64( .POLLUTION );
          tmp *= econ.popState.get( .COUNT, popT );

      pollutionAmount += tmp;
    }

    // Inf pollution                       // TODO : add pollution reducing inf
    for( 0..infTypeC )| f |
    {
      const infT = InfType.fromIdx( f );
      const use  = econ.infState.get( .USE_LVL, infT );

      var tmp  = infT.getMetric_f64( .POLLUTION );
          tmp *= econ.infState.get( .COUNT, infT );
          tmp *= use;

      pollutionAmount += tmp;
    }

    // Ind pollution
    for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );
      const act  = econ.indState.get( .ACT_LVL, indT );

      var tmp  = indT.getMetric_f64( .POLLUTION );
          tmp *= econ.indState.get( .COUNT, indT );
          tmp *= act;

      pollutionAmount += tmp;
    }

    // rawRatio is always >= 0 after the @max clamp
    const rawRatio = @max( 0.0, ( pollutionAmount / self.surfaceArea ) - NATURAL_CAPACITY );

    // Saturating curve
    self.pollution = rawRatio / ( rawRatio + POLLUTION_MIDPOINT );
  }
};