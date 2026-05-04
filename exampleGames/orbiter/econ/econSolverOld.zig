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


const ecnm_d = gdf.ecnm_d;

// NOTE : This reused-memory patern will be an issue if we ever multi-thread processing
var solver : EconSolver = .{ .econ = undefined };

pub inline fn stepEcon( econ : *ecn.Economy ) *const EconSolver
{
  // NOTE : Ensure the reset is total between each call of stepEcon()
  solver.resetValues(); // Zeroes out non-initializable data
  solver.initBaseState( econ ); // Initializes data from econ


// ================ PRECALC PHASE ================

  solver.calcPopMaxDelta();   // Computes maximal possible population   prod and cons
  solver.calcMntMaxDelta();   // Computes maximal possible maintenance  consumption
  solver.calcIndMaxDelta();   // Computes maximal possible industrial   prod and cons
  solver.calcBldMaxDelta();   // Computes maximal possible construction prod and cons

  solver.calcGenResAccess();  // Computes expected agregated    resource access
  solver.calcPopResAccess();  // Computes expected population   resource access
  solver.calcMntResAccess();  // Computes expected maintenance  resource access
  solver.calcIndResAccess();  // Computes expected industrial   resource access
  solver.calcBldResAccess();  // Computes expected construction resource access

  solver.calcPopFulfilment(); // Computes final population fulfilment ratio
  solver.calcIndActivity();   // Computes final industrial activity ratio


// ================ CONSUMPTION PHASE ================

// TODO : add WORK consumption for building and maintenance

  solver.calcPopResCons();  // Computes resource cons from population based on popCount
  solver.calcMntResCons();  // Computes resource cons from maintenance
  solver.calcIndResCons();  // Computes resource cons from industry based on activity
  solver.calcBldResCons();  // Computes resource cons from construction
//solver.calcComResCons();  // Computes resource cons from exports

  solver.applyGenResCons(); // Applies all resource consumption to economy
  solver.applyNatResCons(); // Decays unsued resources left based on individualized rates ( 100% for WORK )


// ================ PRODUCTION PHASE ================

  solver.calcPopResProd();  // Computes resource prod from population based on popCount
  solver.calcIndResProd();  // Computes resource prod from industry based on activity
//solver.calcBldResProd();  // Computes resource prod from deconstruction ( selloffs )
//solver.calcComResProd();  // Computes resource prod from imports

  solver.applyGenResProd(); // Applies all resource production to economy
//solver.applyNatResProd(); // Adds free "wild" resources proportionally to ecology factor


// ================ FINANCES PHASE ================

  solver.clampResStocks();  // Clamps resource amounts to what their respective stores can handle
  solver.updateResPrices(); // Update res prices from real supply and demand

  solver.updatePopFinances(); // Update monetary metrics for each population type
  solver.updateIndFinances(); // Update monetary metrics for each industry type
//solver.updateComFinances();
//solver.updateBldFinances();
//solver.updateGovFinances();


// ================ POST-CALC PHASE ================

  solver.updatePopCount();  // Computes population delta based on access
//solver.updatePopCount();  // Computes industrial growth/decay based on profitability

  solver.pushEconMetrics(); // Pastes leftover metrics into economy's fields

  return &solver;
}


// ================================ SOLVER STRUCT ================================

pub const EconSolver = struct
{
  // Global consumption-production throttles / multipliers ( generally static )
  defGenResAccess  : f64 = 1.0,
  maxPopResAccess  : f64 = 1.0,
  maxMntResAccess  : f64 = 1.0,
  maxIndResAccess  : f64 = 1.0,
  maxBldResAccess  : f64 = 1.0,
  maxComResAccess  : f64 = 1.0,

  maxPopActivity   : f64 = 1.0,
  maxIndActivity   : f64 = 1.0,

  // Core solver data
  econ : *ecn.Economy,

  prevResStock : ecnm_d.ResStockData = .{},
  nextResStock : ecnm_d.ResStockData = .{},
  allocatedRes : ecnm_d.ResStockData = .{},

  resFlowData    : ecnm_d.ResFlowData    = .{}, // Aggregated per EconAgent
  popResFlowData : ecnm_d.PopResFlowData = .{}, // Per popType
  indResFlowData : ecnm_d.IndResFlowData = .{}, // Per indType

  popFulfilment : ecnm_d.PopFulfilmentData = .{}, // Per popType
  indActivity   : ecnm_d.IndActivityData   = .{}, // Per indType

  // TODO : generalize these once we add more popTypes
  prevPopCount : f64 = 0.0,
  nextPopCount : f64 = 0.0,

  popDeaths : f64 = 0.0,
  popBirths : f64 = 0.0,


  fn resetValues( self : *EconSolver ) void
  {
    self.defGenResAccess = 1.0;
    self.maxPopResAccess = 1.0;
    self.maxMntResAccess = 1.0;
    self.maxIndResAccess = 1.0;
    self.maxBldResAccess = 1.0;
    self.maxComResAccess = 1.0;
    self.maxPopActivity  = 1.0;
    self.maxIndActivity  = 1.0;

    self.resFlowData.fillWith(    0.0 );
    self.popResFlowData.fillWith( 0.0 );
    self.indResFlowData.fillWith( 0.0 );

    self.popFulfilment.fillWith( 0.0 );
    self.indActivity.fillWith(   0.0 );

    self.prevPopCount = 0.0;
    self.nextPopCount = 0.0;

    self.popDeaths = 0.0;
    self.popBirths = 0.0;
  }


  fn initBaseState( self : *EconSolver, econ : *ecn.Economy ) void
  {
    self.econ = econ;

    self.prevPopCount = self.econ.popState.get( .COUNT, .HUMAN ); // NOTE : only acounts for humans currently
    self.nextPopCount = self.prevPopCount;

    inline for( 0..ResType.count )| r |
    {
      const resType   = ResType.fromIdx( r );
      const econStock = self.econ.resState.get( .COUNT, resType );

      self.prevResStock.set( resType, econStock );
      self.nextResStock.set( resType, econStock );

      self.allocatedRes.set( resType, 0 );
    }
  }


// ================================ PRE-CALC PHASE ================================


  fn calcPopMaxDelta( self : *EconSolver ) void
  {
    inline for( 0..popTypeC )| d |
    {
      const popType  = PopType.fromIdx( d );
      const popCount = self.econ.popState.get( .COUNT, popType );

    //def.log( .INFO, 0, @src(), "$ LOGGING DELTAS FOR {s} :", .{ @tagName( popType )});

      if( popCount > def.EPS ){ inline for ( 0..resTypeC )| r | // Skip absent populations
      {
        const resType = ResType.fromIdx( r );

        const maxCons = popCount * popType.getResMetric_f64( .CONS, resType );
        const maxProd = popCount * popType.getResMetric_f64( .PROD, resType );

      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons });

        // Per-population flow
        self.popResFlowData.set( popType, .MAX_CONS, resType, maxCons );
        self.popResFlowData.set( popType, .MAX_PROD, resType, maxProd );

        // Aggregate into POP flowAgent
        self.resFlowData.add( .POP, .MAX_CONS, resType, maxCons );
        self.resFlowData.add( .POP, .MAX_PROD, resType, maxProd );

        self.resFlowData.add( .GEN, .MAX_CONS, resType, maxCons );
        self.resFlowData.add( .GEN, .MAX_PROD, resType, maxProd );
      }}
    }
  }

  const INF_MAINT_IDLE_FACTOR : f64 = 0.25;
  const IND_MAINT_IDLE_FACTOR : f64 = 0.10;

  fn calcMntMaxDelta( self : *EconSolver ) void
  {
    var totalPartCons : f64 = 0;

    inline for( 0..infTypeC )| f |
    {
      const infType     = InfType.fromIdx( f );
      const infCount    = self.econ.infState.get(   .COUNT,   infType );
      const mntCost     = infType.getResMetric_f64( .MAINT,   .PART   );
      const scaling     = self.econ.infState.get(   .USE_LVL, infType );
      const maintFactor = def.lerp( INF_MAINT_IDLE_FACTOR, 1.0, scaling );

      totalPartCons += infCount * mntCost * maintFactor;
    }
    inline for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );
      const indCount    = self.econ.indState.get(   .COUNT,  indType );
      const mntCost     = indType.getResMetric_f64( .MAINT,  .PART   );
      const scaling     = self.econ.indState.get( .ACT_TRGT, indType );
      const maintFactor = def.lerp( IND_MAINT_IDLE_FACTOR, 1.0, scaling );

      totalPartCons += indCount * mntCost * maintFactor;
    }

    self.resFlowData.add( .MNT, .MAX_CONS, .PART, totalPartCons );
    self.resFlowData.add( .GEN, .MAX_CONS, .PART, totalPartCons );
  }


  const AGRO_ECO_THRESHOLD   : f64 = 0.5; // Eco factor treshold for ecological impacts to begin
  const AGRO_FACTOR_FLOOR    : f64 = 0.2; // Floor of ecological impact on yields
  const AGRO_FACTOR_CONS_MUL : f64 = 1.0; // forces consumption to be X times larger than production, with clampings

  fn calcIndMaxDelta( self : *EconSolver ) void
  {
    const ecoFactor = self.econ.getEcoFactor();
    var  agroFactor = @min( AGRO_ECO_THRESHOLD, ecoFactor ) * ( 1.0 / AGRO_ECO_THRESHOLD );
         agroFactor = @max( agroFactor, AGRO_FACTOR_FLOOR );

    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .COUNT, indType );

    //def.log( .INFO, 0, @src(), "$ LOGGING DELTAS FOR {s} :", .{ @tagName( indType )});

      if( indCount > def.EPS ){ inline for ( 0..resTypeC )| r | // Skip absent industries
      {
        const resType = ResType.fromIdx( r );

        var maxCons = indCount * indType.getResMetric_f64( .CONS, resType );
        var maxProd = indCount * indType.getResMetric_f64( .PROD, resType );

        // Adjust expected max prod based on sunlight
        if( indType.getPowerSrc() == .SOLAR )
        {
          maxCons *= @floatCast( self.econ.sunAccess );
          maxProd *= @floatCast( self.econ.sunAccess );

        //// further adjusting AGRONOMIC yields based on ecoFactor
        //if( indType == .AGRONOMIC )
        //{
        //  maxProd *= @min( agroFactor,                        1.0 );
        //  maxCons *= @min( agroFactor * AGRO_FACTOR_CONS_MUL, 1.0 );
        //}
        }
      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons });

        // Per-industry flow
        self.indResFlowData.set( indType, .MAX_CONS, resType, maxCons );
        self.indResFlowData.set( indType, .MAX_PROD, resType, maxProd );

        // Aggregate into IND flowAgent
        self.resFlowData.add( .IND, .MAX_CONS, resType, maxCons );
        self.resFlowData.add( .IND, .MAX_PROD, resType, maxProd );

        self.resFlowData.add( .GEN, .MAX_CONS, resType, maxCons );
        self.resFlowData.add( .GEN, .MAX_PROD, resType, maxProd );
      }}
    }
  }

  fn calcBldMaxDelta( self : *EconSolver ) void
  {
    if( self.econ.buildDemand > def.EPS )
    {
      self.resFlowData.set( .BLD, .MAX_CONS, .PART, self.econ.buildDemand );
      self.resFlowData.add( .GEN, .MAX_CONS, .PART, self.econ.buildDemand );
    }
  }


  fn calcGenResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING GEN RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const stored = self.prevResStock.get( resType );
      const genDem = self.resFlowData.get( .GEN, .MAX_CONS, resType );

      var access : f64 = self.defGenResAccess;

      if( genDem > def.EPS )
      {
        access = stored / genDem;
      }

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), stored, genDem, access });
      self.resFlowData.set( .GEN, .AVG_ACS, resType, access );
    }
  }

  fn calcPopResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING POP RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const stored = self.prevResStock.get( resType );
      const popDem = self.resFlowData.get( .POP, .MAX_CONS, resType );

      // Calculating unallocated resource count
      const taken  = self.allocatedRes.get( resType );
      const remain = @max( 0.0, stored - taken );
      const popUse = @min( popDem, remain );

      // Updating allocated resource count
      self.allocatedRes.add( resType, popUse );

      // Calculating access
      var access : f64 = self.maxPopResAccess;

      if( popDem > def.EPS )
      {
        access = @min( access, remain / popDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( resType ), remain, popDem, access * 100.0 });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage for population", .{ @tagName( resType )});
        }
      }

      // NOTE : We do not use individualize access yet ( popFlowData )
      self.resFlowData.set( .POP, .AVG_ACS, resType, access );
    }
  }

  // NOTE : Uses PARTs only ( for now )
  fn calcMntResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING MNT RES ACCESS :" );

    const stored = self.prevResStock.get( .PART );
    const mntDem = self.resFlowData.get( .MNT, .MAX_CONS, .PART );

    // Calculating unallocated resource count
    const taken  = self.allocatedRes.get( .PART );
    const remain = @max( 0.0, stored - taken );
    const mntUse = @min( mntDem, remain );

    // Updating allocated resource count
    self.allocatedRes.add( .PART, mntUse );

    // Calculating access
    var access : f64 = self.maxMntResAccess;

    if( mntDem > def.EPS )
    {
      access = @min( access, remain / mntDem );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( .PART ), remain, mntDem, access * 100.0 });

      if( access < 1.0 - def.EPS )
      {
        def.log( .CONT, 0, @src(), "@ {s} shortage for maintenance", .{ @tagName( .PART )});
      }
    }

    self.resFlowData.set( .MNT, .AVG_ACS, .PART, access );
  }

  fn calcIndResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING IND RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const stored = self.prevResStock.get( resType );
      const indDem = self.resFlowData.get( .IND, .MAX_CONS, resType );

      // Calculating unallocated resource count
      const taken  = self.allocatedRes.get( resType );
      const remain = @max( 0.0, stored - taken );
      const indUse = @min( indDem, remain );

      // Updating allocated resource count
      self.allocatedRes.add( resType, indUse );

      // Calculating access
      var access : f64 = self.maxIndResAccess;

      if( indDem > def.EPS )
      {
        access = @min( access, remain / indDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( resType ), remain, indDem, access * 100.0 });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage for industry", .{ @tagName( resType )});
        }
      }

      // NOTE : We do not use individualize access yet ( indFlowData )
      self.resFlowData.set( .IND, .AVG_ACS, resType, access );
    }
  }

  // NOTE : Uses PARTs only ( for now )
  fn calcBldResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING BLD RES ACCESS :" );

    const stored = self.prevResStock.get( .PART );
    const bldDem = self.resFlowData.get( .BLD, .MAX_CONS, .PART );

    // Calculating remaining resources
    const taken  = self.allocatedRes.get( .PART );
    const remain = @max( 0.0, stored - taken );
    const indUse = @min( bldDem, remain );

    // Updating allocated resource use
    self.allocatedRes.add( .PART, indUse );

    // Calculating access
    var access : f64 = self.maxBldResAccess;

    if( bldDem > def.EPS )
    {
      access = @min( access, remain / bldDem );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( .PART ), remain, bldDem, access * 100.0 });

      if( access < 1.0 - def.EPS )
      {
        def.log( .CONT, 0, @src(), "@ {s} shortage for building", .{ @tagName( .PART )});
      }
    }

    self.resFlowData.set( .BLD, .AVG_ACS, .PART, access );
  }


  fn calcPopFulfilment( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "$ LOGGING FINAL POP ACTIVITY :" );

    inline for ( 0..popTypeC )| p |
    {
      const popType  = PopType.fromIdx( p );
      const popCount = self.econ.popState.get( .COUNT, popType );

      var fulfilment : f64 = self.maxPopActivity;

      if( popCount > def.EPS ) // Skip absent population
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          const maxCons = self.popResFlowData.get( popType, .MAX_CONS, resType );

          if( maxCons > def.EPS )
          {
            // NOTE : We do not use individualize access yet ( popFlowData )
            fulfilment = @min( fulfilment, self.resFlowData.get( .POP, .AVG_ACS, resType ));
          }
        }
      }
    //def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}", .{ @tagName( resType ), activity });

      self.popFulfilment.set( popType, fulfilment ); // NOTE : Only scales pop prod, not cons
    }
  }

  fn calcIndActivity( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "$ LOGGING FINAL IND ACTIVITY :" );

    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .COUNT, indType );

      var activity : f64 = self.maxIndActivity;

      // Basing new activity on previous tick's activity target AND current tick res access caps
      activity = @min( activity, self.econ.indState.get( .ACT_TRGT, indType ));

      if( indCount > def.EPS ) // Skip absent industries
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          const maxCons = self.indResFlowData.get( indType, .MAX_CONS, resType );

          if( maxCons > def.EPS )
          {
            // NOTE : We do not use individualize access yet ( popFlowData )
            activity = @min( activity, self.resFlowData.get( .IND, .AVG_ACS, resType ));
          }
        }
      }
    //def.log( .CONT, 0, @src(), "{s}\t: {d:.6}", .{ @tagName( indType ), activity });

      self.indActivity.set( indType, activity );
    }
  }


// ================================ CONSUMPTION PHASE ================================


  fn calcPopResCons( self : *EconSolver ) void
  {
    // NOTE : Pop consumption uses per-res POP access, not per-pop fulfilment rate
    inline for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      inline for( 0..resTypeC )| r |
      {
        const resType     = ResType.fromIdx( r );
        const popAccess   = self.resFlowData.get( .POP, .AVG_ACS, resType );
        const realPopCons = popAccess * self.popResFlowData.get( popType, .MAX_CONS, resType );

        self.popResFlowData.set( popType, .FIN_CONS, resType, realPopCons );
        self.resFlowData.add( .POP,    .FIN_CONS, resType, realPopCons );
        self.resFlowData.add( .GEN,    .FIN_CONS, resType, realPopCons );
      }
    }
  }

  // NOTE : Uses PARTs only ( for now )
  fn calcMntResCons( self : *EconSolver ) void
  {
    const mntAccess  = self.resFlowData.get( .MNT, .AVG_ACS,   .PART );
    const mntMaxCons = self.resFlowData.get( .MNT, .MAX_CONS, .PART );

    if( mntMaxCons > def.EPS )
    {
      const realMntCons = mntAccess * mntMaxCons;

      self.resFlowData.set( .MNT, .FIN_CONS, .PART, realMntCons );
      self.resFlowData.add( .GEN, .FIN_CONS, .PART, realMntCons );
    }

    // TODO : do something when maintenanced is not fuly paid
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
          const realIndCons = indActivity * self.indResFlowData.get( indType, .MAX_CONS, resType );

          self.indResFlowData.set( indType, .FIN_CONS, resType, realIndCons );
          self.resFlowData.add( .IND,    .FIN_CONS, resType, realIndCons );
          self.resFlowData.add( .GEN,    .FIN_CONS, resType, realIndCons );
        }
      }
    }
  }

  // NOTE : Uses PARTs only ( for now )
  fn calcBldResCons( self : *EconSolver ) void
  {
    const bldAccess  = self.resFlowData.get( .BLD, .AVG_ACS,   .PART );
    const bldMaxCons = self.resFlowData.get( .BLD, .MAX_CONS, .PART );

    if( bldMaxCons > def.EPS )
    {
      const realBldCons = @floor( bldAccess * bldMaxCons );

      self.resFlowData.set( .BLD, .FIN_CONS, .PART, realBldCons );
      self.resFlowData.add( .GEN, .FIN_CONS, .PART, realBldCons );
    }
  }


  fn applyGenResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genCons = self.resFlowData.get( .GEN, .FIN_CONS, resType );

      self.nextResStock.sub( resType, genCons );
    }
  }

  /// Independent from GEN cons
  fn applyNatResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx( r );
      const resCount = self.nextResStock.get( resType );

      // Decay applies to what remains AFTER general consumption
      if( resCount > def.EPS )
      {
        const realNatCons = @ceil( resCount * resType.getMetric_f64( .DECAY_RATE ));

        self.resFlowData.set( .NAT, .FIN_CONS, resType, realNatCons );
        self.nextResStock.sub(                  resType, realNatCons );
      }
    }
  }


// ================================ PRODUCTION PHASE ================================

  const POP_PROD_FLOOR : f64 = 0.2;

  fn calcPopResProd( self : *EconSolver ) void
  {
    inline for( 0..popTypeC )| p |
    {
      const popType       = PopType.fromIdx( p );
      const popFulfilment = self.popFulfilment.get( popType );

      inline for( 0..resTypeC )| r |
      {
        const resType     = ResType.fromIdx( r );
        const prodRate    = @max( popFulfilment, POP_PROD_FLOOR );
        const realPopProd = prodRate * self.resFlowData.get( .POP, .MAX_PROD, resType );

        self.popResFlowData.set( popType, .FIN_PROD, resType, realPopProd );
        self.resFlowData.add( .POP,    .FIN_PROD, resType, realPopProd );
        self.resFlowData.add( .GEN,    .FIN_PROD, resType, realPopProd );
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
          const realIndProd = indActivity * self.indResFlowData.get( indType, .MAX_PROD, resType );

          self.indResFlowData.set( indType, .FIN_PROD, resType, realIndProd );
          self.resFlowData.add( .IND,    .FIN_PROD, resType, realIndProd );
          self.resFlowData.add( .GEN,    .FIN_PROD, resType, realIndProd );
        }
      }
    }
  }

  fn calcBldResProd( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT SELLOFFS OF UNPROFITABLE BUILDINGS FOR PARTS
  }

  fn applyGenResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genProd = self.resFlowData.get( .GEN, .FIN_PROD, resType );

      self.nextResStock.add( resType, genProd );
    }
  }

  /// Independent from GEN prod
//fn applyNatResProd( self : *EconSolver ) void // NOTE : DEPRECATED due to disutility
//{
//  const ecoFactor = self.econ.getEcoFactor();
//
//  inline for( 0..resTypeC )| r |
//  {
//    const resType    = ResType.fromIdx( r );
//    const growthRate = resType.getMetric_f64( .GROWTH_RATE );
//
//    if( growthRate >= def.EPS )
//    {
//      const realNatProd = @floor( ecoFactor * growthRate );
//
//      self.resFlowData.set( .NAT, .FIN_PROD, resType, realNatProd );
//      self.nextResStock.add(                  resType, realNatProd );
//    }
//  }
//}


// ================================ FINANCES PHASE ================================


  fn clampResStocks( self : *EconSolver ) void      // TODO : save the wasted amounts as metrics
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const resL  = self.econ.resState.get( .LIMIT, resType );
      const current = self.nextResStock.get( resType );

      if( current > resL )
      {
        // Clamp stock but do NOT adjust production metrics
        // Industries consumed real inputs and produced real outputs - the overflow
        // is a storage problem, not a production problem
        // Prices will naturally suppress overproduction via supply > demand
        self.nextResStock.set( resType, resL );

        def.log( .WARN, 0, @src(), "{s} stock overflow : {d:.0} clamped to {d:.0} ( {d:.0} wasted )", .{ @tagName( resType ), current, resL, current - resL });
      }
    }
  }

//fn updateBldFinances( self : *EconSolver ) void
//fn updateComFinances( self : *EconSolver ) void
//fn updateGovFinances( self : *EconSolver ) void

  const MAX_SCARC_RATIO  : f64 = 100.0;
  const MIN_PRICE_FACTOR : f64 = 0.010;

  fn updateResPrices( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING RES PRICES :" );

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const basePrice  = resType.getMetric_f64( .PRICE_BASE );
      const elasticity = resType.getMetric_f64( .PRICE_ELAS );
      const dampening  = resType.getMetric_f64( .PRICE_DAMP ); // Lerp factor (0 = no change, 1 = instant)

      // Flow-based: compare this tick's production vs this tick's consumption demand
      const realDemand = self.resFlowData.get( .GEN, .FIN_CONS, resType ); // NOTE : EXCLUDES NATURAL DECAY
      const realSupply = self.resFlowData.get( .GEN, .FIN_PROD, resType )
                       + self.resFlowData.get( .NAT, .FIN_PROD, resType );

      const ceil : f64 = MAX_SCARC_RATIO; // Scarcity ceiling
      var  ratio : f64 = 0.0;

      if(      realSupply > def.EPS ){ ratio = @min( ceil, realDemand / realSupply ); }
      else if( realDemand > def.EPS ){ ratio = ceil; }

      const rawPrice = basePrice * @max( MIN_PRICE_FACTOR, def.pow( f64, ratio, elasticity ));
      const oldPrice = self.econ.resState.get( .PRICE, resType );
      const newPrice = def.lerp(  oldPrice, rawPrice, dampening ); // Lerp dampening
      const dltPrice = newPrice - oldPrice;
      const dltPrcnt = 100.0 * dltPrice / oldPrice;
      const offPrcnt = 100.0 * newPrice / basePrice;

      const resCount = self.nextResStock.get( resType );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0} \t| {d:.6}\t| {d:.6}\t{d:.6}\t| {d:.1}%  \tx {d:.1}%", .{ @tagName( resType ), resCount, basePrice, oldPrice, newPrice, dltPrcnt, offPrcnt });

      self.econ.resState.set( .PRICE,   resType, newPrice );
      self.econ.resState.set( .PRICE_D, resType, dltPrice );
    }
  }

  const POP_MARGIN_FLOOR : f64 = -2.5;

  fn updatePopFinances( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING POP FINANCES :" );

    const econ = self.econ;
    inline for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );
      var  popCount = econ.popState.get( .COUNT, popType );

      const isPresent : bool = ( popCount > def.EPS );
      if( !isPresent ){ popCount = 1.0; }

      if( popCount > def.EPS )
      {
        var expense : f64 = 0.0;
        var revenue : f64 = 0.0;
        var profit  : f64 = 0.0;

        // Calculating revenues and expenses
        inline for( 0..resTypeC )| r |
        {
          const resType  = ResType.fromIdx( r );
          const resPrice = econ.resState.get( .PRICE, resType );

          if( isPresent )
          {
            expense += resPrice * self.popResFlowData.get( popType, .FIN_CONS, resType );
            revenue += resPrice * self.popResFlowData.get( popType, .FIN_PROD, resType );
          }
          else // Theoritical profitability calculations
          {
            expense += resPrice * popType.getResMetric_f64( .CONS, resType );
            revenue += resPrice * popType.getResMetric_f64( .PROD, resType );
          }
        }
        profit = revenue - expense;

        // TODO : add housing costs

        // Calculating margin
        const floor : f64 = POP_MARGIN_FLOOR;
        var  margin : f64 = 0.0;

        if(      revenue > def.EPS ){ margin = @max( floor, profit / revenue ); }
        else if( expense > def.EPS ){ margin =       floor; }


        // Updating econ metrics
        const prevSavings = econ.popState.get( .SAVINGS, popType );

        if( isPresent )
        {
          const nextSavings = prevSavings + profit;

          // NOTE : Expenses and revenues are logged per unit for ease of comparison, but stored as totals
          def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t| {d:.1}\t| +{d:.4}\t-{d:.4}\t| {d:.4}", .{ @tagName( popType ), popCount, nextSavings, revenue / popCount, expense / popCount, margin });

          econ.popState.set( .EXPENSE,  popType, expense     );
          econ.popState.set( .REVENUE,  popType, revenue     );
          econ.popState.set( .SAVINGS,  popType, nextSavings );
        }
        else
        {
          def.log( .CONT, 0, @src(), "{s}\t: 0\t| {d:.1}\t| +N/A\t-N/A\t| {d:.4}", .{ @tagName( popType ), prevSavings, margin});

          econ.popState.zero( .EXPENSE,  popType );
          econ.popState.zero( .REVENUE,  popType );

          // TODO : transfer savings to gov if non-zero ( population died off )
        }
      }
    }
  }


  // Minimum industry activity - prevents permanent shutdown death spiral
  // Industries always "test" the market at this rate
  const IND_MIN_ACT_TRGT  : f64 = 0.05;
  const IND_MARGIN_FLOOR  : f64 = -2.5;
  const IND_MARGIN_OFFSET : f64 = -0.0;

  fn updateIndFinances( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING IND FINANCES :" );

    const econ = self.econ;
    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );
      var  indCount = econ.indState.get( .COUNT, indType );

      const isPresent : bool = ( indCount > def.EPS );
      if( !isPresent ){ indCount = 1.0; }

      if( indType.canBeBuiltIn( econ.location, econ.hasAtmo ))
      {
        var expense : f64 = 0.0;
        var revenue : f64 = 0.0;
        var profit  : f64 = 0.0;

        // Calculating revenues and expenses
        inline for( 0..resTypeC )| r |
        {
          const resType  = ResType.fromIdx( r );
          const resPrice = econ.resState.get( .PRICE, resType );

          if( isPresent )
          {
            expense += resPrice * self.indResFlowData.get( indType, .FIN_CONS, resType );
            revenue += resPrice * self.indResFlowData.get( indType, .FIN_PROD, resType );
          }
          else // Theoritical profitability calculations
          {
            expense += resPrice * indType.getResMetric_f64( .CONS, resType );
            revenue += resPrice * indType.getResMetric_f64( .PROD, resType );
          }
        }


        // Calculating maintenance costs
        // NOTE : duplicated code ( calcMntMaxDelta ). buffer previous results instead
        const partPrice   = self.econ.resState.get(   .PRICE, .PART );
        const mntCost     = indType.getResMetric_f64( .MAINT, .PART );
        const scaling     = self.indActivity.get( indType );
        const maintFactor = def.lerp( IND_MAINT_IDLE_FACTOR, 1.0, scaling );

        expense += indCount * mntCost * partPrice * maintFactor;
        profit   = revenue  - expense;


        // Calculating margin and activity target
        const floor : f64 = IND_MARGIN_FLOOR;
        var  margin : f64 = 0.0;

        if(      revenue > def.EPS ){ margin = @max( floor, profit / revenue ); }
        else if( expense > def.EPS ){ margin =       floor; }

        // Large profits will push target towards 1.0, large losses will push it towards 0.0
        var activityTarget = self.maxIndActivity * def.sigmoid( margin + IND_MARGIN_OFFSET, 8.0 ); // NOTE : lower K for smoother transitioning
            activityTarget = def.clmp( activityTarget, IND_MIN_ACT_TRGT, 1.00 );

        econ.indState.set( .ACT_TRGT, indType, activityTarget ); // To be used next tick

        // Updating econ metrics
        const prevCapital = econ.indState.get( .SAVINGS, indType );

        if( isPresent )
        {
          const nextCapital = prevCapital + profit;

          // NOTE : Expenses and revenues are logged per unit for ease of comparison, but stored as totals
          def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t| {d:.1}\t| +{d:.4}\t-{d:.4}\t| {d:.4}\t{d:.4}%", .{ @tagName( indType ), indCount, nextCapital, revenue / indCount, expense / indCount, margin, activityTarget * 100.0 });

          econ.indState.set( .EXPENSE,  indType, expense     );
          econ.indState.set( .REVENUE,  indType, revenue     );
          econ.indState.set( .SAVINGS,  indType, nextCapital );
        }
        else
        {
          def.log( .CONT, 0, @src(), "{s}\t: 0\t| {d:.1}\t| +N/A\t-N/A\t| {d:.4}\t{d:.4}%", .{ @tagName( indType ), prevCapital, margin, activityTarget * 100.0 });

          econ.indState.zero( .EXPENSE,  indType );
          econ.indState.zero( .REVENUE,  indType );

          // TODO : transfer capital to gov if non-zero ( industry went insolvent )
        }
      }
      else
      {
        econ.indState.zero( .ACT_TRGT, indType );
        econ.indState.zero( .EXPENSE,  indType );
        econ.indState.zero( .REVENUE,  indType );
        econ.indState.zero( .SAVINGS,  indType );
      }
    }
  }



// ================================ POST-CALC PHASE ================================

// Pop growth / decay factors
  const RES_MODIFIER_EXPONENT : f64 = def.PHI; // Smooth out death rates from pop res shortages
  const JOB_MODIFIER_EXPONENT : f64 = def.PHI; // Smooth out growth suppression from pop job shortages

  const MAX_RES_MODIFIER : f64 = 1.2;
  const MAX_JOB_MODIFIER : f64 = 1.2;


  fn updatePopCount( self : *EconSolver ) void
  {
    const jobAccess : f64 = @max( def.EPS, self.resFlowData.get( .GEN, .AVG_ACS, .WORK ));

    var avgPopStarveRate : f64 = 0.0;
    var avgPopDeathRate  : f64 = 0.0;
    var avgPopBirthRate  : f64 = 0.0;

    inline for( 0..popTypeC )| p |
    {
      const popType  = PopType.fromIdx( p );
      const popCount = self.econ.popState.get( .COUNT, popType );

      if( popCount > def.EPS )
      {
        def.log( .INFO, 0, @src(), "$ LOGGING POP FACTORS ({s}) :", .{ @tagName( popType )});

        const baseFatality = popType.getMetric_f64( .FATALITY );
        const baseNatality = popType.getMetric_f64( .NATALITY );


        // ================ MORTALITY ================
        // Base fatality ( natural causes ) + starvation mortality

        var maxStarveRate : f64 = 0.0;
        var minResAccess  : f64 = 1.0;

        def.qlog( .CONT, 0, @src(), "Access rates  : " );

        for( 0..resTypeC )| r |
        {
          const resType  = ResType.fromIdx( r );
          const mortRate = popType.getResMetric_f64( .MORT, resType );

          if( mortRate > def.EPS )
          {
            const access = self.resFlowData.get( .POP, .AVG_ACS, resType );
            minResAccess = @min( minResAccess, access );

            def.log( .CONT, 0, @src(), "- {s}\t : {d:.4}", .{ @tagName( resType ), access });

            if( access < 1.0 )
            {
              def.log( .CONT, 0, @src(), "@ {s} pops are experiencing {s} shortages !", .{ @tagName( popType ), @tagName( resType ) });

              maxStarveRate = @max( maxStarveRate, mortRate * def.pow( f64, 1.0 - access, RES_MODIFIER_EXPONENT ));
            }
          }
        }
        const starved = @floor( popCount * maxStarveRate );

        avgPopStarveRate += maxStarveRate;

        def.log( .CONT, 0, @src(), "Starve Rate  : {d:.6}", .{ maxStarveRate });


        const deathRate = baseFatality + maxStarveRate;
        const deaths    = @floor( popCount * deathRate );

        avgPopDeathRate += deathRate;

        def.log( .CONT, 0, @src(), "Death Rate   : {d:.6}", .{ deathRate });


        // ================ NATALITY ================
        // Growth only occurs in the fraction of the population that has full resource access
        // Modified by resource abundance and job availability

        const resModifier = @min( def.pow( f64,    minResAccess, 1.0 / RES_MODIFIER_EXPONENT ), MAX_RES_MODIFIER );
        const jobModifier = @min( def.pow( f64, 1.0 / jobAccess, 1.0 / JOB_MODIFIER_EXPONENT ), MAX_JOB_MODIFIER );

        const birthRate   = baseNatality * resModifier * jobModifier;
        const birtherRate = 1.0 - deathRate;
        const births      = @ceil( popCount * birtherRate * birthRate );

        avgPopBirthRate += birthRate;

        def.log( .CONT, 0, @src(), "Birth Rate   : {d:.6}", .{ birthRate });
        def.log( .CONT, 0, @src(), "Res Modifier : {d:.8}", .{ resModifier });
        def.log( .CONT, 0, @src(), "Job Modifier : {d:.8}", .{ jobModifier });


        // ================ POP DELTA ================

        const popCap : f64 = @floatFromInt( self.econ.getPopCap( popType ));

        const nextPop = def.clmp( popCount + births - deaths, 0.0, popCap );

        def.log( .CONT, 0, @src(), "New Pop count : {d:.0}", .{ nextPop });


        // Push pop metrics to econ
        self.econ.popState.set( .COUNT,  popType, nextPop );
        self.econ.popState.set( .STARVE, popType, starved );
        self.econ.popState.set( .DEATH,  popType, deaths  );
        self.econ.popState.set( .BIRTH,  popType, births  );
      }
    }

    // TODO : Store these averages in econ
    avgPopStarveRate /= @floatFromInt( popTypeC );
    avgPopDeathRate  /= @floatFromInt( popTypeC );
    avgPopBirthRate  /= @floatFromInt( popTypeC );
  }

//fn applyIndDelta( self : *EconSolver ) void
// TODO : calc target industrial growth / decay based on profitability
// NOTE : remove capital from industry from growth costs
// NOTE : inject capital into industry from decay selloffs


  fn pushEconMetrics( self : *EconSolver ) void
  {
    const econ : *ecn.Economy = self.econ;

    self.econ.buildBudget = self.resFlowData.get( .BLD, .FIN_CONS, .PART );


  // ================ AGENT AVERAGE ACCESS RATE ================

    var avgGenResAccess  : f64 = 0.0;
    var avgPopResAccess  : f64 = 0.0;
  //var avgInfResAccess  : f64 = 0.0;
    var avgIndResAccess  : f64 = 0.0;


    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const initialStk = self.prevResStock.get( resType );
      const finalStk   = self.nextResStock.get( resType );
      const initialAcs = self.econ.resState.get( .ACCESS, resType );
      const finalAcs   = self.resFlowData.get( .GEN, .AVG_ACS, resType );

      econ.resState.set( .COUNT,    resType, @max( 0.0, finalStk  ));
      econ.resState.set( .COUNT_D,  resType, finalStk - initialStk );
      econ.resState.set( .ACCESS,   resType, @max( 0.0, finalAcs  ));
      econ.resState.set( .ACCESS_D, resType, finalAcs - initialAcs );

      avgGenResAccess += self.resFlowData.get( .GEN, .AVG_ACS, resType );
      avgPopResAccess += self.resFlowData.get( .POP, .AVG_ACS, resType );
    //avgInfResAccess += self.resFlowData.get( .INF, .AVG_ACS, res );
      avgIndResAccess += self.resFlowData.get( .IND, .AVG_ACS, resType );
    }


    avgGenResAccess  /= @floatFromInt( resTypeC );
    avgPopResAccess  /= @floatFromInt( popTypeC );
  //avgInfResAccess  /= @floatFromInt( infTypeC );
    avgIndResAccess  /= @floatFromInt( indTypeC );

    econ.agtState.set( .GEN, .AVG_ACS, avgGenResAccess  );
    econ.agtState.set( .POP, .AVG_ACS, avgPopResAccess  );
  //econ.agtState.set( .INF, .AVG_ACS, avgInfResAccess  );
    econ.agtState.set( .IND, .AVG_ACS, avgIndResAccess  );


  // ================ AGENT AVERAGE "ACTION" RATE ================

    var avgPopFulfilment : f64 = 0.0;
  //var avgInfUsage      : f64 = 0.0;
    var avgIndActivity   : f64 = 0.0;


    inline for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      const popFulfilment = self.popFulfilment.get( popType );

      econ.popState.set( .FLM_LVL, popType, popFulfilment );

      avgPopFulfilment += popFulfilment;
    }
  //inline for( 0..infTypeC )| f | // NOTE : done in econ.updateInfUsage()
  //{
  //  const infType = InfType.fromIdx( f );
  //
  //  avgInfUsage += PLACEHOLDER;
  //}
    inline for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );
      const indActivity = self.indActivity.get( indType );

      econ.indState.set( .ACT_LVL, indType, indActivity );

      avgIndActivity += indActivity;
    }


    avgPopFulfilment /= @floatFromInt( popTypeC );
  //avgInfUsage      /= @floatFromInt( infTypeC );
    avgIndActivity   /= @floatFromInt( indTypeC );

    econ.agtState.set( .POP, .AVG_ACT, avgPopFulfilment );
  //econ.agtState.set( .INF, .AVG_ACT, avgInfUsage      );
    econ.agtState.set( .IND, .AVG_ACT, avgIndActivity   );
  }


  // ================================ DEBUG LOGGING ================================

  pub inline fn logAllMetrics( self : *const EconSolver ) void
  {
  //self.logResMetrics();
  //self.logIndMetrics();
    self.logInfMetrics();
  //self.logPopMetrics();
  }
  pub fn logPopMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ POPULATION : Count ( Capacity )  [ Delta | Births Deaths ]  Fulfilment rate" );
    def.qlog( .CONT, 0, @src(), "=============================================================================" );

  //inline for( 0..popTypeC )| p |
  //{
  //  const popType  = PopType.fromIdx( p );
      const popType  = PopType.HUMAN;

      const count  : f64 = self.nextPopCount;
      const limit  : f64 = self.econ.popState.get( .LIMIT, popType );

      const births : f64 = self.popBirths;
      const deaths : f64 = self.popDeaths;
      const delta  : f64 = births - deaths;

      const flmLvl : f64 = self.popFulfilment.get( popType ) * 100;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t/ {d:.0}\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t] {d:.3}%",
        .{ @tagName( popType ), count, limit, delta, births, deaths, flmLvl });
  //}
  }

  pub inline fn logResMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ RESOURCE : Count / Capacity   [ Delta | Prod Cons Decay ]   Access rate   ( Price )" );
    def.qlog( .CONT, 0, @src(), "=====================================================================================" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const count  : f64 = self.econ.resState.get( .COUNT, resType );
      const limit  : f64 = self.econ.resState.get( .LIMIT, resType );
      const price  : f64 = self.econ.resState.get( .PRICE, resType );

      const prod   : f64 = self.resFlowData.get( .GEN, .FIN_PROD, resType );
      const cons   : f64 = self.resFlowData.get( .GEN, .FIN_CONS, resType );
      const decay  : f64 = self.resFlowData.get( .NAT, .FIN_CONS, resType );
      const delta  : f64 = prod - cons;

      const avgAcs : f64 = self.resFlowData.get( .GEN, .AVG_ACS,  resType ) * 100.0;

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t/ {d:.0}\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t-{d:.0}\t] {d:.2}%\t ( {d:.6} )",
        .{ @tagName( resType ), count, limit, delta, prod, cons, decay, avgAcs, price });
    }
  }

  pub inline fn logInfMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ INFRASTRUCTURE : Count ( Bonus )   [ Delta ]   Usage rate" );
    def.qlog( .CONT, 0, @src(), "===========================================================" );

    inline for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      const count  : f64 = self.econ.infState.get( .COUNT,   infType );

      const built  : f64 = self.econ.infState.get( .BUILT,   infType );
      const destr  : f64 = self.econ.infState.get( .DESTR,   infType );
      const delta  : f64 = built - destr;

      const bonus  : f64 = count * infType.getMetric_f64( .CAPACITY );
      const useLvl : f64 = self.econ.infState.get( .USE_LVL, infType ) * 100.0;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t( +{d:.0}\t) [ {d:.0}\t] {d:.2}%",
        .{ @tagName( infType ), count, bonus, delta, useLvl });
    }
  }

  pub inline fn logIndMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ INDUSTRY : Count   [ Delta ]   Activity rate / Target rate" );
    def.qlog( .CONT, 0, @src(), "============================================================" );
    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );

      const count : f64 = self.econ.indState.get( .COUNT, indType );

      const built : f64 = self.econ.indState.get( .BUILT, indType );
      const destr : f64 = self.econ.indState.get( .DESTR, indType );
      const delta : f64 = built - destr;

      const actLvl    : f64 = self.econ.indState.get( .ACT_LVL,  indType ) * 100;
      const actTarget : f64 = self.econ.indState.get( .ACT_TRGT, indType ) * 100;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0} \t[ {d:.0}\t] {d:.2}%\t/ {d:.2}%",
        .{ @tagName( indType ), count, delta, actLvl, actTarget });
    }
  }
};


// ================================ TEST-LOGGER ================================

pub fn testEconLogs( econ : *ecn.Economy ) void
{
  // NOTE : Uses non-global solver-instance to avoid corrupting the actual solver
  var tmpSolver : EconSolver = .{ .econ = undefined };

  tmpSolver.initBaseState( econ );

  tmpSolver.calcPopMaxDelta();
  tmpSolver.calcMntMaxDelta();
  tmpSolver.calcIndMaxDelta();
  tmpSolver.calcBldMaxDelta();


  def.qlog( .INFO, 0, @src(), "$ TESTING ECON PROFITABILITY :" );

  def.qlog( .INFO, 0, @src(), "# RES DELTA :" );

  inline for( 0..resTypeC )| r |
  {
    const resType   = ResType.fromIdx( r );

    const cons  = tmpSolver.resFlowData.get( .GEN, .MAX_CONS, resType );
    const prod  = tmpSolver.resFlowData.get( .GEN, .MAX_PROD, resType );
    const delta = prod - cons;

    var ratio : f64 = 0.0;
    if( prod > def.EPS ){ ratio = delta / prod; }

    def.log( .CONT, 0, @src(), "{s}  \t| +{d:.0}\t-{d:.0}\t= {d:.0}\t( {d:.2}% )", .{ @tagName( resType ), prod, cons, delta, ratio * 100.0 });
  }

  def.qlog( .INFO, 0, @src(), "# POP PROFITABILITY :" );

  inline for( 0..popTypeC )| p |
  {
    const popType  = PopType.fromIdx( p );
    const popCount = econ.popState.get( .COUNT, popType );

    var expense : f64 = 0.0;
    var revenue : f64 = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx( r );
      const resPrice = econ.resState.get( .PRICE, resType );

      expense += resPrice * tmpSolver.popResFlowData.get( popType, .MAX_CONS, resType );
      revenue += resPrice * tmpSolver.popResFlowData.get( popType, .MAX_PROD, resType );
    }

    const profit = revenue - expense;

    var margin : f64 = 0.0;
    if( revenue > def.EPS ){ margin = profit / revenue; }

    def.log( .CONT, 0, @src(), "{s}\t : {d:.0}\t| +{d:.0}\t-{d:.0}\t= {d:.0}\t( {d:.2}% )", .{ @tagName( popType ), popCount, revenue, expense, profit, margin * 100.0 });
  }

  def.qlog( .INFO, 0, @src(), "# IND PROFITABILITY :" );

  inline for( 0..indTypeC )| d |
  {
    const indType  = IndType.fromIdx( d );
    const indCount = econ.indState.get( .COUNT, indType );

    var expense : f64 = 0.0;
    var revenue : f64 = 0.0;

    inline for ( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx(r);
      const resPrice = econ.resState.get(.PRICE, resType);

      expense += resPrice * tmpSolver.indResFlowData.get( indType, .MAX_CONS, resType );
      revenue += resPrice * tmpSolver.indResFlowData.get( indType, .MAX_PROD, resType );
    }

    // Add maintenance cost
    const partPrice = econ.resState.get(        .PRICE, .PART );
    const mntCost   = indType.getResMetric_f64( .MAINT, .PART );
    const mntCosts  = indCount * mntCost * partPrice;

    const profit = revenue - ( expense + mntCosts );

    var margin : f64 = 0.0;
    if( revenue > def.EPS ){ margin = profit / revenue; }

    def.log( .CONT, 0, @src(), "{s}\t : {d:.0}\t| +{d:.0}\t-{d:.0}\t-{d:.0}\t= {d:.0}\t( {d:.2}% )", .{ @tagName( indType ), indCount, revenue, expense, mntCosts, profit, margin * 100.0 });
  }

//tmpSolver.logAllMetrics();
}


