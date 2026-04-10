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

  solver.calcGenResAccess(); // Computes expected agregated resource access
  solver.calcPopResAccess(); // Computes expected population resource access
  solver.calcIndResAccess(); // Computes expected industrial resource access
  solver.calcInfResAccess(); // Computes expected construction resource access

  solver.calcPopActivity();  // Computes final population activity ratio
  solver.calcIndActivity();  // Computes final industrial activity ratio


// ================ CONSUMPTION PHASE ================

  solver.calcPopResCons();   // Computes resource cons from population based on popCount
  solver.calcIndResCons();   // Computes resource cons from industry based on activity
  solver.calcInfResCons();   // Computes resource cons from construction and infrastructure maintenance
  solver.calcNatResCons();   // Decays unsued resources left based on individualized rates ( 100% for WORK )
  solver.applyGenResCons();  // Applies all resource consumption to economy


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

  solver.calcPopDelta();     // Computes population delta based on access
//solver.calcIndDelta();     // Computes industrial growth/decay based on profitability

  solver.pushEconMetrics();  // Pastes leftover metrics into economy's fields
}


const EconSolver = struct
{
  // Global consumption-production throttles / multipliers
  sunshineModifier : f32 = 1.0,
  natureModifier   : f32 = 1.0,

  maxPopResAccess  : f64 = 1.0,
  maxIndResAccess  : f64 = 1.0,
  maxInfResAccess  : f64 = 1.0,

  maxPopActivity   : f64 = 1.0,
  maxIndActivity   : f64 = 1.0,

  // Solver data
  econ : *ecn.Economy,

  prevPopCount : f64 = 0.0,
  nextPopCount : f64 = 0.0,

  popDeaths    : f64 = 0.0,
  popBirths    : f64 = 0.0,

  popActivity  : f64 = 0.0,

  resStockData : ecnm_d.ResStockData    = .{}, // aka nextResStocks
  resFlowData  : ecnm_d.ResFlowData     = .{}, // Agregated industry
  indFlowData  : ecnm_d.IndFlowData     = .{}, // Per industry
  indActivity  : ecnm_d.IndActivityData = .{}, // Per industry


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

    if( self.econ.buildDemand > def.EPS )
    {
      self.resFlowData.set( .INF, .MAX_CONS, .PART, self.econ.buildDemand );
      self.resFlowData.add( .GEN, .MAX_CONS, .PART, self.econ.buildDemand );
    }

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
    def.qlog( .INFO, 0, @src(), "$ LOGGING GEN RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply = self.resStockData.get( resType ); // Previous week's resulting bank supply
      const genDem = self.resFlowData.get( .GEN, .MAX_CONS, resType );

      var access : f64 = 0.0;

      if( genDem > def.EPS )
      {
        access = supply / genDem;
      }

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, genDem, access });
      self.resFlowData.set( .GEN, .ACCESS, resType, access );
    }
  }

  fn calcPopResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING POP RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply = self.resStockData.get( resType ); // Previous week's resulting bank supply
      const popDem = self.resFlowData.get( .POP, .MAX_CONS, resType );

      var access : f64 = self.maxPopResAccess;

      if( popDem > def.EPS )
      {
        access = @min( self.maxPopResAccess, supply / popDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, popDem, access });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage in population", .{ @tagName( resType )});
        }
      }

      self.resFlowData.set( .POP, .ACCESS, resType, access );
    }
  }

  fn calcIndResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING IND RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply = self.resStockData.get( resType ); // Previous week's resulting bank supply
      const popDem = self.resFlowData.get( .POP, .MAX_CONS, resType );
      const indDem = self.resFlowData.get( .IND, .MAX_CONS, resType );

      // Pop gets first dibs, industry gets whatever is left
      const popClaim  = @min( supply, popDem );
      const remainder = @max( 0.0, supply - popClaim );

      var access : f64 = self.maxIndResAccess;

      if( indDem > def.EPS )
      {
        access = @min( self.maxIndResAccess, remainder / indDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, indDem, access });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage in industry", .{ @tagName( resType )});
        }
      }

      self.resFlowData.set( .IND, .ACCESS, resType, access );
    }
  }

  fn calcInfResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING INF RES ACCESS :" );


    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const supply  = self.resStockData.get( resType );
      const popDem  = self.resFlowData.get( .POP, .MAX_CONS, resType );
      const indDem  = self.resFlowData.get( .IND, .MAX_CONS, resType );
      const infDem  = self.resFlowData.get( .INF, .MAX_CONS, resType );

      const popClaim  = @min( supply, popDem );
      const indClaim  = @min( @max( 0.0, supply - popClaim ), indDem );
      const remainder = @max( 0.0, supply - popClaim - indClaim );

      var access : f64 = self.maxInfResAccess;

      if( infDem > def.EPS )
      {
        access = @min( self.maxInfResAccess, remainder / infDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), supply, indDem, access });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage in infrastructure", .{ @tagName( resType )});
        }
      }

      self.resFlowData.set( .INF, .ACCESS, resType, access );
    }
  }


  fn calcPopActivity( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "$ LOGGING FINAL POP ACTIVITY :" );

    var activity : f64 = self.maxPopActivity;

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      if( self.resFlowData.get( .POP, .MAX_CONS, resType ) > def.EPS )
      {
        activity = @min( activity, self.resFlowData.get( .POP, .ACCESS, resType ));
      }

    //def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}", .{ @tagName( resType ), activity });
    }

    self.popActivity = activity; // NOTE: Should only scale pop prod, not cons
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

      // Basing new activity on previous tick's activity target AND current tick res access caps
      activity = @min( activity, self.econ.indState.get( .ACT_TRGT, indType ));

    //def.log( .CONT, 0, @src(), "{s}\t: {d:.6}", .{ @tagName( indType ), activity });

      self.indActivity.set( indType, activity );

      self.econ.indState.set( .ACT_LVL, indType, self.indActivity.get( indType ));

      // Accumulate average industrial activity rate
      self.econ.avgIndActivity += activity;
    }

    self.econ.avgIndActivity /= @floatFromInt( indTypeC );
  }

// ================================ CONSUMPTION PHASE ================================


  fn calcPopResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType      = ResType.fromIdx( r );
      const popResAccess = @min( 1.0, self.resFlowData.get(     .POP, .ACCESS,   resType ));
      const popMaxCons   = self.resFlowData.get( .POP, .MAX_CONS, resType );
      const popResConst = popResAccess * popMaxCons;

      self.resFlowData.set( .POP, .REAL_CONS, resType, popResConst );
      self.resFlowData.add( .GEN, .REAL_CONS, resType, popResConst );
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

  fn calcInfResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const infAccess  = self.resFlowData.get( .INF, .ACCESS,   resType );
      const infMaxCons = self.resFlowData.get( .INF, .MAX_CONS, resType );

      if( infMaxCons > def.EPS )
      {
        const realInfCons = infAccess * infMaxCons;

        self.resFlowData.set( .INF, .REAL_CONS, resType, realInfCons );
        self.resFlowData.add( .GEN, .REAL_CONS, resType, realInfCons );
      }
    }
  }

  fn calcNatResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx( r );
      const resCount = self.resStockData.get( resType );

      const popCons  = self.resFlowData.get( .POP, .REAL_CONS, resType );
      const indCons  = self.resFlowData.get( .IND, .REAL_CONS, resType );
      const infCons  = self.resFlowData.get( .INF, .REAL_CONS, resType );
      const totCons  = popCons + indCons + infCons;

      // Decay applies to what remains AFTER pop and ind consumption
      const remainder = @max( 0.0, resCount - totCons ); //

      if( remainder > def.EPS and resCount > def.EPS  )
      {
        const realNatCons = remainder * resType.getMetric_f64( .DECAY_RATE );

        self.resFlowData.set( .NAT, .REAL_CONS, resType, realNatCons );
      }
    }
  }

  fn applyGenResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genCons = self.resFlowData.get( .GEN, .REAL_CONS, resType );
      const natCons = self.resFlowData.get( .NAT, .REAL_CONS, resType );

      self.resStockData.sub( resType, genCons + natCons );
    }
  }


// ================================ PRODUCTION PHASE ================================


  fn calcPopResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType     = ResType.fromIdx( r );
      const realPopProd = self.popActivity * self.resFlowData.get( .POP, .MAX_PROD, resType );

      self.resFlowData.set( .POP, .REAL_PROD, resType, realPopProd );
      self.resFlowData.add( .GEN, .REAL_PROD, resType, realPopProd );
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
      }
    }
  }

  fn applyGenResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genProd = self.resFlowData.get( .GEN, .REAL_PROD, resType );
      const natProd = self.resFlowData.get( .NAT, .REAL_PROD, resType );

      self.resStockData.add( resType, genProd + natProd );
    }
  }


// ================================ POST-CALC PHASE ================================


  const MAX_SCARC_RATIO  : f64 = 100.0;
  const MIN_PRICE_FACTOR : f64 = 0.005;

  fn updatedResPrice( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING RES PRICES :" );

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const basePrice  = resType.getMetric_f64( .PRICE_BASE );
      const elasticity = resType.getMetric_f64( .PRICE_ELAS );
      const dampening  = resType.getMetric_f64( .PRICE_DAMP ); // Lerp factor (0 = no change, 1 = instant)

      // Flow-based: compare this tick's production vs this tick's consumption demand
      const realDemand = self.resFlowData.get( .GEN, .REAL_CONS, resType ); // NOTE : EXCLUDES NATURAL DECAY
      const realSupply = self.resFlowData.get( .GEN, .REAL_PROD, resType )
                       + self.resFlowData.get( .NAT, .REAL_PROD, resType );

      const ceil : f64 = MAX_SCARC_RATIO; // Scarcity ceiling
      var  ratio : f64 =   0.0;

      if(      realSupply > def.EPS ){ ratio = @min( ceil, realDemand / realSupply ); }
      else if( realDemand > def.EPS ){ ratio = ceil; }

      const rawPrice = basePrice * @max( MIN_PRICE_FACTOR, def.pow( f64, ratio, elasticity ));
      const oldPrice = self.econ.resState.get( .PRICE, resType );
      const newPrice = def.lerp(  oldPrice, rawPrice, dampening ); // Lerp smoothing
      const dltPrice = newPrice - oldPrice;

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}\t| {d:.6}\t {d:.6}\t| {d:.6}", .{ @tagName( resType ), basePrice, oldPrice, newPrice, dltPrice });

      self.econ.resState.set( .PRICE,   resType, newPrice );
      self.econ.resState.set( .PRICE_D, resType, dltPrice );
    }
  }

//fn updatePopProfit( self : *EconSolver ) void

//fn updateInfProfit( self : *EconSolver ) void


  const PROFITABILITY_FLOOR : f64 = -2.5;

  fn updateIndProfit( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING IND PROFITS :" );

    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .BANK, indType );

      if( indType.canBeBuiltIn( self.econ.location, self.econ.hasAtmo ))
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
        const activityTarget = self.maxIndActivity * def.sigmoid( margin, 8.0 ); // NOTE : lower K for smoother transitioning

        self.econ.indState.set( .ACT_TRGT, indType, activityTarget );

        if( indCount > def.EPS )
        {
          def.log( .CONT, 0, @src(), "{s}\t: {d:.6}\t-{d:.6}\t| {d:.6}\t{d:.6}", .{ @tagName( indType ), revenue, expense, margin, activityTarget });

          self.econ.indState.set( .EXPENSE,  indType, expense * indCount );
          self.econ.indState.set( .REVENUE,  indType, revenue * indCount );
          self.econ.indState.set( .PROFIT,   indType, profit  * indCount );
        }
        else
        {
          self.econ.indState.set( .EXPENSE,  indType, 0.0 );
          self.econ.indState.set( .REVENUE,  indType, 0.0 );
          self.econ.indState.set( .PROFIT,   indType, 0.0 );
        }
      }
      else
      {
        self.econ.indState.set( .ACT_TRGT, indType, 0.0 );
        self.econ.indState.set( .EXPENSE,  indType, 0.0 );
        self.econ.indState.set( .REVENUE,  indType, 0.0 );
        self.econ.indState.set( .PROFIT,   indType, 0.0 );
      }

    }
  }

//fn updateGovProfit( self : *EconSolver ) void


// ================================ ECON UPDATE PHASE ================================


// Pop growth factor ( ~ x4.75 each century ) // TODO : change min growth of less than 1.0 to chance to grow by 1.0
  const WEEKLY_POP_GROWTH     : f64 = 0.0003;   // TODO : update based on econTickLen

  // Pop decay factors
  const WEEKLY_PARCH_RATE     : f64 = 0.08;
  const WEEKLY_STARVE_RATE    : f64 = 0.03;
  const WEEKLY_FREEZE_RATE    : f64 = 0.01;

  const RES_SHORTAGE_EXPONENT : f64 = def.PHI; // Smooth out death rates from pop res shortages
  const JOB_SHORTAGE_EXPONENT : f64 = def.PHI; // Smooth out growth suppression from pop job shortages

  const MAX_RES_MODIFIER      : f64 = @sqrt( def.PHI );
  const MAX_JOB_MODIFIER      : f64 = @sqrt( def.PHI );


  fn calcPopDelta( self : *EconSolver ) void
  {
    var mortalityRate : f64 = 0.0;

    // TODO : DE-HARDCODE ACCESS CALCS FOR DEATHS

    // ================ FOOD ================

    const foodAccess = self.resFlowData.get( .POP, .ACCESS, .FOOD );

    if( foodAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing food  shortages ! ( {d:.3} )", .{ foodAccess });

      mortalityRate += WEEKLY_STARVE_RATE * def.pow( f64, 1.0 - foodAccess, RES_SHORTAGE_EXPONENT );
    }


    // ================ WATER ================

    const waterAccess = self.resFlowData.get( .POP, .ACCESS, .WATER );

    if( waterAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing water shortages ! ( {d:.3} )", .{ waterAccess });

      mortalityRate += WEEKLY_PARCH_RATE * def.pow( f64, 1.0 - waterAccess, RES_SHORTAGE_EXPONENT );
    }


    // ================ POWER ================

    const powerAccess = self.resFlowData.get( .POP, .ACCESS, .POWER );

    if( powerAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing power shortages ! ( {d:.3} )", .{ powerAccess });

      mortalityRate += WEEKLY_FREEZE_RATE * def.pow( f64, 1.0 - powerAccess, RES_SHORTAGE_EXPONENT );
    }

    self.popDeaths = @floor( self.prevPopCount * mortalityRate );


    // ================ POP GROWTH ================

    const minResAccess : f64 = @min( foodAccess, waterAccess, powerAccess );
    const jobAccess    : f64 = @max( def.EPS, self.resFlowData.get( .GEN, .ACCESS, .WORK ));

    const resModifier  : f64 = @min( def.pow( f64,    minResAccess, 1.0 / RES_SHORTAGE_EXPONENT ), MAX_RES_MODIFIER );
    const jobModifier  : f64 = @min( def.pow( f64, 1.0 / jobAccess, 1.0 / JOB_SHORTAGE_EXPONENT ), MAX_JOB_MODIFIER );

    const natalityRate : f64 = WEEKLY_POP_GROWTH * resModifier * jobModifier;

    self.popBirths = @ceil( self.prevPopCount * natalityRate );


    // ================ POP DELTA ================

    const popCap : f64 = @floatFromInt( self.econ.getPopCap() );

    self.nextPopCount = def.clmp( self.prevPopCount + self.popBirths - self.popDeaths, 0.0, popCap );

    def.qlog( .INFO, 0, @src(), "$ LOGGING POP FACTORS :" );
    def.log(  .CONT, 0, @src(), "Pop access : F {d:.4}\tW {d:.4}\tP {d:.4}", .{ foodAccess, waterAccess, powerAccess });
    def.log(  .CONT, 0, @src(), "Res & Job Modifiers : {d:.8}\t{d:.8}",      .{ resModifier,       jobModifier       });
    def.log(  .CONT, 0, @src(), "Death & Birth Rates : {d:.8}\t{d:.8}",      .{ mortalityRate,     natalityRate      });
    def.log(  .CONT, 0, @src(), "Prev & Next Pop     : {d:.0}\t{d:.0}",      .{ self.prevPopCount, self.nextPopCount });
  }

//fn applyIndDelta( self : *EconSolver ) void
// TODO : calc target industrial growth / decay based on profitability
// NOTE : remove capital from industry from growth costs
// NOTE : inject capital into industry from decay selloffs

  fn pushEconMetrics( self : *EconSolver ) void
  {
    const econ : *ecn.Economy = self.econ;

    econ.popMetrics.set( .ACTIVITY, self.popActivity  );
    econ.popMetrics.set( .COUNT,    self.nextPopCount );
    econ.popMetrics.set( .DELTA,    self.nextPopCount - self.prevPopCount );

    self.econ.buildBudget = self.resFlowData.get( .INF, .REAL_CONS, .PART );


    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const initialStock = self.econ.resState.get( .BANK, resType );
      const finalStock   = self.resStockData.get( resType );

      econ.resState.set( .BANK,  resType, @max( 0.0, finalStock ));
      econ.resState.set( .DELTA, resType, finalStock - initialStock );

      econ.resState.set( .MAX_SUP,  resType, self.resFlowData.get( .GEN, .MAX_PROD,  resType ));
      econ.resState.set( .MAX_DEM,  resType, self.resFlowData.get( .GEN, .MAX_CONS,  resType ));

      econ.resState.set( .GEN_PROD, resType, self.resFlowData.get( .GEN, .REAL_PROD, resType ));
      econ.resState.set( .GEN_CONS, resType, self.resFlowData.get( .GEN, .REAL_CONS, resType ));

      econ.resState.set( .DECAY,    resType, self.resFlowData.get( .NAT, .REAL_CONS, resType ));
      econ.resState.set( .GROWTH,   resType, self.resFlowData.get( .NAT, .REAL_PROD, resType ));

      econ.resState.set( .GEN_ACS,  resType, self.resFlowData.get( .GEN, .ACCESS,    resType ));
      econ.resState.set( .POP_ACS,  resType, self.resFlowData.get( .POP, .ACCESS,    resType ));
      econ.resState.set( .IND_ACS,  resType, self.resFlowData.get( .IND, .ACCESS,    resType ));

      // Accumulate average resource access rate
      econ.avgResAccess += self.resFlowData.get( .GEN, .ACCESS, resType );
    }

    econ.avgResAccess /= @floatFromInt( resTypeC );
  }
};
