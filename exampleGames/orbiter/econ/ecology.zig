const std = @import( "std" );
const def = @import( "defs" );


const gbl = @import( "../gameGlobals.zig" );
const ecn = gbl.ecn;

const PowerSrc = gbl.PowerSrc;
const VesType  = gbl.VesType;
const ResType  = gbl.ResType;
const InfType  = gbl.InfType;
const IndType  = gbl.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;


// Tune this to control how steeply pollution rises
const POLLUTION_PER_POP : f64 = 1.0;
const NATURAL_CAPACITY  : f64 = 0.0; // NOTE : Activate if polution is too harsh
const POLLUTION_SCALE   : f64 = 1.0; // shifts the midpoint ( higher = saturates sooner )

// Tune these to control how harshly each factor penalises the eco factor
const DEV_WEIGHT  : f64 = 0.6; // ecumenopolis alone can reduce ecoFactor to 0.4
const POLL_WEIGHT : f64 = 0.9; // full pollution alone can reduce ecoFactor to 0.1


pub const EcoState = struct
{
  pollutionPerPop : f64 = POLLUTION_PER_POP,

  surfaceArea : f64,
  population  : f64 = 0.0,
  development : f64 = 0.0,
  pollution   : f64 = 0.0,
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

    return eco;
  }

  pub inline fn logEco( self : *EcoState ) void
  {
    def.qlog( .INFO, 0, @src(), "Loggin ecology :" );
    def.log(  .CONT, 0, @src(), "Development\t: {d:.8}", .{ self.development });
    def.log(  .CONT, 0, @src(), "Pollution  \t: {d:.8}", .{ self.pollution   });
    def.log(  .CONT, 0, @src(), "Eco Factor \t: {d:.8}", .{ self.ecoFactor   });
  }

  pub fn update( self : *EcoState, econ : *const ecn.Economy ) void
  {
    self.calcDevelopment( econ );
    self.calcPollution(   econ );

  // Each factor independently penalises the eco factor multiplicatively.
  // Neither alone reaches 0 — both together approach it.

  // 0.0 / 0.0  →  ecoFactor == 1.0  ( wilderness,   clean )
  // 1.0 / 0.0  →  ecoFactor == 0.4  ( ecumenopolis, clean )
  // 0.0 / 1.0  →  ecoFactor == 0.1  ( wilderness,   toxic )
  // 1.0 / 1.0  →  ecoFactor == 0.04 ( ecumenopolis, toxic )

    const devPenalty  = 1.0 - ( self.development * DEV_WEIGHT  );
    const pollPenalty = 1.0 - ( self.pollution   * POLL_WEIGHT );

    self.ecoFactor = devPenalty * pollPenalty;

    self.ecoFactor = def.clmp( self.ecoFactor, def.EPS, 1.0 - def.EPS );

    self.logEco();

  }

  inline fn calcDevelopment( self : *EcoState, econ : *const ecn.Economy ) void
  {
    // [ 0.0, 1.0 ]
    self.development = @min( 1.0, econ.areaMetrics.get( .USED ) / self.surfaceArea );
  }

  inline fn calcPollution( self : *EcoState, econ : *const ecn.Economy ) void
  {
    self.population = econ.popMetrics.get( .COUNT );

    var pollutionAmount : f64 = 0.0;
    var averageActivity : f64 = 0.0;

    // Pop pollution
    pollutionAmount += self.population * self.pollutionPerPop;

    // Ind pollution
    for( 0..indTypeC )| d |
    {
      const activity = econ.indState.get( .ACT_LVL, IndType.fromIdx( d ));
      const indType  = IndType.fromIdx( d );

      var tmp  = indType.getMetric_f64( .POLLUTION );
          tmp *= econ.indState.get( .BANK, indType );
          tmp *= activity;

      pollutionAmount += tmp;
      averageActivity += activity;
    }

    averageActivity /= indTypeC;

    // Inf pollution                                  // TODO : add pollution reducting inf
    for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      var tmp  = infType.getMetric_f64( .POLLUTION );
          tmp *= econ.infState.get( .BANK, infType );
          tmp *= averageActivity;                     // TODO : used infrastruct usage rate instead

      pollutionAmount += tmp;
    }

    // rawRatio is always >= 0 after the @max clamp
    const rawRatio = @max( 0.0, ( pollutionAmount / self.surfaceArea ) - NATURAL_CAPACITY );

    // Log-space mapping : keeps pollution meaningful across several orders of magnitude
    // log( 1 + x ) is used instead of log( x ) to avoid log(0) and keep output >= 0

    // rawRatio == 0.0  →  logRatio == 0.000  →  pollution == 0.00
    // rawRatio == 0.1  →  logRatio == 0.095  →  pollution ≈ 0.07
    // rawRatio == 1.0  →  logRatio == 0.693  →  pollution ≈ 0.47
    // rawRatio == 10.0 →  logRatio == 2.398  →  pollution ≈ 0.92
    // rawRatio == 100  →  logRatio == 4.615  →  pollution ≈ 0.99


    const logRatio = @log( 1.0 + rawRatio );

    // Sigmoid on log-space input, remapped from [ 0.5, 1.0 ] to [ 0.0, 1.0 ]
    self.pollution = 1.0 / ( 1.0 + @exp( -logRatio * POLLUTION_SCALE ));
    self.pollution = ( self.pollution - 0.5 ) * 2.0;
    self.pollution = @max( 0.0, self.pollution );
  }
};