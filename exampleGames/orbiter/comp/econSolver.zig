const std = @import( "std" );
const def = @import( "defs" );

const ecn = @import( "economy.zig" );


const gbl = @import( "../gameGlobals.zig" );

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


const ecnm_d = gbl.ecnm_d;

const FlowAgent = ecnm_d.FlowAgentEnum;
const FlowPhase = ecnm_d.FlowPhaseEnum;
const Access    = ecnm_d.AccessAgentEnum;


// Pop growth factor ( ~ x4.75 each century ) // TODO : change min growth of less than 1.0 to chance to grow by 1.0
const WEEKLY_POP_GROWTH     : f32 = 0.0003;

// Pop decay factors
const WEEKLY_PARCH_RATE     : f32 = 0.10;
const WEEKLY_STARVE_RATE    : f32 = 0.05;
const WEEKLY_FREEZE_RATE    : f32 = 0.02;

const POP_SHORTAGE_EXPONENT : f32 = 2.0; // Smooth out death rates from pop res shortages0.20;



pub inline fn resolveEcon( econ : *ecn.Economy ) void
{
  var solver : EconSolver = .{ .econ = econ };

  solver.initBaseState();   // Zeroes out dataMatrices and resets econ metrics
  solver.applyResDecay();   // Decays stored resources based on defined rates
  solver.applyResGrowth();  // Grows wild resources based on ecology factor

  solver.calcIndMaxDelta(); // Computes industrial potential prod and cons
  solver.calcPopMaxDelta(); // Computes population potential prod and cons

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

  resStockData  : ecnm_d.ResStockData    = .{},
  resAccessData : ecnm_d.ResAccessData   = .{},
  indActivity   : ecnm_d.IndActivityData = .{},
  indFlowData   : ecnm_d.IndFlowData     = .{}, // Per industry
  resFlowData   : ecnm_d.ResFlowData     = .{}, // Agregated industry


  fn initBaseState( self : *EconSolver ) void
  {
    self.prevPopCount = self.econ.popMetrics.get( .COUNT );
    self.nextPopCount = self.prevPopCount;

    // Zero solver scratch
    self.resAccessData.fillWith( 0.0 );
    self.indActivity.fillWith(   0.0 );
    self.indFlowData.fillWith(   0.0 );
    self.resFlowData.fillWith(   0.0 );

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
    const ecoFactor = self.econ.getEcologyFactor();

  //def.qlog( .DEBUG, 0, @src(), "Logging natural resource growth :" );

    inline for( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx( r );
      const growRate = resType.getMetric_f64( .GROWTH_RATE );

      if( growRate >= def.EPS )
      {
        const growthGain = ecoFactor * ecoFactor * growRate;

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
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const maxProd = self.prevPopCount * resType.getMetric_f64( .POP_PROD );
      const maxCons = self.prevPopCount * resType.getMetric_f64( .POP_CONS );

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

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( ResType.fromIdx( r )), supply, demand });


      var access : f64 = self.maxResAccess;

      if( demand > def.EPS )
      {
        access = supply / demand;

        // If res is needed by EITHER pop or ind ( not both ), have mark the other as fully supplied
        const popMaxCons = self.resFlowData.get( .POP, .MAX_CONS, resType );
        const indMaxCons = self.resFlowData.get( .IND, .MAX_CONS, resType );

        if( popMaxCons > def.EPS ){ self.resAccessData.set( .POP, resType, access            ); }
        else                      { self.resAccessData.set( .POP, resType, self.maxResAccess ); }

        if( indMaxCons > def.EPS ){ self.resAccessData.set( .IND, resType, access            ); }
        else                      { self.resAccessData.set( .IND, resType, self.maxResAccess ); }

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage", .{ @tagName( ResType.fromIdx( r ))});
        }
      }

      // Updating economy metrics
      self.resAccessData.set( .GEN,     resType, access );
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

      workRate = @min( workRate, self.resAccessData.get( .POP, resType ));
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
    self.resAccessData.set( .POP, .WORK, self.maxResAccess ); // POP will never need work, so access is always maxed

    self.resAccessData.set( .IND, .WORK, access );
    self.resAccessData.set( .GEN, .WORK, access );

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
            activity = @min( activity, self.resAccessData.get( .IND, resType ));
          }
        }
      }

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
      const popAccess = self.resAccessData.get( .POP, resType );

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
      const finalStock   = self.resStockData.get( resType );


      // Updating economy metrics and storage
      self.econ.resState.set( .DELTA, resType, finalStock - initialStock );

      self.econ.resState.set( .MAX_SUP, resType, maxSupply );
      self.econ.resState.set( .MAX_DEM, resType, maxDemand );

      self.econ.resState.set( .FIN_PROD, resType, realProd );
      self.econ.resState.set( .FIN_CONS, resType, realCons );


      self.resStockData.add( resType, realProd );
      self.resStockData.sub( resType, realCons );

      self.econ.resState.set( .BANK, resType, self.resStockData.get( resType ));
    }
  }


  fn applyPopDelta( self : *EconSolver ) void
  {
    var deaths : f64 = 0.0;
    var births : f64 = 0.0;

    // ================ FOOD ================
    var foodAccess = self.maxResAccess;
        foodAccess = @min( foodAccess, self.resAccessData.get( .POP, .FOOD ));

    if( foodAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing food  shortages ! ( {d:.3} )", .{ foodAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - foodAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_STARVE_RATE;
    }

    // ================ WATER ================
    var waterAccess = self.maxResAccess;
        waterAccess = @min( waterAccess, self.resAccessData.get( .POP, .WATER ));

    if( waterAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing water shortages ! ( {d:.3} )", .{ waterAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - waterAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_PARCH_RATE;
    }

    // ================ POWER ================
    var powerAccess = self.maxResAccess;
        powerAccess = @min( powerAccess, self.resAccessData.get( .POP, .POWER ));

    if( powerAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing power shortages ! ( {d:.3} )", .{ powerAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - powerAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_FREEZE_RATE;
    }

    // ================ POP DELTA ================
    const suppliedRatio : f64 = def.pow( f64, @min( foodAccess, waterAccess ), 1.0 / POP_SHORTAGE_EXPONENT );

    births = self.prevPopCount * suppliedRatio * @as( f64, WEEKLY_POP_GROWTH );

    def.log( .INFO, 0, @src(), "Pop access : F {d:.4}\tW {d:.4}\tP {d:.4}", .{ foodAccess, waterAccess, powerAccess });
    def.log( .CONT, 0, @src(), "Deaths     : {d:.8}", .{ deaths });
    def.log( .CONT, 0, @src(), "Births     : {d:.8}", .{ births });
    def.log( .CONT, 0, @src(), "Supplied   : {d:.8}", .{ suppliedRatio });


    // Updating economy
    const econ = self.econ;

    const popCap  : f64 = @floatFromInt( econ.getPopCap() );
    const nextPop : f64 = def.clmp( self.prevPopCount - @floor( deaths ) + @ceil( births ), 0.0, popCap );

    econ.popMetrics.set( .COUNT,  nextPop );
    econ.popMetrics.set( .DELTA,  nextPop - self.prevPopCount );
    econ.popMetrics.set( .ACCESS, @min( foodAccess, @min( waterAccess, powerAccess )));
  }
};