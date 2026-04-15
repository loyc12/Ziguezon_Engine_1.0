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


// Tune this to control how steeply pollution rises
const NATURAL_CAPACITY   : f64 = 0.2; // Quantity of polution each unit area can absorbe for free // NOTE : increase if pollution is too harsh
const POLLUTION_MIDPOINT : f64 = 2.0; // rawRatio at which pollution == 0.5

// Tune these to control how harshly each factor penalises the eco factor
const DEV_WEIGHT  : f64 = 0.2; // full development alone can reduce ecoFactor to 1.0 - val
const POLL_WEIGHT : f64 = 0.9; // full pollution   alone can reduce ecoFactor to 1.0 - val

const ECO_DAMPENING : f64 = 0.02;


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

    var eco : EcoState = .{ .surfaceArea = econ.areaMetrics.get( .CAP )};

    eco.update( econ );

    eco.ecoFactor = eco.ecoTarget;

    return eco;
  }

  pub inline fn logEco( self : *const EcoState ) void
  {
    def.qlog( .INFO, 0, @src(), "Loggin ecology :" );
    def.log(  .CONT, 0, @src(), "Development    : {d:.6}", .{ self.development });
    def.log(  .CONT, 0, @src(), "Pollution      : {d:.6}", .{ self.pollution   });
    def.log(  .CONT, 0, @src(), "Eco Factor     : {d:.6}", .{ self.ecoFactor   });
    def.log(  .CONT, 0, @src(), "Eco Target     : {d:.6}", .{ self.ecoTarget   });
  }

  pub fn update( self : *EcoState, econ : *const ecn.Economy ) void
  {
    self.calcDevelopment( econ );
    self.calcPollution(   econ );

  // Each factor independently penalises the eco factor multiplicatively.
  // Neither alone reaches 0 - both together approach it.

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
    self.development = @min( 1.0, econ.areaMetrics.get( .USED ) / self.surfaceArea );
  }

  inline fn calcPollution( self : *EcoState, econ : *const ecn.Economy ) void
  {
    var pollutionAmount : f64 = 0.0;

    // Pop pollution
    for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      var tmp  = popType.getMetric_f64( .POLLUTION );
          tmp *= econ.popState.get( .COUNT, popType );

      pollutionAmount += tmp;
    }

    // Inf pollution                       // TODO : add pollution reducing inf
    for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );
      const useRate = econ.infState.get( .USE_LVL, infType );

      var tmp  = infType.getMetric_f64( .POLLUTION );
          tmp *= econ.infState.get( .COUNT, infType );
          tmp *= useRate;

      pollutionAmount += tmp;
    }

    // Ind pollution
    for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const activity = econ.indState.get( .ACT_LVL, indType );

      var tmp  = indType.getMetric_f64( .POLLUTION );
          tmp *= econ.indState.get( .COUNT, indType );
          tmp *= activity;

      pollutionAmount += tmp;
    }

    // rawRatio is always >= 0 after the @max clamp
    const rawRatio = @max( 0.0, ( pollutionAmount / self.surfaceArea ) - NATURAL_CAPACITY );

    // Saturating curve
    self.pollution = rawRatio / ( rawRatio + POLLUTION_MIDPOINT );
  }
};