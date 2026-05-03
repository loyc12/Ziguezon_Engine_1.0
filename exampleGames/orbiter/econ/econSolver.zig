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
// NOTE : Ensure the reset is total between each call of stepEcon()
var solver : EconSolver = .{ .econ = undefined };


pub inline fn stepEcon( econ : *ecn.Economy ) *const EconSolver
{
  solver.resetValues();         // Zeroes out non-initializable data
  solver.initBaseState( econ ); // Initializes data from econ


// ================ MAX RES FLOW PHASE ================

  solver.calcPopMaxFlow(); // Computes the maximal population prod and cons
//solver.calcInfMaxFlow(); // Computes the maximal infrastr.  prod and cons
  solver.calcIndMaxFlow(); // Computes the maximal industrial prod and cons
//solver.calcComMaxFlow(); // Computes the maximal commercial imp. and exp.


  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  solver.calcMntMaxFlow(); // Computes the maximal maintenance  consumption
  solver.calcBldMaxFlow(); // Computes the maximal construction prod and cons


// ================ RES ACCESS PHASE ================

  // TODO : Have these call a singular, generic "calcResAccess" instead (?)
  solver.calcGenResAccess(); // Computes the expected aggregated resource access
  solver.calcPopResAccess(); // Computes the expected population resource access
//solver.calcInfResAccess(); // Computes the expected infrastr.  resource access
  solver.calcIndResAccess(); // Computes the expected industrial resource access
//solver.calcComResAccess(); // Computes the expected commercial resource access

  // TODO : Fold into POP/INF/IND, and generalise to account for all resType
  solver.calcMntResAccess(); // Computes the expected maintenance  resource access
  solver.calcBldResAccess(); // Computes the expected construction resource access


// ================ ACTION RATES PHASE ================

  solver.updatePopFulfilment(); // Computes the final population fulfilment ratio
//solver.updateInfUsage();      // Computes the final infrastructure usage  ratio
  solver.updateIndActivity();   // Computes the final industrial activity   ratio
//solver.updateComActivity();   // Computes the final commercial activity   ratio (?)


// ================ CONSUMPTION PHASE ================

  // NOTE : Have these call a singular, generic "calcResCons" instead (?)
  solver.calcPopResCons();  // Computes resource cons from population based on popCount
  solver.calcInfResCons();  // Computes resource cons from infrastructure based on usage
  solver.calcIndResCons();  // Computes resource cons from industry based on activity
//solver.calcComResCons();  // Computes resource cons from exports

  solver.applyGenResCons(); // Applies all resource consumption to the economy
  solver.applyResDecay();   // Decays unsued resources leftover based on individual rates ( 100% for WORK )


// ================ PRODUCTION PHASE ================

  // NOTE : Have these call a singular, generic "calcResProd" instead (?)
  solver.calcPopResProd();  // Computes resource prod from population based on popCount
  // Inf does not produce resources
  solver.calcIndResProd();  // Computes resource prod from industry based on activity
//solver.calcComResProd();  // Computes resource prod from imports

  solver.applyGenResProd(); // Applies all resource production to the economy


// ================ FINANCES PHASE ================

  solver.clampResStocks();  // Clamps resource amounts to what their respective stores can handle
  solver.updateResPrices(); // Update res prices from final supply and demand

  solver.updatePopFinances(); // Update monetary metrics for each population type
  solver.updateInfFinances(); // Update monetary metrics for each infrastructure type // TODO : IMPLEMENT ME
  solver.updateIndFinances(); // Update monetary metrics for each industry type
//solver.updateComFinances();
//solver.updateGovFinances();


// ================ GROWTH & DECAY PHASE ================

  solver.updatePopCount();  // Computes population delta based on access
//solver.updateInfCount();  // Computes infrastructure growth/decay based on profitability
//solver.updateIndCount();  // Computes industrial growth/decay based on profitability


// ================ ECON UPDATE PHASE ================

  solver.pushResMetrics();
  solver.pushAgentMetrics();

  return &solver;
}


// ================================ SOLVER STRUCT ================================


pub const EconSolver = struct
{
  // Global consumption-production throttles / multipliers ( generally static )
  defGenResAccess : f64 = 1.0,
  maxPopResAccess : f64 = 1.0,
  maxIndResAccess : f64 = 1.0,
  maxMntResAccess : f64 = 1.0,
  maxBldResAccess : f64 = 1.0,
  maxComResAccess : f64 = 1.0,

  maxPopActivity  : f64 = 1.0,
  maxIndActivity  : f64 = 1.0,

  // Core solver data
  econ : *ecn.Economy,

  // Stock snapshots
  prevResStock : ecnm_d.ResStockData = .{},
  nextResStock : ecnm_d.ResStockData = .{},
  allocatedRes : ecnm_d.ResStockData = .{}, // TODO : use me

  genResFlowData : ecnm_d.GenResFlowData = .{}, // Aggregated sum of all changes
  grpResFlowData : ecnm_d.GrpResFlowData = .{}, // Aggregated per AgentGroup
  popResFlowData : ecnm_d.PopResFlowData = .{}, // Split per PopType
  infResFlowData : ecnm_d.InfResFlowData = .{}, // Split per InfType
  indResFlowData : ecnm_d.IndResFlowData = .{}, // Split per IndType


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

    self.genResFlowData.fillWith( 0.0 );
    self.grpResFlowData.fillWith( 0.0 );
    self.popResFlowData.fillWith( 0.0 );
    self.infResFlowData.fillWith( 0.0 );
    self.indResFlowData.fillWith( 0.0 );
  }


  fn initBaseState( self : *EconSolver, econ : *ecn.Economy ) void
  {
    self.econ = econ;

    inline for( 0..ResType.count )| r |
    {
      const resType   = ResType.fromIdx( r );
      const econStock = self.econ.resState.get( .COUNT, resType );

      self.prevResStock.set( resType, econStock );
      self.nextResStock.set( resType, econStock );

      self.allocatedRes.set( resType, 0 );
    }
  }


// ================================ MAX RES FLOW PHASE ================================


  fn calcPopMaxFlow( self : *EconSolver ) void
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

        self.popResFlowData.set( popType, .OPR_CONS, resType, maxCons );
        self.popResFlowData.set( popType, .OPR_PROD, resType, maxProd );

        self.grpResFlowData.add( .POP,    .OPR_CONS, resType, maxCons );
        self.grpResFlowData.add( .POP,    .OPR_PROD, resType, maxProd );

        self.genResFlowData.add(          .OPR_CONS, resType, maxCons );
        self.genResFlowData.add(          .OPR_PROD, resType, maxProd );
      }}
    }
  }


  fn calcInfMaxFlow( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }


  const AGRO_ECO_THRESHOLD   : f64 = 0.5; // Eco factor treshold for ecological impacts to begin
  const AGRO_FACTOR_FLOOR    : f64 = 0.2; // Floor of ecological impact on yields
  const AGRO_FACTOR_CONS_MUL : f64 = 1.0; // forces consumption to be X times larger than production, with clampings

  fn calcIndMaxFlow( self : *EconSolver ) void
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

        // NOTE : Potentially too penalizing. review this section
        //// further adjusting AGRONOMIC yields based on ecoFactor
        //if( indType == .AGRONOMIC )
        //{
        //  maxProd *= @min( agroFactor,                        1.0 );
        //  maxCons *= @min( agroFactor * AGRO_FACTOR_CONS_MUL, 1.0 );
        //}
        }
      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resType ), maxProd, maxCons });

        self.indResFlowData.set( indType, .OPR_CONS, resType, maxCons );
        self.indResFlowData.set( indType, .OPR_PROD, resType, maxProd );

        self.grpResFlowData.add( .IND,    .OPR_CONS, resType, maxCons );
        self.grpResFlowData.add( .IND,    .OPR_PROD, resType, maxProd );

        self.genResFlowData.add(          .OPR_CONS, resType, maxCons );
        self.genResFlowData.add(          .OPR_PROD, resType, maxProd );
      }}
    }
  }


  const INF_MAINT_IDLE_FACTOR : f64 = 0.25;
  const IND_MAINT_IDLE_FACTOR : f64 = 0.10;

  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  fn calcMntMaxFlow( self : *EconSolver ) void
  {
  //inline for( 0..resType )| r |
    {
      const resType = ResType.PART;

      inline for( 0..infTypeC )| f |
      {
        const infType  = InfType.fromIdx( f );

        const factor   = self.econ.infState.get( .USE_LVL, infType );
        const scaling  = def.lerp( INF_MAINT_IDLE_FACTOR, 1.0, factor );

        const infCount = self.econ.infState.get(   .COUNT, infType );
        const baseCost = infType.getResMetric_f64( .MAINT, resType );
        const maxCost  = infCount * baseCost * scaling;

        self.infResFlowData.set( infType, .MNT_CONS, resType, maxCost );
        self.grpResFlowData.add( .INF,    .MNT_CONS, resType, maxCost );
        self.genResFlowData.add(          .MNT_CONS, resType, maxCost );
      }
      inline for( 0..indTypeC )| d |
      {
        const indType  = IndType.fromIdx( d );

        const factor   = self.econ.indState.get( .ACT_LVL, indType );
        const scaling  = def.lerp( IND_MAINT_IDLE_FACTOR, 1.0, factor );

        const indCount = self.econ.indState.get(   .COUNT, indType );
        const baseCost = indType.getResMetric_f64( .MAINT, resType );
        const maxCost  = indCount * baseCost * scaling;

        self.indResFlowData.set( indType, .MNT_CONS, resType, maxCost );
        self.grpResFlowData.add( .IND,    .MNT_CONS, resType, maxCost );
        self.genResFlowData.add(          .MNT_CONS, resType, maxCost );
      }
    }
  }

  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  fn calcBldMaxFlow( self : *EconSolver ) void
  {
    if( self.econ.buildQueue == null ){ return; }

    const queue = &self.econ.buildQueue.?;

    if( queue.entryCount == 0 ){ return; }

    // Walk entries, attribute via construct for now
    var rawTotal : f64 = 0.0;

    for( 0..queue.entryCount )| idx |
    {
      const e = queue.entries[ idx ];
      if( e.buildCount == 0 ){ break; }

      const cost = @as( f64, @floatFromInt( e.buildCount )) * e.construct.getPartCost();
      rawTotal += cost;

      switch( e.construct )
      {
        .inf => | infType | {
          self.infResFlowData.add( infType, .BLD_CONS, .PART, cost );
          self.grpResFlowData.add( .INF,    .BLD_CONS, .PART, cost );
        },
        .ind => | indType | {
          self.indResFlowData.add( indType, .BLD_CONS, .PART, cost );
          self.grpResFlowData.add( .IND,    .BLD_CONS, .PART, cost );
        },
      }
    }

    // Apply ASSEMBLY throughput cap (preserves old calcBuildDemand semantics)
    const assemblyCount = self.econ.infState.get( .COUNT, .ASSEMBLY );
    const assemblyRate  = InfType.ASSEMBLY.getMetric_f64( .CAPACITY );
    const assemblyCap   = @floor( assemblyCount * assemblyRate );

    const cap : f64 = @min( rawTotal, assemblyCap );
    var scale : f64 = 1.0;

    if( rawTotal > def.EPS )
    {
      scale = cap / rawTotal;
    }

    // Scale all per-agent rows by `scale` so they reflect throughput-capped demand
    if( scale < 1.0 - def.EPS )
    {
      inline for( 0..infTypeC )| f |
      {
        const infType = InfType.fromIdx( f );
        const maxCost = self.infResFlowData.get( infType, .BLD_CONS, .PART );
        self.infResFlowData.set( infType, .BLD_CONS, .PART, @floor( maxCost * scale ) );
      }
      self.grpResFlowData.set( .INF, .BLD_CONS, .PART,
      self.grpResFlowData.get( .INF, .BLD_CONS, .PART ) * scale );

      inline for( 0..indTypeC )| d |
      {
        const indType = IndType.fromIdx( d );
        const maxCost = self.indResFlowData.get( indType, .BLD_CONS, .PART );
        self.indResFlowData.set( indType, .BLD_CONS, .PART, @floor( maxCost * scale ));
      }

      self.grpResFlowData.set( .IND, .BLD_CONS, .PART,
      self.grpResFlowData.get( .IND, .BLD_CONS, .PART ) * scale );
    }

    self.genResFlowData.add( .BLD_CONS, .PART, cap );
  }


// ================================ RES ACCESS PHASE ================================


  fn calcGenResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING GEN RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const stored = self.prevResStock.get( resType );
      const genDem = self.genResFlowData.get( .OPR_CONS, resType );

      var access : f64 = self.defGenResAccess;

      if( genDem > def.EPS )
      {
        access = stored / genDem;
      }

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resType ), stored, genDem, access });
      self.genResFlowData.set( .OPR_ACS, resType, access );
    }
  }

  fn calcPopResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING POP RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const stored = self.prevResStock.get( resType );
      const popDem = self.grpResFlowData.get( .POP, .OPR_CONS, resType );

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

      // NOTE : We do not use individualize access yet ( popResFlowData )
      self.grpResFlowData.set( .POP, .OPR_ACS, resType, access );
    }
  }

  fn calcInfResAccess( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }

  fn calcIndResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING IND RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const stored = self.prevResStock.get( resType );
      const indDem = self.grpResFlowData.get( .IND, .OPR_CONS, resType );

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

      // NOTE : We do not use individualize access yet ( indResFlowData )
      self.grpResFlowData.set( .IND, .OPR_ACS, resType, access );
    }
  }

  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  fn calcMntResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING MNT RES ACCESS :" );

    const stored = self.prevResStock.get( .PART );
    const mntDem = self.genResFlowData.get( .MNT_CONS, .PART );

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

    self.grpResFlowData.set( .POP, .MNT_ACS, .PART, access );
    self.grpResFlowData.set( .INF, .MNT_ACS, .PART, access );
    self.grpResFlowData.set( .IND, .MNT_ACS, .PART, access );
    self.genResFlowData.set(       .MNT_ACS, .PART, access );
  }

  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  fn calcBldResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING BLD RES ACCESS :" );

    const stored = self.prevResStock.get( .PART );
    const bldDem = self.genResFlowData.get( .BLD_CONS, .PART );

    // Calculating remaining resources
    const taken  = self.allocatedRes.get( .PART );
    const remain = @max( 0.0, stored - taken );
    const bldUse = @min( bldDem, remain );

    // Updating allocated resource use
    self.allocatedRes.add( .PART, bldUse );

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

    self.grpResFlowData.set( .POP, .BLD_ACS, .PART, access );
    self.grpResFlowData.set( .INF, .BLD_ACS, .PART, access );
    self.grpResFlowData.set( .IND, .BLD_ACS, .PART, access );
    self.genResFlowData.set(       .BLD_ACS, .PART, access );
  }


// ================================ ACTION RATES PHASE ================================


  // TODO : Generalise to acount for all pop
  fn updatePopFulfilment( self : *EconSolver ) void
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

          const maxCons = self.popResFlowData.get( popType, .OPR_CONS, resType );

          if( maxCons > def.EPS )
          {
            // NOTE : We do not use individualize access yet ( popFlowData )
            fulfilment = @min( fulfilment, self.grpResFlowData.get( .POP, .OPR_ACS, resType ));
          }
        }
      }
    //def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}", .{ @tagName( resType ), activity });

      self.econ.popState.set( .FLM_LVL, .HUMAN, fulfilment );
    }
  }

  fn updateInfUsage( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }

  fn updateIndActivity( self : *EconSolver ) void
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

          const maxCons = self.indResFlowData.get( indType, .OPR_CONS, resType );

          if( maxCons > def.EPS )
          {
            // NOTE : We do not use individualize access yet ( popFlowData )
            activity = @min( activity, self.grpResFlowData.get( .IND, .OPR_ACS, resType ));
          }
        }
      }
    //def.log( .CONT, 0, @src(), "{s}\t: {d:.6}", .{ @tagName( indType ), activity });

      self.econ.indState.set( .ACT_LVL, indType, activity );
    }
  }


// ================================ CONSUMPTION PHASE ================================


  fn calcPopResCons( self : *EconSolver ) void
  {
    for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      inline for( 0..resTypeC )| r |
      {
        const resType = ResType.fromIdx( r );

        // NOTE : Pop fulfilment rate does NOT affect consumption rates

        const oprAcs  = self.grpResFlowData.get( .POP, .OPR_ACS, resType );
        const oprCons = self.popResFlowData.get( popType, .OPR_CONS, resType ) * oprAcs;

        self.popResFlowData.set( popType, .OPR_CONS, resType, oprCons );

        self.popResFlowData.set( popType, .TOT_CONS, resType, oprCons );
        self.grpResFlowData.add( .POP,    .TOT_CONS, resType, oprCons );
        self.genResFlowData.add(          .TOT_CONS, resType, oprCons );
      }
    }
  }

  fn calcInfResCons( self : *EconSolver ) void
  {
    for( 0..infTypeC )| d |
    {
      const infType  = InfType.fromIdx( d );
      const infUsage = self.econ.infState.get( .USE_LVL, infType );

      if( infUsage > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          // TODO : Scale consumption based on infUsage

          const oprAcs  = self.grpResFlowData.get( .INF,    .OPR_ACS,  resType );
          const mntAcs  = self.grpResFlowData.get( .INF,    .MNT_ACS,  resType );
          const bldAcs  = self.grpResFlowData.get( .INF,    .BLD_ACS,  resType );

          const oprCons = self.infResFlowData.get( infType, .OPR_CONS, resType ) * oprAcs;
          const mntCons = self.infResFlowData.get( infType, .MNT_CONS, resType ) * mntAcs;
          const bldCons = self.infResFlowData.get( infType, .BLD_CONS, resType ) * bldAcs;

          const totCons = oprCons + mntCons + bldCons;

          self.infResFlowData.set( infType, .OPR_CONS, resType, oprCons );
          self.infResFlowData.set( infType, .MNT_CONS, resType, mntCons );
          self.infResFlowData.set( infType, .BLD_CONS, resType, bldCons );

          self.infResFlowData.set( infType, .TOT_CONS, resType, totCons );
          self.grpResFlowData.add( .INF,    .TOT_CONS, resType, totCons );
          self.genResFlowData.add(          .TOT_CONS, resType, totCons );
        }
      }
    }
  }

  fn calcIndResCons( self : *EconSolver ) void
  {
    for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );
      const indActivity = self.econ.indState.get( .ACT_LVL, indType );

      if( indActivity > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          const mntAcs  = self.grpResFlowData.get( .IND,    .MNT_ACS,  resType );
          const bldAcs  = self.grpResFlowData.get( .IND,    .BLD_ACS,  resType );

          const oprCons = self.indResFlowData.get( indType, .OPR_CONS, resType ) * indActivity;
          const mntCons = self.indResFlowData.get( indType, .MNT_CONS, resType ) * mntAcs;
          const bldCons = self.indResFlowData.get( indType, .BLD_CONS, resType ) * bldAcs;

          const totCons = oprCons + mntCons + bldCons;

          self.indResFlowData.set( indType, .OPR_CONS, resType, oprCons );
          self.indResFlowData.set( indType, .MNT_CONS, resType, mntCons );
          self.indResFlowData.set( indType, .BLD_CONS, resType, bldCons );

          self.indResFlowData.set( indType, .TOT_CONS, resType, totCons );
          self.grpResFlowData.add( .IND,    .TOT_CONS, resType, totCons );
          self.genResFlowData.add(          .TOT_CONS, resType, totCons );
        }
      }
    }
  }

  fn applyGenResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genCons = self.genResFlowData.get( .TOT_CONS, resType );

      self.nextResStock.sub( resType, genCons );
    }
  }

  /// Independent from GEN cons
  fn applyResDecay( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx( r );
      const resCount = self.nextResStock.get( resType );

      // Decay applies to what remains AFTER general consumption
      if( resCount > def.EPS )
      {
        const decayed = @ceil( resCount * resType.getMetric_f64( .DECAY_RATE ));

      //self.grpResFlowData.set( .NAT, .FIN_CONS, resType, decayed ); // TODO : save the decayed amount somewhere for debug loging
        self.nextResStock.sub( resType, decayed );
      }
    }
  }


// ================================ PRODUCTION PHASE ================================


  const POP_PROD_FLOOR : f64 = 0.1;

  fn calcPopResProd( self : *EconSolver ) void
  {
    inline for( 0..popTypeC )| p |
    {
      const popType       = PopType.fromIdx( p );
      const popFulfilment = self.econ.popState.get( .FLM_LVL, popType );

      inline for( 0..resTypeC )| r |
      {
        const resType = ResType.fromIdx( r );

        const prodRate = @max( popFulfilment, POP_PROD_FLOOR ); // Even starving, pops can work a bit
        const oprProd  = self.popResFlowData.get( popType, .OPR_PROD, resType ) * prodRate;

        self.popResFlowData.set( popType, .TOT_PROD, resType, oprProd );
        self.grpResFlowData.add( .POP,    .TOT_PROD, resType, oprProd );
        self.genResFlowData.add(          .TOT_PROD, resType, oprProd );
      }
    }
  }

  // NOTE : Inf will never produce resources

  fn calcIndResProd( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType     = IndType.fromIdx( d );

      const indActivity = self.econ.indState.get( .ACT_LVL, indType );

      if( indActivity > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );
          const oprProd = self.indResFlowData.get( indType, .OPR_PROD, resType ) * indActivity;

          self.indResFlowData.set( indType, .TOT_PROD, resType, oprProd );
          self.grpResFlowData.add( .IND,    .TOT_PROD, resType, oprProd );
          self.genResFlowData.add(          .TOT_PROD, resType, oprProd );
        }
      }
    }
  }

  fn applyGenResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const genProd = self.genResFlowData.get( .TOT_PROD, resType );

      self.nextResStock.add( resType, genProd );
    }
  }


// ================================ FINANCES PHASE ================================


  fn clampResStocks( self : *EconSolver ) void      // TODO : save the wasted amounts as metrics
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const resCap  = self.econ.resState.get( .LIMIT, resType );
      const current = self.nextResStock.get( resType );

      if( current > resCap )
      {
        // Clamp stock but do NOT adjust production metrics
        // Industries consumed final inputs and produced final outputs
        // The overflow is a storage problem, not a production problem
        // Prices will naturally suppress overproduction via supply > demand

        self.nextResStock.set( resType, resCap );

        def.log( .WARN, 0, @src(), "{s} stock overflow : {d:.0} clamped to {d:.0} ( {d:.0} wasted )", .{ @tagName( resType ), current, resCap, current - resCap });
      }
    }
  }

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
      const finDemand = self.genResFlowData.get( .TOT_CONS, resType ); // NOTE : EXCLUDES NATURAL DECAY
      const finSupply = self.genResFlowData.get( .TOT_PROD, resType );

      const ceil : f64 = MAX_SCARC_RATIO; // Scarcity ceiling
      var  ratio : f64 = 0.0;

      if(      finSupply > def.EPS ){ ratio = @min( ceil, finDemand / finSupply ); }
      else if( finDemand > def.EPS ){ ratio = ceil; }

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
            expense += resPrice * self.popResFlowData.get( popType, .OPR_CONS, resType );
            revenue += resPrice * self.popResFlowData.get( popType, .OPR_PROD, resType );
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


  fn updateInfFinances( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }


  // Minimum industry activity - prevents permanent shutdown death spiral
  // Industries always "test" the market at this rate
  const IND_MIN_ACT_TRGT  : f64 = 0.05;
  const IND_MARGIN_FLOOR  : f64 = -2.5;
  const IND_MARGIN_OFFSET : f64 = -0.0;
  const ACT_TRGT_FACTOR   : f64 =  8.0; // NOTE : lower for a smoother target transitioning

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
            // NOTE : ignore build costs, as those are one-time payments from savings
            expense += resPrice * self.indResFlowData.get( indType, .OPR_CONS, resType );
            expense += resPrice * self.indResFlowData.get( indType, .MNT_CONS, resType );

            revenue += resPrice * self.indResFlowData.get( indType, .TOT_PROD, resType );
          }
          else // Theoritical profitability calculations
          {
            expense += resPrice * indType.getResMetric_f64( .CONS,  resType );
            expense += resPrice * indType.getResMetric_f64( .MAINT, resType );

            revenue += resPrice * indType.getResMetric_f64( .PROD,  resType );
          }
        }
        profit = revenue - expense;


        // Calculating margin and activity target
        const floor : f64 = IND_MARGIN_FLOOR;
        var  margin : f64 = 0.0;

        if(      revenue > def.EPS ){ margin = @max( floor, profit / revenue ); }
        else if( expense > def.EPS ){ margin =       floor; }

        // Large profits will push target towards 1.0, large losses will push it towards 0.0
        var activityTarget = self.maxIndActivity * def.sigmoid( margin + IND_MARGIN_OFFSET, ACT_TRGT_FACTOR );
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

          // TODO : transfer capital to gov if non-zero ( industry may have gone insolvent )
        }
      }
      else // This industry cannot be built in this econ
      {
        //NOTE : Ensures all these are zero. to trivially void all "This industry would be profitable here" signaling

        econ.indState.zero( .ACT_TRGT, indType );
        econ.indState.zero( .EXPENSE,  indType );
        econ.indState.zero( .REVENUE,  indType );

        // TODO : transfer capital to gov if non-zero ( industry may have been destroyed )
      }
    }
  }


// ================================ GROWTH & DECAY PHASE ================================


// Pop growth / decay factors
  const RES_MODIFIER_EXPONENT : f64 = def.PHI; // Smooth out death rates from pop res shortages
  const JOB_MODIFIER_EXPONENT : f64 = def.PHI; // Smooth out growth suppression from pop job shortages

  const MAX_RES_MODIFIER : f64 = 1.2;
  const MAX_JOB_MODIFIER : f64 = 1.2;

  fn updatePopCount( self : *EconSolver ) void
  {
    const jobAccess : f64 = @max( def.EPS, self.genResFlowData.get( .OPR_ACS, .WORK ));

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
            const access = self.grpResFlowData.get( .POP, .OPR_ACS, resType );
            minResAccess = @min( minResAccess, access );

            def.log( .CONT, 0, @src(), "- {s}\t : {d:.4}", .{ @tagName( resType ), access });

            if( access < 1.0 )
            {
              def.log( .CONT, 0, @src(), "@ Experiencing {s} shortages !", .{ @tagName( resType ) });

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

  fn updateInfCount( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }
  fn updateIndCount( self : *EconSolver ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }
// TODO : calc target  growth / decay based on profitability
// NOTE : remove capital from growth costs
// NOTE : inject capital from decay selloffs


// ================================ ECON UPDATE PHASE ================================


  fn pushResMetrics( self : *EconSolver ) void
  {
    const econ : *ecn.Economy = self.econ;

    const bldDem = self.genResFlowData.get( .BLD_CONS, .PART );
    const bldAcs = self.genResFlowData.get( .BLD_ACS,  .PART );

    self.econ.buildBudget = @floor( bldDem * bldAcs );

  // ================ AGENT AVERAGE ACCESS RATE ================

    var avgGenResAccess  : f64 = 0.0;
    var avgPopResAccess  : f64 = 0.0;
  //var avgInfResAccess  : f64 = 0.0;
    var avgIndResAccess  : f64 = 0.0;


    inline for( 0..resTypeC )| r |
    {
      const res = ResType.fromIdx( r );

      const initialStk = self.econ.resState.get(  .COUNT,   res );
      const finalStk   = self.nextResStock.get(             res );
      const initialAcs = self.econ.resState.get(  .ACCESS,  res );
      const finalAcs   = self.genResFlowData.get( .OPR_ACS, res );

      econ.resState.set( .COUNT,     res, @max( 0.0, finalStk  ));
      econ.resState.set( .COUNT_D,   res, finalStk - initialStk );
      econ.resState.set( .ACCESS,    res, @max( 0.0, finalAcs  ));
      econ.resState.set( .ACCESS_D,  res, finalAcs - initialAcs );

      avgGenResAccess += self.genResFlowData.get(       .OPR_ACS, res );
      avgPopResAccess += self.grpResFlowData.get( .POP, .OPR_ACS, res );
    //avgInfResAccess += self.resFlowData.get( .INF, .ACCESS, res );
      avgIndResAccess += self.grpResFlowData.get( .IND, .OPR_ACS, res );
    }


    avgGenResAccess  /= @floatFromInt( resTypeC );
    avgPopResAccess  /= @floatFromInt( popTypeC );
  //avgInfResAccess  /= @floatFromInt( infTypeC );
    avgIndResAccess  /= @floatFromInt( indTypeC );

  //econ.agtState.set( .GEN, .ACCESS, avgGenResAccess ); // TODO : save general access rates in economy
    econ.agtState.set( .POP, .ACCESS, avgPopResAccess );
  //econ.agtState.set( .INF, .ACCESS, avgInfResAccess );
    econ.agtState.set( .IND, .ACCESS, avgIndResAccess );
  }

  fn pushAgentMetrics( self : *EconSolver ) void
  {
    const econ : *ecn.Economy = self.econ;

  // ================ AGENT AVERAGE "ACTION" RATE ================

    var avgPopFulfilment : f64 = 0.0;
    var avgInfUsage      : f64 = 0.0;
    var avgIndActivity   : f64 = 0.0;


    inline for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      avgPopFulfilment += self.econ.popState.get( .FLM_LVL, popType );
    }

    avgPopFulfilment /= @floatFromInt( popTypeC );
    econ.agtState.set( .POP, .ACTION, avgPopFulfilment );


    inline for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      avgInfUsage += self.econ.infState.get( .USE_LVL, infType );
    }

    avgInfUsage /= @floatFromInt( infTypeC );
    econ.agtState.set( .INF, .ACTION, avgInfUsage );


    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );

      avgIndActivity += self.econ.indState.get( .ACT_LVL, indType );
    }

    avgIndActivity /= @floatFromInt( indTypeC );
    econ.agtState.set( .IND, .ACTION, avgIndActivity );
  }


// ================================ DEBUG LOGGING ================================


  pub inline fn logAllMetrics( self : *const EconSolver ) void
  {
    // Comment and uncomment these subfunctions to select what to log
    // Most of these are show during steping anyways

    self.logResMetrics();
    self.logIndMetrics();
    self.logInfMetrics();
    self.logPopMetrics();
  }

  pub fn logPopMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ POPULATION : Count ( Capacity )  [ Delta | Births Deaths ( Starved )]  Fulfilment" );
    def.qlog( .CONT, 0, @src(), "===================================================================================" );

    inline for( 0..popTypeC )| p |
    {
      const popType  = PopType.fromIdx( p );

      const count   : f64 = self.econ.popState.get( .COUNT,  popType );
      const limit   : f64 = self.econ.popState.get( .LIMIT,  popType );

      const births  : f64 = self.econ.popState.get( .BIRTH,  popType );
      const deaths  : f64 = self.econ.popState.get( .DEATH,  popType );
      const starved : f64 = self.econ.popState.get( .STARVE, popType );
      const delta   : f64 = births - deaths;

      const flmLvl  : f64 = self.econ.popState.get( .FLM_LVL, popType ) * 100;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t/ {d:.0}\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t( -{d:.0}\t)] {d:.3}%",
        .{ @tagName( popType ), count, limit, delta, births, deaths, starved, flmLvl });
    }
  }

  pub inline fn logInfMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ INFRASTRUCTURE : Count ( Bonus )  [ Delta ]  Usage rate" );
    def.qlog( .CONT, 0, @src(), "=========================================================" );

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
    def.qlog( .INFO, 0, @src(), "$ INDUSTRY : Count  [ Delta ]  Activity rate / Target rate" );
    def.qlog( .CONT, 0, @src(), "==========================================================" );
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

  pub inline fn logResMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ RESOURCE : Count / Capacity  [ Delta | Prod Cons Decay ]  Access rate  ( Price )" );
    def.qlog( .CONT, 0, @src(), "==================================================================================" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const count  : f64 = self.econ.resState.get( .COUNT, resType );
      const limit  : f64 = self.econ.resState.get( .LIMIT, resType );
      const price  : f64 = self.econ.resState.get( .PRICE, resType );

      const prod   : f64 = self.genResFlowData.get(       .TOT_PROD, resType );
      const cons   : f64 = self.genResFlowData.get(       .TOT_CONS, resType );
    //const decay  : f64 = self.grpResFlowData.get( .NAT, .FIN_CONS, resType ); // TODO : Restore storing of decay
      const delta  : f64 = prod - cons;

      const avgAcs : f64 = self.genResFlowData.get( .OPR_ACS, resType ) * 100.0;

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t/ {d:.0}\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t-{d:.0}\t] {d:.2}%\t ( {d:.6} )",
        .{ @tagName( resType ), count, limit, delta, prod, cons, -1.0, avgAcs, price });
    }
  }
};


// ================================ TEST-LOGGER ================================


// TODO : rework once solver refactor is done

pub fn testEconLogs( econ : *ecn.Economy ) void
{
  // NOTE : Uses non-global solver-instance to avoid corrupting the actual solver
  var tmpSolver : EconSolver = .{ .econ = undefined };

  tmpSolver.initBaseState( econ );

  tmpSolver.calcPopMaxFlow();
  tmpSolver.calcIndMaxFlow();
  tmpSolver.calcMntMaxFlow();
  tmpSolver.calcBldMaxFlow();


  def.qlog( .INFO, 0, @src(), "$ TESTING ECON PROFITABILITY :" );

  def.qlog( .INFO, 0, @src(), "# RES DELTA :" );

  inline for( 0..resTypeC )| r |
  {
    const resType   = ResType.fromIdx( r );

    const cons  = tmpSolver.genResFlowData.get( .OPR_CONS, resType );
    const prod  = tmpSolver.genResFlowData.get( .OPR_PROD, resType );
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

      expense += resPrice * tmpSolver.popResFlowData.get( popType, .OPR_CONS, resType );
      revenue += resPrice * tmpSolver.popResFlowData.get( popType, .OPR_PROD, resType );
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

      expense += resPrice * tmpSolver.indResFlowData.get( indType, .OPR_CONS, resType );
      revenue += resPrice * tmpSolver.indResFlowData.get( indType, .OPR_PROD, resType );
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


