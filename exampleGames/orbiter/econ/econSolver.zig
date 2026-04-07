const std = @import( "std"  );
const def = @import( "defs" );


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const ecn = gdf.ecn;

const PowerSrc = gdf.PowerSrc;
const VesType  = gdf.VesType;
const ResType  = gdf.ResType;
const InfType  = gdf.InfType;
const IndType  = gdf.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;


const ecnm_d = gdf.ecnm_d;

const FlowAgent = ecnm_d.FlowAgentEnum;
const FlowPhase = ecnm_d.FlowPhaseEnum;
const Access    = ecnm_d.AccessAgentEnum;



pub inline fn resolveEcon( econ : *ecn.Economy ) void
{
  var solver : EconSolver = .{ .econ = econ };

  solver.initBaseState();   // Zeroes out dataMatrices and resets econ metrics
  solver.applyResDecay();   // Decays stored resources based on defined rates
  solver.applyResGrowth();  // Grows wild resources based on ecology factor

  solver.calcIndMaxDelta(); // Computes industrial potential prod and cons
  solver.calcPopMaxDelta(); // Computes population potential prod and cons
  solver.calcPriceDelta();
  solver.calcProfitability();

  solver.calcResAccess();   // Computes non-WORK resource access     TODO : add access-tweaking policies / modifiers
  solver.applyWorkWeek();   // Precomputes real WORK production to inform industrial WORK access
  solver.calcWorkAccess();  // Computes industrial WORK access

  solver.calcIndActivity(); // Computes the activity rate of each industry

  solver.calcIndResDelta(); // Computes real ressource delta from industry   based on activity
  solver.calcPopResDelta(); // Computes real ressource delta from population based on popCount

  solver.applyResDelta();   // Apply resources  delta based on previous calcs
  solver.applyPopDelta();   // Apply population delta based on access
}


const EconSolver = struct
{
  // Global consumption-production throttles / multipliers
  maxResAccess   : f64 = 1.0,
  maxIndActivity : f64 = 1.0,

  minWorkRate    : f64 = 0.2,
  maxWorkRate    : f64 = 1.0,

  sunshineModifier : f32 = 1.0,
  natureModifier   : f32 = 1.0,

  // Solver data
  econ : *ecn.Economy,

  prevPopCount  : f64 = 0.0,
  nextPopCount  : f64 = 0.0,

  resStockData     : ecnm_d.ResStockData     = .{},
  genResAccessData : ecnm_d.GenResAccessData = .{},
  indActivity      : ecnm_d.IndActivityData  = .{},
  indFlowData      : ecnm_d.IndFlowData      = .{}, // Per industry
  resFlowData      : ecnm_d.ResFlowData      = .{}, // Agregated industry


  fn initBaseState( self : *EconSolver ) void
  {
    self.prevPopCount = self.econ.popMetrics.get( .COUNT );
    self.nextPopCount = self.prevPopCount;

    self.genResAccessData.fillWith( 0.0 );
    self.indActivity.fillWith(      0.0 );
    self.indFlowData.fillWith(      0.0 );
    self.resFlowData.fillWith(      0.0 );

    inline for( 0..ResType.count )| r |
    {
      const resType   = ResType.fromIdx( r );
      const econStock = self.econ.resState.get( .BANK, resType );

      self.resStockData.set( resType, econStock );
    }

    self.econ.resetCountMetrics();
  }

  fn applyResDecay( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "Logging natural resource decay :" );

    inline for( 0..resTypeC )| r |
    {
      const resType   = ResType.fromIdx( r );
      const decayRate = resType.getMetric_f64( .DECAY_RATE );
      const resCount  = self.resStockData.get( resType );

      if( decayRate > def.EPS and resCount > def.EPS  )
      {
        const decayLoss = resCount * decayRate;

        self.resStockData.sub( resType, decayLoss );

        // Store in flow data as natural consumption ( not included in .GEN )
        self.resFlowData.set( .NAT, .REAL_CONS, resType, decayLoss );

        // Update economy state
        self.econ.resState.set( .DECAY, resType, decayLoss );

      //def.log( .CONT, 0, @src(), "{s}  \t: -{d}", .{ @tagName( ResType.fromIdx( r )), decay_u64 });
      }
    }
  }

  fn applyResGrowth( self : *EconSolver ) void
  {
    const ecoFactor = self.econ.getEcoFactor();

  //def.qlog( .DEBUG, 0, @src(), "Logging natural resource growth :" );

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const growRate   = resType.getMetric_f64( .GROWTH_RATE );
      const growthGain = @max( 0.0, ecoFactor * ecoFactor * ecoFactor * growRate );

      if( growthGain >= def.EPS )
      {
        self.resStockData.add( resType, growthGain );

        // Store in flow data as natural production ( not included in .GEN )
        self.resFlowData.set( .NAT, .REAL_PROD, resType, growthGain );

        // Update economy state
        self.econ.resState.set( .GROWTH, resType, growthGain );

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}", .{ @tagName( ResType.fromIdx( r )), grow_u64 });
      }

    }
  }



  fn calcIndMaxDelta( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .BANK, indType );

    //def.log( .INFO, 0, @src(), "$ LOGGING DELTAS FOR {s} :", .{ @tagName( indType )}); // NOTE : DEBUG

      if( indCount > def.EPS ){ inline for ( 0..resTypeC )| r | // Skip absent industries
      {
        const resType = ResType.fromIdx( r );

        var maxProd = indCount * indType.getResProd_f64( resType );
        var maxCons = indCount * indType.getResCons_f64( resType );

        // Adjust expected max prob based on sunlight
        if( indType.getPowerSrc() == .SOLAR )
        {
          maxProd *= @floatCast( self.econ.sunAccess );
          maxCons *= @floatCast( self.econ.sunAccess );
        }
      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons }); // NOTE : DEBUG

        // Per-industry flow
        self.indFlowData.set( indType, .MAX_PROD, resType, maxProd );
        self.indFlowData.set( indType, .MAX_CONS, resType, maxCons );

        // Aggregate into IND flowAgent
        self.resFlowData.add( .IND, .MAX_PROD, resType, maxProd );
        self.resFlowData.add( .IND, .MAX_CONS, resType, maxCons );

        self.resFlowData.add( .GEN, .MAX_PROD, resType, maxProd );
        self.resFlowData.add( .GEN, .MAX_CONS, resType, maxCons );
      }}
    }

  }

  fn calcPopMaxDelta( self : *EconSolver ) void
  {
  //def.qlog( .INFO, 0, @src(), "$ LOGGING DELTAS FOR POP :" ); // NOTE : DEBUG

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const maxProd = self.prevPopCount * resType.getMetric_f64( .POP_PROD );
      const maxCons = self.prevPopCount * resType.getMetric_f64( .POP_CONS );

    //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons }); // NOTE : DEBUG

      if( maxProd > def.EPS ) // If res produced ( WORK )
      {
        self.resFlowData.set( .POP, .MAX_PROD, resType, maxProd );
        self.resFlowData.add( .GEN, .MAX_PROD, resType, maxProd );
      }
      if( maxCons > def.EPS ) // If res consumed ( FOOD, WATER, POWER )
      {
        self.resFlowData.set( .POP, .MAX_CONS, resType, maxCons );
        self.resFlowData.add( .GEN, .MAX_CONS, resType, maxCons );
      }
    }
  }

  fn calcPriceDelta( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging resource prices :" );

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const basePrice  = resType.getMetric_f64( .PRICE_BASE );
      const elasticity = resType.getMetric_f64( .PRICE_ELAS );
      const dampening  = resType.getMetric_f64( .PRICE_DAMP ); // Lerp factor (0 = no change, 1 = instant)

      if( basePrice > def.EPS )
      {
        const maxSupply = self.resFlowData.get( .GEN, .MAX_PROD, resType ) + self.resStockData.get( resType );
        const maxDemand = self.resFlowData.get( .GEN, .MAX_CONS, resType );

        const ceil : f64 = 1000.0; // Scarcity ceiling
        var  ratio : f64 =    0.0;

        if(      maxSupply > def.EPS ){ ratio = @min( ceil, maxDemand / maxSupply ); }
        else if( maxDemand > def.EPS ){ ratio = ceil; }

        const oldPrice = self.econ.resState.get( .PRICE, resType );
        var   rawPrice = basePrice;

        // TODO : calc PART demand in advance for this
        if( maxDemand > def.EPS ){ rawPrice *= def.pow( f64, ratio, elasticity ); }
        else                     { rawPrice *= 0.05; } // Prevents unused res costing absolutely nothing.

        const newPrice = def.lerp(  oldPrice, rawPrice, dampening ); // Lerp smoothing
        const delta    = newPrice - oldPrice;

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}\t| {d:.6}\t {d:.6}\t| {d:.6}", .{ @tagName( resType ), basePrice, oldPrice, newPrice, delta });

        self.econ.resState.set( .PRICE,   resType, newPrice );
        self.econ.resState.set( .PRICE_D, resType, delta    );
      }
    }
  }

  fn calcProfitability( self : *EconSolver ) void
  {
    def.qlog( .DEBUG, 0, @src(), "Logging individual industrial profitability :" );

    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .BANK, indType );

      if( indCount > def.EPS )
      {
        var revenue : f64 = 0.0;
        var expense : f64 = 0.0;

        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );
          const price   = self.econ.resState.get( .PRICE, resType );

          const prodPerUnit = indType.getResProd_f64( resType );
          const consPerUnit = indType.getResCons_f64( resType );

          revenue += prodPerUnit * price;
          expense += consPerUnit * price;
        }

        const profit = revenue - expense;

        const floor : f64 = -10.0; // profitlesness floor
        var  margin : f64 =   0.0;

        if(      revenue > def.EPS ){ margin = @max( floor, ( revenue - expense ) / revenue ); }
        else if( expense > def.EPS ){ margin =       floor; }

        // large profits will tend to 1.0, large losses will tend to 0.0
        const activityTarget = self.maxIndActivity * def.sigmoid( margin, 4.0 ); // NOTE : lower K for smoother transitioning

        def.log( .CONT, 0, @src(), "{s}\t: {d:.6}\t-{d:.6}\t| {d:.6}\t{d:.6}", .{ @tagName( indType ), revenue, expense, margin, activityTarget });

        self.econ.indState.set( .EXPENSE,  indType, expense * indCount );
        self.econ.indState.set( .REVENUE,  indType, revenue * indCount );
        self.econ.indState.set( .PROFIT,   indType, profit  * indCount );
        self.econ.indState.set( .ACT_TRGT, indType, activityTarget     );
      }
      else
      {
        self.econ.indState.set( .EXPENSE,  indType, 0.0 );
        self.econ.indState.set( .REVENUE,  indType, 0.0 );
        self.econ.indState.set( .PROFIT,   indType, 0.0 );
        self.econ.indState.set( .ACT_TRGT, indType, 1.0 );
      }
    }
  }



  // TODO : Tweak population vs industry access ratio here if need be
  // TODO : Split ind and pop access passes if need be
  fn calcResAccess( self : *EconSolver ) void
  {
    def.qlog( .DEBUG, 0, @src(), "Logging resource availabilities and requirements :" );

    inline for( 0..resTypeC )| r |{ if( ResType.fromIdx( r ) != .WORK ) // Skipping WORK ( see calcWorkAccess() )
    {
      const resType = ResType.fromIdx( r );

      // Calculating supply and demand
      const supply = self.resStockData.get( resType );
      const demand = self.resFlowData.get( .GEN, .MAX_CONS, resType );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), supply, demand });

      var access : f64 = self.maxResAccess;

      if( demand > def.EPS )
      {
        access = supply / demand;

        // If res is needed by EITHER pop or ind ( not both ), have mark the other as fully supplied
        const popMaxCons = self.resFlowData.get( .POP, .MAX_CONS, resType );
        const indMaxCons = self.resFlowData.get( .IND, .MAX_CONS, resType );

        if( popMaxCons > def.EPS ){ self.genResAccessData.set( .POP, resType, access            ); }
        else                      { self.genResAccessData.set( .POP, resType, self.maxResAccess ); }

        if( indMaxCons > def.EPS ){ self.genResAccessData.set( .IND, resType, access            ); }
        else                      { self.genResAccessData.set( .IND, resType, self.maxResAccess ); }

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage", .{ @tagName( resType )});
        }
      }
      else
      {
        self.genResAccessData.set( .POP, resType, self.maxResAccess );
        self.genResAccessData.set( .IND, resType, self.maxResAccess );
      }

      // Updating economy metrics
      self.genResAccessData.set( .GEN,     resType, access );
      self.econ.resState.set( .SAT_LVL, resType, access );

      self.econ.avgResAccess += access / ResType.count;
    }}
  }

  fn applyWorkWeek( self : *EconSolver ) void // TODO : If some industries produce work, produce it here too
  {
    var workRate : f64 = self.maxWorkRate;

    inline for( 0..resTypeC )| r |{ if( ResType.fromIdx( r ) != .WORK )
    {
      const resType = ResType.fromIdx( r );

      const popMaxCons = self.resFlowData.get( .POP, .MAX_CONS, resType );

      if( popMaxCons > def.EPS )
      {
        workRate = @min( workRate, self.genResAccessData.get( .POP, resType ));
      }
    }}

    // Clamping pop work rates to a minimum to prevent total supply chain collapse
    workRate = @max( workRate, self.minWorkRate );

    def.log( .CONT, 0, @src(), "# WORK rate\t: {d:.4}", .{ workRate });

    // Updating economy metrics
    const weeklyPopWork = workRate * self.resFlowData.get( .POP, .MAX_PROD, .WORK );

    self.resFlowData.set( .POP, .REAL_PROD, .WORK, weeklyPopWork );
    self.resFlowData.add( .GEN, .REAL_PROD, .WORK, weeklyPopWork );

    self.resStockData.add( .WORK, weeklyPopWork );

  }

  fn calcWorkAccess( self : *EconSolver ) void
  {
    // Like calcResAccess() + applyResDelta(), but only for work, since we need other res to calculate work prod

    // Calculating supply and demand
    const supply = self.resStockData.get( .WORK );
    const demand = self.resFlowData.get( .IND, .MAX_CONS, .WORK );

    def.log( .CONT, 0, @src(), "WORK  \t: {d:.0}\t-{d:.0}", .{ supply, demand });

    self.resFlowData.add( .GEN, .MAX_PROD, .WORK, supply );
    self.resFlowData.add( .GEN, .MAX_CONS, .WORK, demand );

    var access : f64 = self.maxResAccess;

    if( demand > def.EPS )
    {
      access = supply / demand;

      if( access < 1.0 - def.EPS )
      {
        def.qlog( .CONT, 0, @src(), "@ WORK shortage" );
      }
    }

    // Updating economy metrics
    self.genResAccessData.set( .POP, .WORK, self.maxResAccess ); // POP will never need work, so access is always maxed

    self.genResAccessData.set( .IND, .WORK, access );
    self.genResAccessData.set( .GEN, .WORK, access );

    self.econ.resState.set( .SAT_LVL, .WORK, access );

    self.econ.avgResAccess += access / ResType.count;
  }



  fn calcIndActivity( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "Logging industrial activity :" );

    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .BANK, indType );

      var activity : f64 = self.maxIndActivity;

      if( indCount < def.EPS ) // Skip absent industries
      {
        activity = 0.0;
      }
      else
      {
        // NOTE : Sunshine ratio effect moved to maxResProd phase, to avoid planning for impossible supplies

        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          const maxCons = self.indFlowData.get( indType, .MAX_CONS, resType );

          if( maxCons > def.EPS )
          {
            activity = @min( activity, self.genResAccessData.get( .IND, resType ));
          }
        }
      }

    //activity = @min( activity, self.econ.indState.get( .ACT_TRGT, indType )); // TODO : figure out why activating this crashes activity

      // Updating economy metrics
      self.indActivity.set(             indType, activity );
      self.econ.indState.set( .ACT_LVL, indType, activity );

      self.econ.avgIndActivity += activity / IndType.count;
    }
  }

  fn calcIndResDelta( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );
      const indActivity = self.indActivity.get( indType );

      if( indActivity > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          // Ind Production
          if( resType != .WORK ) // WORK production handled in applyWorkWeek()
          {
            const realIndProd = indActivity * self.indFlowData.get( indType, .MAX_PROD, resType );

            self.indFlowData.set( indType, .REAL_PROD, resType, realIndProd );
            self.resFlowData.add( .IND,    .REAL_PROD, resType, realIndProd );
            self.resFlowData.add( .GEN,    .REAL_PROD, resType, realIndProd );
          }

          // Ind Consumption
          const realIndCons = indActivity * self.indFlowData.get( indType, .MAX_CONS, resType );

          self.indFlowData.set( indType, .REAL_CONS, resType, realIndCons );
          self.resFlowData.add( .IND,    .REAL_CONS, resType, realIndCons );
          self.resFlowData.add( .GEN,    .REAL_CONS, resType, realIndCons );
        }
      }
    }
    //def.qlog( .DEBUG, 0, @src(), "Logging general resource prod. and cons. :" );
  }

  fn calcPopResDelta( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType   = ResType.fromIdx( r );
      const popAccess = self.genResAccessData.get( .POP, resType );

      if( popAccess > def.EPS and resType != .WORK ) // WORK handled in applyWorkWeek()
      {
        const realPopCons = popAccess * self.resFlowData.get( .POP, .MAX_CONS, resType );
        const realPopProd = popAccess * self.resFlowData.get( .POP, .MAX_PROD, resType );

        self.resFlowData.set( .POP, .REAL_PROD, resType, realPopProd );
        self.resFlowData.add( .GEN, .REAL_PROD, resType, realPopProd );

        self.resFlowData.set( .POP, .REAL_CONS, resType, realPopCons );
        self.resFlowData.add( .GEN, .REAL_CONS, resType, realPopCons );
      }
    }
  }

  fn applyResDelta( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType   = ResType.fromIdx( r );

      const maxSupply = self.resFlowData.get( .GEN, .MAX_PROD, resType );
      const maxDemand = self.resFlowData.get( .GEN, .MAX_CONS, resType );

      const realProd  = self.resFlowData.get( .GEN, .REAL_PROD, resType );
      const realCons  = self.resFlowData.get( .GEN, .REAL_CONS, resType );

      const initialStock = self.econ.resState.get( .BANK, resType );
      const finalStock   = self.resStockData.get(  resType );


      // Updating economy metrics and storage
      self.econ.resState.set( .DELTA, resType, finalStock - initialStock );

      self.econ.resState.set( .MAX_SUP, resType, maxSupply );
      self.econ.resState.set( .MAX_DEM, resType, maxDemand );

      self.econ.resState.set( .GEN_PROD, resType, realProd );
      self.econ.resState.set( .GEN_CONS, resType, realCons );


      self.resStockData.add( resType, realProd );
      self.resStockData.sub( resType, realCons );

      self.econ.resState.set( .BANK, resType, self.resStockData.get( resType ));
    }
  }


  // Pop growth factor ( ~ x4.75 each century ) // TODO : change min growth of less than 1.0 to chance to grow by 1.0
  const WEEKLY_POP_GROWTH     : f32 = 0.0003;   // TODO : update based on econTickLen

  // Pop decay factors
  const WEEKLY_PARCH_RATE     : f32 = 0.10;
  const WEEKLY_STARVE_RATE    : f32 = 0.05;
  const WEEKLY_FREEZE_RATE    : f32 = 0.02;

  const RES_SHORTAGE_EXPONENT : f32 = 2.0; // Smooth out death rates from pop res shortages
  const JOB_SHORTAGE_EXPONENT : f32 = 1.0; // Smooth out growth suppression from pop job shortages

  const MAX_RES_MODIFIER      : f32 = def.PHI;
  const MAX_JOB_MODIFIER      : f32 = def.PHI;

  fn applyPopDelta( self : *EconSolver ) void
  {
    var deaths : f64 = 0.0;
    var births : f64 = 0.0;


    // ================ FOOD ================

    const foodAccess = self.genResAccessData.get( .POP, .FOOD );

    if( foodAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing food  shortages ! ( {d:.3} )", .{ foodAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - foodAccess, RES_SHORTAGE_EXPONENT ) * WEEKLY_STARVE_RATE;
    }


    // ================ WATER ================

    const waterAccess = self.genResAccessData.get( .POP, .WATER );

    if( waterAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing water shortages ! ( {d:.3} )", .{ waterAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - waterAccess, RES_SHORTAGE_EXPONENT ) * WEEKLY_PARCH_RATE;
    }


    // ================ POWER ================

    const powerAccess = self.genResAccessData.get( .POP, .POWER );

    if( powerAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing power shortages ! ( {d:.3} )", .{ powerAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - powerAccess, RES_SHORTAGE_EXPONENT ) * WEEKLY_FREEZE_RATE;
    }


    // ================ POP DELTA ================

    const minResAccess : f64 = @min( foodAccess, waterAccess, powerAccess );
    const workAccess   : f64 = self.genResAccessData.get( .IND, .WORK );

    const resModifier : f64 = @min( def.pow( f64,     minResAccess, 1.0 / RES_SHORTAGE_EXPONENT ), MAX_RES_MODIFIER );
    const jobModifier : f64 = @min( def.pow( f64, 1.0 / workAccess, 1.0 / JOB_SHORTAGE_EXPONENT ), MAX_JOB_MODIFIER );

    births = self.prevPopCount * @as( f64, WEEKLY_POP_GROWTH ) * resModifier * jobModifier;


    def.log( .INFO, 0, @src(), "Pop access   : F {d:.4}\tW {d:.4}\tP {d:.4}", .{ foodAccess, waterAccess, powerAccess });
    def.log( .CONT, 0, @src(), "Deaths       : {d:.8}", .{ deaths });
    def.log( .CONT, 0, @src(), "Births       : {d:.8}", .{ births });
    def.log( .CONT, 0, @src(), "Res Modifier : {d:.8}", .{ resModifier });
    def.log( .CONT, 0, @src(), "Job modifier : {d:.8}", .{ jobModifier });


    // Updating economy
    const econ = self.econ;

    const popCap  : f64 = @floatFromInt( econ.getPopCap() );
    const nextPop : f64 = def.clmp( self.prevPopCount - @floor( deaths ) + @ceil( births ), 0.0, popCap );

    econ.popMetrics.set( .COUNT,  nextPop );
    econ.popMetrics.set( .DELTA,  nextPop - self.prevPopCount );
    econ.popMetrics.set( .ACCESS, @min( foodAccess, @min( waterAccess, powerAccess )));
  }
};