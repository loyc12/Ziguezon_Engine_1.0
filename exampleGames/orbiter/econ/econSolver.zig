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



pub inline fn resolveEcon( econ : *ecn.Economy ) void
{
  var solver : EconSolver = .{ .econ = econ };

  solver.initBaseState();    // Zeroes out dataMatrices and resets econ metrics


// ================ PRECALC PHASE ================

  solver.calcPopMaxDelta();  // Computes maximal possible population prod and cons
  solver.calcIndMaxDelta();  // Computes maximal possible industrial prod and cons

  solver.calcGenResAccess(); // Computes expected agregated  resource access
  solver.calcPopResAccess(); // Computes expected population resource access
  solver.calcIndResAccess(); // Computes expected industrial resource access

  solver.calcIndActivity();  // Computes expected industrial activity ratio


// ================ CONSUMPTION PHASE ================

  solver.calcPopResCons();   // Computes resource cons from population based on popCount
  solver.calcIndResCons();   // Computes resource cons from industry based on activity
  solver.calcNatResCons();   // Decays unsued resources left based on individualized rates ( 100% for WORK )
  solver.applyGenResCons();  // Applies all resource consumption to economy


// ================ COUNT UPDATE PHASE ================

  solver.applyPopDelta();    // Apply population delta based on access
//solver.applyIndDelta();    // Apply industrial growth/decay based on profitability


// ================ PRODUCTION PHASE ================

  solver.calcPopResProd();   // Computes resource prod from population based on popCount
  solver.calcIndResProd();   // Computes resource prod from industry based on activity
  solver.calcNatResProd();   // Adds free "wild" resources to bank proportionally to ecology factor
  solver.applyGenResProd();  // Applies all resource production to economy


// ================ POST-CALC PHASE ================

  solver.updatedResPrice();  // Update res prices from real supply and demand
//solver.updatePopProfit();
  solver.updateIndProfit();  // Update monetary metrics for each industry type
//solver.updateGovProfit();


// ================ ECON UPDATE PHASE ================

  solver.pushEconMetrics();  // Pastes leftover metrics into economy's fields
}


const EconSolver = struct
{
  // Global consumption-production throttles / multipliers
  maxPopResAccess  : f64 = 1.0,
  maxIndResAccess  : f64 = 1.0,
  maxIndActivity   : f64 = 1.0,

//minWorkRate      : f64 = 0.2,
//maxWorkRate      : f64 = 1.0,

  sunshineModifier : f32 = 1.0,
  natureModifier   : f32 = 1.0,

  // Solver data
  econ : *ecn.Economy,

  prevPopCount  : f64 = 0.0,
  nextPopCount  : f64 = 0.0,

  resStockData     : ecnm_d.ResStockData     = .{},
  resFlowData      : ecnm_d.ResFlowData      = .{}, // Agregated industry
  indFlowData      : ecnm_d.IndFlowData      = .{}, // Per industry
  indActivity      : ecnm_d.IndActivityData  = .{}, // Per industry


  fn initBaseState( self : *EconSolver ) void
  {
    self.prevPopCount = self.econ.popMetrics.get( .COUNT );
    self.nextPopCount = self.prevPopCount;

    inline for( 0..ResType.count )| r |
    {
      const resType   = ResType.fromIdx( r );
      const econStock = self.econ.resState.get( .BANK, resType );

      self.resStockData.set( resType, econStock );
    }

    self.resFlowData.fillWith( 0.0 );
    self.indActivity.fillWith( 0.0 );
    self.indFlowData.fillWith( 0.0 );

    self.econ.resetCountMetrics();
  }


// ================================ PRE-CALC PHASE ================================


  fn calcPopMaxDelta( self : *EconSolver ) void
  {
  //def.qlog( .INFO, 0, @src(), "$ LOGGING DELTAS FOR POP :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const maxProd = self.prevPopCount * resType.getMetric_f64( .POP_PROD );
      const maxCons = self.prevPopCount * resType.getMetric_f64( .POP_CONS );

    //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons });

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

  fn calcIndMaxDelta( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .BANK, indType );

    //def.log( .INFO, 0, @src(), "$ LOGGING DELTAS FOR {s} :", .{ @tagName( indType )});

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
      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons });

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



  fn calcGenResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGIN GEN RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply = self.resStockData.get( resType ); // Previous week's resulting bank supply
      const demand = self.resFlowData.get( .GEN, .MAX_CONS, resType );

      var access : f64 = self.maxPopResAccess;

      if( demand > def.EPS )
      {
        access = @min( self.maxPopResAccess, supply / demand );
      }

      self.resFlowData.set( .GEN, .ACCESS, resType, access );
      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, demand, access });
    }
  }

  fn calcPopResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGIN POP RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply = self.resStockData.get( resType ); // Previous week's resulting bank supply
      const popDem = self.resFlowData.get( .POP, .MAX_CONS, resType );

      var access : f64 = self.maxPopResAccess;

      if( popDem > def.EPS )
      {
        access = @min( self.maxPopResAccess, supply / popDem );
      }

      self.resFlowData.set( .POP, .ACCESS, resType, access );
      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, popDem, access });

      if( access < 1.0 - def.EPS )
      {
        def.log( .CONT, 0, @src(), "@ {s} shortage in population", .{ @tagName( resType )});
      }
    }
  }

  fn calcIndResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGIN IND RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply = self.resStockData.get( resType ); // Previous week's resulting bank supply
      const popDem = self.resFlowData.get( .POP, .MAX_CONS, resType );
      const indDem = self.resFlowData.get( .IND, .MAX_CONS, resType );

      // Pop claims first — industry gets the remainder
      const popClaim  = @min( supply, popDem );
      const remainder = @max( 0.0, supply - popClaim );

      var access : f64 = self.maxIndResAccess;

      if( indDem > def.EPS )
      {
        access = @min( self.maxIndResAccess, remainder / indDem );
      }

      self.resFlowData.set( .IND, .ACCESS, resType, access );
      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, indDem, access });

      if( access < 1.0 - def.EPS )
      {
        def.log( .CONT, 0, @src(), "@ {s} shortage in industry", .{ @tagName( resType )});
      }
    }
  }


  fn calcIndActivity( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "$ LOGGING FINAL IND ACTIVITY :" );

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
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          const maxCons = self.indFlowData.get( indType, .MAX_CONS, resType );

          if( maxCons > def.EPS )
          {
            activity = @min( activity, self.resFlowData.get( .IND, .ACCESS, resType ));
          }
        }
      }

      activity = @min( activity, self.econ.indState.get( .ACT_TRGT, indType ));

      // Updating economy metrics
      self.indActivity.set(             indType, activity );
      self.econ.indState.set( .ACT_LVL, indType, activity );

      self.econ.avgIndActivity += activity;
    }

    self.econ.avgIndActivity /= @floatFromInt( indTypeC );
  }

//fn calcResAccess( self : *EconSolver ) void
//{
//  def.qlog( .DEBUG, 0, @src(), "Logging resource availabilities and requirements :" );
//
//  inline for( 0..resTypeC )| r |{ if( ResType.fromIdx( r ) != .WORK ) // Skipping WORK ( see calcWorkAccess() )
//  {
//    const resType = ResType.fromIdx( r );
//
//    // Calculating supply and demand
//    const supply = self.resStockData.get( resType );
//    const demand = self.resFlowData.get( .GEN, .MAX_CONS, resType );
//
//    def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), supply, demand });
//
//    var access : f64 = self.maxResAccess;
//
//    if( demand > def.EPS )
//    {
//      access = supply / demand;
//
//      // If res is needed by EITHER pop or ind ( not both ), have mark the other as fully supplied
//      const popMaxCons = self.resFlowData.get( .POP, .MAX_CONS, resType );
//      const indMaxCons = self.resFlowData.get( .IND, .MAX_CONS, resType );
//
//      if( popMaxCons > def.EPS ){ self.resFlowData.set( .POP, .ACCESS, resType, access            ); }
//      else                      { self.resFlowData.set( .POP, .ACCESS, resType, self.maxResAccess ); }
//
//      if( indMaxCons > def.EPS ){ self.resFlowData.set( .IND, .ACCESS, resType, access            ); }
//      else                      { self.resFlowData.set( .IND, .ACCESS, resType, self.maxResAccess ); }
//
//      if( access < 1.0 - def.EPS )
//      {
//        def.log( .CONT, 0, @src(), "@ {s} shortage", .{ @tagName( resType )});
//      }
//    }
//    else
//    {
//      self.resFlowData.set( .POP, .ACCESS, resType, self.maxResAccess );
//      self.resFlowData.set( .IND, .ACCESS, resType, self.maxResAccess );
//    }
//
//    // Updating economy metrics
//    self.resFlowData.set( .GEN, .ACCESS,     resType, access );
//    self.econ.resState.set( .SAT_LVL, resType, access );
//
//    self.econ.avgResAccess += access / ResType.count;
//  }}
//}
//
//fn applyWorkWeek( self : *EconSolver ) void // TODO : If some industries produce work, produce it here too
//{
//  var workRate : f64 = self.maxWorkRate;
//
//  inline for( 0..resTypeC )| r |{ if( ResType.fromIdx( r ) != .WORK )
//  {
//    const resType = ResType.fromIdx( r );
//
//    const popMaxCons = self.resFlowData.get( .POP, .MAX_CONS, resType );
//
//    if( popMaxCons > def.EPS )
//    {
//      workRate = @min( workRate, self.resFlowData.get( .POP, .ACCESS, resType ));
//    }
//  }}
//
//  // Clamping pop work rates to a minimum to prevent total supply chain collapse
//  workRate = @max( workRate, self.minWorkRate );
//
////def.log( .CONT, 0, @src(), "# WORK rate\t: {d:.4}", .{ workRate });
//
//  // Updating economy metrics
//  const weeklyPopWork = workRate * self.resFlowData.get( .POP, .MAX_PROD, .WORK );
//
//  self.resFlowData.set( .POP, .REAL_PROD, .WORK, weeklyPopWork );
//  self.resFlowData.add( .GEN, .REAL_PROD, .WORK, weeklyPopWork );
//
//  self.resStockData.add( .WORK, weeklyPopWork );
//
//}
//
//fn calcWorkAccess( self : *EconSolver ) void
//{
//  // Like calcResAccess() + applyResDelta(), but only for work, since we need other res to calculate work prod
//
//  // Calculating supply and demand
//  const supply = self.resStockData.get( .WORK );
//  const demand = self.resFlowData.get( .IND, .MAX_CONS, .WORK );
//
//  def.log( .CONT, 0, @src(), "WORK  \t: {d:.0}\t-{d:.0}", .{ supply, demand });
//
//  self.resFlowData.add( .GEN, .MAX_PROD, .WORK, supply );
//  self.resFlowData.add( .GEN, .MAX_CONS, .WORK, demand );
//
//  var access : f64 = self.maxResAccess;
//
//  if( demand > def.EPS )
//  {
//    access = supply / demand;
//
//    if( access < 1.0 - def.EPS )
//    {
//      def.qlog( .CONT, 0, @src(), "@ WORK shortage" );
//    }
//  }
//
//  // Updating economy metrics
//  self.resFlowData.set( .POP, .ACCESS, .WORK, self.maxResAccess ); // POP will never need work, so access is always maxed
//
//  self.resFlowData.set( .IND, .ACCESS, .WORK, access );
//  self.resFlowData.set( .GEN, .ACCESS, .WORK, access );
//
//  self.econ.resState.set( .SAT_LVL, .WORK, access );
//
//  self.econ.avgResAccess += access / ResType.count;
//}



// ================================ CONSUMPTION PHASE ================================


  fn calcPopResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType   = ResType.fromIdx( r );
      const popAccess = self.resFlowData.get( .POP, .ACCESS, resType );

      if( popAccess > def.EPS )
      {
        const realPopCons = popAccess * self.resFlowData.get( .POP, .MAX_CONS, resType );

        self.resFlowData.set( .POP, .REAL_CONS, resType, realPopCons );
        self.resFlowData.add( .GEN, .REAL_CONS, resType, realPopCons );
      }
    }
  }

  fn calcIndResCons( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );
      const indActivity = self.indActivity.get( indType );

      if( indActivity > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType     = ResType.fromIdx( r );
          const realIndCons = indActivity * self.indFlowData.get( indType, .MAX_CONS, resType );

          self.indFlowData.set( indType, .REAL_CONS, resType, realIndCons );
          self.resFlowData.add( .IND,    .REAL_CONS, resType, realIndCons );
          self.resFlowData.add( .GEN,    .REAL_CONS, resType, realIndCons );
        }
      }
    }
  }

  fn calcNatResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType   = ResType.fromIdx( r );
      const resCount  = self.resStockData.get( resType );
      const popCons   = self.resFlowData.get( .POP, .REAL_CONS, resType );
      const indCons   = self.resFlowData.get( .IND, .REAL_CONS, resType );

      // Decay applies to what remains AFTER pop and ind consumption
      const remainder = @max( 0.0, resCount - ( popCons + indCons ));

      if( remainder > def.EPS and resCount > def.EPS  )
      {
        const realNatCons = remainder * resType.getMetric_f64( .DECAY_RATE );

        self.resFlowData.set( .NAT, .REAL_CONS, resType, realNatCons );
        self.resFlowData.add( .GEN, .REAL_CONS, resType, realNatCons );
      }
    }
  }

  fn applyGenResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genCons = self.resFlowData.get( .GEN, .REAL_CONS, resType );

      self.resStockData.sub( resType, genCons );
    }
  }


// ================================ COUNT UPDATE PHASE ================================


// Pop growth factor ( ~ x4.75 each century ) // TODO : change min growth of less than 1.0 to chance to grow by 1.0
  const WEEKLY_POP_GROWTH     : f64 = 0.0003;   // TODO : update based on econTickLen

  // Pop decay factors
  const WEEKLY_PARCH_RATE     : f64 = 0.08;
  const WEEKLY_STARVE_RATE    : f64 = 0.03;
  const WEEKLY_FREEZE_RATE    : f64 = 0.01;

  const RES_SHORTAGE_EXPONENT : f64 = 2.0; // Smooth out death rates from pop res shortages
  const JOB_SHORTAGE_EXPONENT : f64 = 1.0; // Smooth out growth suppression from pop job shortages

  const MAX_RES_MODIFIER      : f64 = @sqrt( def.PHI );
  const MAX_JOB_MODIFIER      : f64 = @sqrt( def.PHI );


  fn applyPopDelta( self : *EconSolver ) void
  {
    var deaths : f64 = 0.0;
    var births : f64 = 0.0;


    // TODO : DE-HARDCODE

    // ================ FOOD ================

    const foodAccess = self.resFlowData.get( .POP, .ACCESS, .FOOD );

    if( foodAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing food  shortages ! ( {d:.3} )", .{ foodAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - foodAccess, RES_SHORTAGE_EXPONENT ) * WEEKLY_STARVE_RATE;
    }


    // ================ WATER ================

    const waterAccess = self.resFlowData.get( .POP, .ACCESS, .WATER );

    if( waterAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing water shortages ! ( {d:.3} )", .{ waterAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - waterAccess, RES_SHORTAGE_EXPONENT ) * WEEKLY_PARCH_RATE;
    }


    // ================ POWER ================

    const powerAccess = self.resFlowData.get( .POP, .ACCESS, .POWER );

    if( powerAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing power shortages ! ( {d:.3} )", .{ powerAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - powerAccess, RES_SHORTAGE_EXPONENT ) * WEEKLY_FREEZE_RATE;
    }


    // ================ POP DELTA ================

    const minResAccess : f64 = @min( foodAccess, waterAccess, powerAccess );
    const workAccess   : f64 = self.resFlowData.get( .GEN, .ACCESS, .WORK );

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

    // Activity takes effect this tick
    econ.popMetrics.set( .ACTIVITY, @min( foodAccess, waterAccess, powerAccess ));

    // Population changes take effect next tick
    econ.popMetrics.set( .COUNT,  nextPop );
    econ.popMetrics.set( .DELTA,  nextPop - self.prevPopCount );
  }


// ================================ PRODUCTION PHASE ================================


  fn calcPopResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType   = ResType.fromIdx( r );
      const activity = self.econ.popMetrics.get( .ACTIVITY );

      if( activity > def.EPS )
      {
        const realPopProd = activity * self.resFlowData.get( .POP, .MAX_PROD, resType );

        self.resFlowData.set( .POP, .REAL_PROD, resType, realPopProd );
        self.resFlowData.add( .GEN, .REAL_PROD, resType, realPopProd );
      }
    }
  }

  fn calcIndResProd( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );
      const indActivity = self.indActivity.get( indType );

      if( indActivity > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType     = ResType.fromIdx( r );
          const realIndProd = indActivity * self.indFlowData.get( indType, .MAX_PROD, resType );

          self.indFlowData.set( indType, .REAL_PROD, resType, realIndProd );
          self.resFlowData.add( .IND,    .REAL_PROD, resType, realIndProd );
          self.resFlowData.add( .GEN,    .REAL_PROD, resType, realIndProd );
        }
      }
    }
  }

  fn calcNatResProd( self : *EconSolver ) void
  {
    const ecoFactor = self.econ.getEcoFactor();

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const growthRate = resType.getMetric_f64( .GROWTH_RATE );

      if( growthRate >= def.EPS )
      {
        const realNatProd = @max( 0.0, ecoFactor * ecoFactor * ecoFactor * growthRate );

        self.resFlowData.set( .NAT, .REAL_PROD, resType, realNatProd );
        self.resFlowData.add( .GEN, .REAL_PROD, resType, realNatProd );
      }
    }
  }

  fn applyGenResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genProd = self.resFlowData.get( .GEN, .REAL_PROD, resType );

      self.resStockData.add( resType, genProd );
    }
  }


//fn applyResDelta( self : *EconSolver ) void
//{
//  inline for( 0..resTypeC )| r |
//  {
//    const resType   = ResType.fromIdx( r );
//
//    const maxSupply = self.resFlowData.get( .GEN, .MAX_PROD, resType );
//    const maxDemand = self.resFlowData.get( .GEN, .MAX_CONS, resType );
//
//    const realProd  = self.resFlowData.get( .GEN, .REAL_PROD, resType );
//    const realCons  = self.resFlowData.get( .GEN, .REAL_CONS, resType );
//
//    const initialStock = self.econ.resState.get( .BANK, resType );
//    const finalStock   = self.resStockData.get(  resType );
//
//
//    // Updating economy metrics and storage
//    self.econ.resState.set( .DELTA, resType, finalStock - initialStock );
//
//    self.econ.resState.set( .MAX_SUP, resType, maxSupply );
//    self.econ.resState.set( .MAX_DEM, resType, maxDemand );
//
//    self.econ.resState.set( .GEN_PROD, resType, realProd );
//    self.econ.resState.set( .GEN_CONS, resType, realCons );
//
//
//    self.resStockData.add( resType, realProd );
//    self.resStockData.sub( resType, realCons );
//
//    self.econ.resState.set( .BANK, resType, self.resStockData.get( resType ));
//  }
//}


// ================================ POST-CALC PHASE ================================


  const MAX_SCARC_RATIO  : f64 = 100.0;
  const MIN_PRICE_FACTOR : f64 = 0.005;

  fn updatedResPrice( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging resource prices :" );

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const basePrice  = resType.getMetric_f64( .PRICE_BASE );
      const elasticity = resType.getMetric_f64( .PRICE_ELAS );
      const dampening  = resType.getMetric_f64( .PRICE_DAMP ); // Lerp factor (0 = no change, 1 = instant)

      const realSupply = self.resStockData.get( resType );
      const realDemand = self.resFlowData.get( .GEN, .REAL_CONS, resType );

      const ceil : f64 = MAX_SCARC_RATIO; // Scarcity ceiling
      var  ratio : f64 =   0.0;

      if(      realSupply > def.EPS ){ ratio = @min( ceil, realDemand / realSupply ); }
      else if( realDemand > def.EPS ){ ratio = ceil; }

      const oldPrice = self.econ.resState.get( .PRICE, resType );
      const rawPrice = basePrice * @max( MIN_PRICE_FACTOR, def.pow( f64, ratio, elasticity ));

      const newPrice = def.lerp(  oldPrice, rawPrice, dampening ); // Lerp smoothing
      const delta    = newPrice - oldPrice;

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}\t| {d:.6}\t {d:.6}\t| {d:.6}", .{ @tagName( resType ), basePrice, oldPrice, newPrice, delta });

      self.econ.resState.set( .PRICE,   resType, newPrice );
      self.econ.resState.set( .PRICE_D, resType, delta    );
    }
  }

//fn updatePopProfit( self : *EconSolver ) void


  const PROFITABILITY_FLOOR : f64 = -2.5;

  fn updateIndProfit( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging industrial profitability :" );

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

        const floor : f64 = PROFITABILITY_FLOOR;
        var  margin : f64 = 0.0;

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

//fn updateGovProfit( self : *EconSolver ) void


// ================================ ECON UPDATE PHASE ================================


//fn applyIndDelta( self : *EconSolver ) void

  fn pushEconMetrics( self : *EconSolver ) void
  {
    const econ : *ecn.Economy = self.econ;

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const initialStock = self.econ.resState.get( .BANK, resType );
      const finalStock   = self.resStockData.get( resType );

      econ.resState.set( .DELTA, resType, finalStock - initialStock );
      econ.resState.set( .BANK,  resType, @max( 0.0, finalStock ));

      econ.resState.set( .MAX_SUP,  resType, self.resFlowData.get( .GEN, .MAX_PROD,  resType ));
      econ.resState.set( .MAX_DEM,  resType, self.resFlowData.get( .GEN, .MAX_CONS,  resType ));

      econ.resState.set( .GEN_PROD, resType, self.resFlowData.get( .GEN, .REAL_PROD, resType ));
      econ.resState.set( .GEN_CONS, resType, self.resFlowData.get( .GEN, .REAL_CONS, resType ));

      econ.resState.set( .DECAY,  resType, self.resFlowData.get( .NAT, .REAL_CONS, resType ));
      econ.resState.set( .GROWTH, resType, self.resFlowData.get( .NAT, .REAL_PROD, resType ));

      econ.resState.set( .GEN_ACS, resType,  self.resFlowData.get( .GEN, .ACCESS, resType ));
      econ.resState.set( .POP_ACS, resType,  self.resFlowData.get( .POP, .ACCESS, resType ));
      econ.resState.set( .IND_ACS, resType,  self.resFlowData.get( .IND, .ACCESS, resType ));

      // Accumulate average access
      econ.avgResAccess += self.resFlowData.get( .GEN, .ACCESS, resType );
    }

    econ.avgResAccess /= @floatFromInt( resTypeC );
  }
};
