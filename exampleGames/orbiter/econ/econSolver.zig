const std = @import( "std"  );
const def = @import( "defs" );


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const ecn = gdf.ecn;

const PowerSrc  = gdf.PowerSrc;
const VesType   = gdf.VesType;
const ResType   = gdf.ResType;
const PopType   = gdf.PopType;
const InfType   = gdf.InfType;
const IndType   = gdf.IndType;

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


  // TODO : Fold into POP/INF/IND, and generalise to account for all ResType
  solver.calcMntMaxFlow(); // Computes the maximal maintenance  consumption
  solver.calcBldMaxFlow(); // Computes the maximal construction prod and cons


// ================ RES ACCESS PHASE ================

  // TODO : Have these call a singular, generic "calcResAccess" instead (?)
  solver.calcGenResAccess(); // Computes the expected aggregated resource access
  solver.calcPopResAccess(); // Computes the expected population resource access
//solver.calcInfResAccess(); // Computes the expected infrastr.  resource access
  solver.calcIndResAccess(); // Computes the expected industrial resource access
//solver.calcComResAccess(); // Computes the expected commercial resource access

  // TODO : Fold into POP/INF/IND, and generalise to account for all ResType
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
  defGenResAccess : f64 = 100.0,

  maxPopResAccess : f64 = 1.0,
  maxIndResAccess : f64 = 1.0,
  maxMntResAccess : f64 = 1.0,
  maxBldResAccess : f64 = 1.0,
  maxComResAccess : f64 = 1.0,

  maxPopActivity  : f64 = 1.0,
  maxIndActivity  : f64 = 1.0,

  // Core solver data
  econ : *ecn.Economy,

  // Stock snapshot buffers
  resStockData : ecnm_d.ResStockData = .{},

  // Res flow data
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

    self.resStockData.fillWith( 0.0 );

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
      const resT      = ResType.fromIdx( r );
      const econStock = self.econ.resState.get( .COUNT, resT );

      self.resStockData.set( .BUFF,  resT, econStock );
      self.resStockData.set( .FINAL, resT, econStock );
    }
  }


// ================================ MAX RES FLOW PHASE ================================


  fn calcPopMaxFlow( self : *EconSolver ) void
  {
    inline for( 0..popTypeC )| d |
    {
      const popT = PopType.fromIdx( d );
      const popC = self.econ.popState.get( .COUNT, popT );

    //def.log( .INFO, 0, @src(), "$ LOGGING DELTAS FOR {s} :", .{ @tagName( popT )});

      if( popC > def.EPS ){ inline for ( 0..resTypeC )| r | // Skip absent populations
      {
        const resT = ResType.fromIdx( r );

        const maxCons = popC * popT.getResMetric_f64( .CONS, resT );
        const maxProd = popC * popT.getResMetric_f64( .PROD, resT );

      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resT ), maxProd, maxCons });

        self.popResFlowData.set( popT, .OPR_CONS, resT, maxCons );
        self.popResFlowData.set( popT, .OPR_PROD, resT, maxProd );

        self.grpResFlowData.add( .POP, .OPR_CONS, resT, maxCons );
        self.grpResFlowData.add( .POP, .OPR_PROD, resT, maxProd );

        self.genResFlowData.add(       .OPR_CONS, resT, maxCons );
        self.genResFlowData.add(       .OPR_PROD, resT, maxProd );
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
      const indT = IndType.fromIdx( d );
      const indC = self.econ.indState.get( .COUNT, indT );

    //def.log( .INFO, 0, @src(), "$ LOGGING DELTAS FOR {s} :", .{ @tagName( indT )});

      if( indC > def.EPS ){ inline for ( 0..resTypeC )| r | // Skip absent industries
      {
        const resT = ResType.fromIdx( r );

        var maxCons = indC * indT.getResMetric_f64( .CONS, resT );
        var maxProd = indC * indT.getResMetric_f64( .PROD, resT );

        // Adjust expected max prod based on sunlight
        if( indT.getPowerSrc() == .SOLAR )
        {
          maxCons *= @floatCast( self.econ.sunAccess );
          maxProd *= @floatCast( self.econ.sunAccess );

        // NOTE : Potentially too penalizing. review this section
        //// further adjusting AGRONOMIC yields based on ecoFactor
        //if( indT == .AGRONOMIC )
        //{
        //  maxProd *= @min( agroFactor,                        1.0 );
        //  maxCons *= @min( agroFactor * AGRO_FACTOR_CONS_MUL, 1.0 );
        //}
        }
      //def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( resT ), maxProd, maxCons });

        self.indResFlowData.set( indT, .OPR_CONS, resT, maxCons );
        self.indResFlowData.set( indT, .OPR_PROD, resT, maxProd );

        self.grpResFlowData.add( .IND, .OPR_CONS, resT, maxCons );
        self.grpResFlowData.add( .IND, .OPR_PROD, resT, maxProd );

        self.genResFlowData.add(       .OPR_CONS, resT, maxCons );
        self.genResFlowData.add(       .OPR_PROD, resT, maxProd );
      }}
    }
  }


  // TODO : Move IDLE_FACTOR to peing per-IndType/InfType
  const INF_MAINT_IDLE_FACTOR : f64 = 0.25;
  const IND_MAINT_IDLE_FACTOR : f64 = 0.10;

  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  fn calcMntMaxFlow( self : *EconSolver ) void
  {
  //inline for( 0..resTypeC )| r |
    {
      const resT = ResType.PART;

      inline for( 0..infTypeC )| f |
      {
        const infT = InfType.fromIdx( f );
        const infC = self.econ.infState.get( .COUNT, infT );

        const factor   = self.econ.infState.get( .USE_LVL, infT );
        const scaling  = def.lerp( INF_MAINT_IDLE_FACTOR, 1.0, factor );

        const baseCost = infT.getResMetric_f64(  .MAINT, resT );
        const maxCost  = infC * baseCost * scaling;

        self.infResFlowData.set( infT, .MNT_CONS, resT, maxCost );
        self.grpResFlowData.add( .INF, .MNT_CONS, resT, maxCost );
        self.genResFlowData.add(       .MNT_CONS, resT, maxCost );
      }
      inline for( 0..indTypeC )| d |
      {
        const indT = IndType.fromIdx( d );
        const indC = self.econ.indState.get(   .COUNT, indT );

        const factor   = self.econ.indState.get( .ACT_LVL, indT );
        const scaling  = def.lerp( IND_MAINT_IDLE_FACTOR, 1.0, factor );

        const baseCost = indT.getResMetric_f64( .MAINT, resT );
        const maxCost  = indC * baseCost * scaling;

        self.indResFlowData.set( indT, .MNT_CONS, resT, maxCost );
        self.grpResFlowData.add( .IND, .MNT_CONS, resT, maxCost );
        self.genResFlowData.add(       .MNT_CONS, resT, maxCost );
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

      const cost = @as( f64, @floatFromInt( e.buildCount )) * e.construct.getResBldCost( .PART );
      rawTotal += cost;

      switch( e.construct )
      {
        .infT => | f | {
          self.infResFlowData.add(    f, .BLD_CONS, .PART, cost );
          self.grpResFlowData.add( .INF, .BLD_CONS, .PART, cost );
        },
        .indT => | d | {
          self.indResFlowData.add(    d, .BLD_CONS, .PART, cost );
          self.grpResFlowData.add( .IND, .BLD_CONS, .PART, cost );
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
        const infT    = InfType.fromIdx( f );
        const maxCost = self.infResFlowData.get( infT, .BLD_CONS, .PART );

        self.infResFlowData.set( infT, .BLD_CONS, .PART, @floor( maxCost * scale ) );
      }
      self.grpResFlowData.set( .INF, .BLD_CONS, .PART,
      self.grpResFlowData.get( .INF, .BLD_CONS, .PART ) * scale );

      inline for( 0..indTypeC )| d |
      {
        const indT    = IndType.fromIdx( d );
        const maxCost = self.indResFlowData.get( indT, .BLD_CONS, .PART );

        self.indResFlowData.set( indT, .BLD_CONS, .PART, @floor( maxCost * scale ));
      }

      self.grpResFlowData.set( .IND, .BLD_CONS, .PART,
      self.grpResFlowData.get( .IND, .BLD_CONS, .PART ) * scale );
    }

    self.genResFlowData.add( .BLD_CONS, .PART, cap );
  }


// ================================ RES ACCESS PHASE ================================


  fn calcPopResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING POP RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      const remain = self.resStockData.get(             .BUFF, resT );
      const popDem = self.grpResFlowData.get( .POP, .OPR_CONS, resT );
      const popUse = @min( popDem, remain );

      // Updating resource buffer
      self.resStockData.sub( .BUFF, resT, popUse );

      // Calculating access
      var access : f64 = self.maxPopResAccess;

      if( popDem > def.EPS )
      {
        access = @min( access, remain / popDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( resT ), remain, popDem, access * 100.0 });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage for population", .{ @tagName( resT )});
        }
      }

      // NOTE : We do not use individualize access yet ( popResFlowData )
      self.grpResFlowData.set( .POP, .OPR_ACS, resT, access );
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
      const resT = ResType.fromIdx( r );

      const remain = self.resStockData.get(             .BUFF, resT );
      const indDem = self.grpResFlowData.get( .IND, .OPR_CONS, resT );
      const indUse = @min( indDem, remain );

      // Updating resource buffer
      self.resStockData.sub( .BUFF, resT, indUse );

      // Calculating access
      var access : f64 = self.maxIndResAccess;

      if( indDem > def.EPS )
      {
        access = @min( access, remain / indDem );

        def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( resT ), remain, indDem, access * 100.0 });

        if( access < 1.0 - def.EPS )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage for industry", .{ @tagName( resT )});
        }
      }

      // NOTE : We do not use individualize access yet ( indResFlowData )
      self.grpResFlowData.set( .IND, .OPR_ACS, resT, access );
    }
  }

  // TODO : Fold into POP/INF/IND, and generalise to account for all res
  fn calcMntResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING MNT RES ACCESS :" );

    const resT = ResType.PART;

    const remain = self.resStockData.get(       .BUFF, resT );
    const mntDem = self.genResFlowData.get( .MNT_CONS, resT );
    const mntUse = @min( mntDem, remain );

    // Updating resource buffer
    self.resStockData.sub( .BUFF, resT, mntUse );

    // Calculating access
    var access : f64 = self.maxMntResAccess;

    if( mntDem > def.EPS )
    {
      access = @min( access, remain / mntDem );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.2}%", .{ @tagName( resT ), remain, mntDem, access * 100.0 });

      if( access < 1.0 - def.EPS )
      {
        def.log( .CONT, 0, @src(), "@ {s} shortage for maintenance", .{ @tagName( resT )});
      }
    }

    self.grpResFlowData.set( .POP, .MNT_ACS, resT, access );
    self.grpResFlowData.set( .INF, .MNT_ACS, resT, access );
    self.grpResFlowData.set( .IND, .MNT_ACS, resT, access );
    self.genResFlowData.set(       .MNT_ACS, resT, access );
  }

  // TODO : Fold into POP/INF/IND, and generalise to account for all resT
  fn calcBldResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING BLD RES ACCESS :" );

    const resT = ResType.PART;

    const remain = self.resStockData.get(       .BUFF, resT );
    const bldDem = self.genResFlowData.get( .BLD_CONS, resT );
    const bldUse = @min( bldDem, remain );

    // Updating resource buffer
    self.resStockData.sub( .BUFF, resT, bldUse );


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


  fn calcGenResAccess( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING GEN RES ACCESS :" );

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      const stored = self.econ.resState.get(  .COUNT,    resT ); // Using initial Stocks
      const genDem = self.genResFlowData.get( .OPR_CONS, resT );

      var access : f64 = self.defGenResAccess;

      if( genDem > def.EPS )
      {
        access = stored / genDem;
      }

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}\t| {d:.6}", .{ @tagName( resT ), stored, genDem, access });
      self.genResFlowData.set( .OPR_ACS, resT, access );
    }
  }

// ================================ ACTION RATES PHASE ================================


  // TODO : Generalise to acount for all pop
  fn updatePopFulfilment( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "$ LOGGING FINAL POP ACTIVITY :" );

    inline for ( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );
      const popC = self.econ.popState.get( .COUNT, popT );

      var fulfilment : f64 = self.maxPopActivity;

      if( popC > def.EPS ) // Skip absent population
      {
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );

          const maxCons = self.popResFlowData.get( popT, .OPR_CONS, resT );

          if( maxCons > def.EPS )
          {
            // NOTE : We do not use individualize access yet ( popFlowData )
            fulfilment = @min( fulfilment, self.grpResFlowData.get( .POP, .OPR_ACS, resT ));
          }
        }
      }
    //def.log( .CONT, 0, @src(), "{s}  \t: {d:.6}", .{ @tagName( resT ), activity });

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
      const indT = IndType.fromIdx( d );
      const indC = self.econ.indState.get( .COUNT, indT );

      var activity : f64 = self.maxIndActivity;

      // Basing new activity on previous tick's activity target AND current tick res access caps
      activity = @min( activity, self.econ.indState.get( .ACT_TRGT, indT ));

      if( indC > def.EPS ) // Skip absent industries
      {
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );

          const maxCons = self.indResFlowData.get( indT, .OPR_CONS, resT );

          if( maxCons > def.EPS )
          {
            // NOTE : We do not use individualize access yet ( popFlowData )
            activity = @min( activity, self.grpResFlowData.get( .IND, .OPR_ACS, resT ));
          }
        }
      }
    //def.log( .CONT, 0, @src(), "{s}\t: {d:.6}", .{ @tagName( indT ), activity });

      self.econ.indState.set( .ACT_LVL, indT, activity );
    }
  }


// ================================ CONSUMPTION PHASE ================================


  fn calcPopResCons( self : *EconSolver ) void
  {
    for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );

    // NOTE : Pop fulfilment rate does NOT affect targeted consumption rates

      inline for( 0..resTypeC )| r |
      {
        const resT = ResType.fromIdx( r );

        const oprAcs  = self.grpResFlowData.get( .POP, .OPR_ACS,  resT );
        const oprCons = self.popResFlowData.get( popT, .OPR_CONS, resT ) * oprAcs;

        self.popResFlowData.set( popT, .OPR_CONS, resT, oprCons );

        self.popResFlowData.set( popT, .TOT_CONS, resT, oprCons );
        self.grpResFlowData.add( .POP, .TOT_CONS, resT, oprCons );
        self.genResFlowData.add(       .TOT_CONS, resT, oprCons );
      }
    }
  }

  fn calcInfResCons( self : *EconSolver ) void
  {
    for( 0..infTypeC )| d |
    {
      const infT     = InfType.fromIdx( d );
      const infUsage = self.econ.infState.get( .USE_LVL, infT );

      if( infUsage > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );

          const mntAcs  = self.grpResFlowData.get( .INF, .MNT_ACS,  resT );
          const bldAcs  = self.grpResFlowData.get( .INF, .BLD_ACS,  resT );

          const oprCons = self.infResFlowData.get( infT, .OPR_CONS, resT ) * infUsage;
          const mntCons = self.infResFlowData.get( infT, .MNT_CONS, resT ) * mntAcs;
          const bldCons = self.infResFlowData.get( infT, .BLD_CONS, resT ) * bldAcs;

          const totCons = oprCons + mntCons + bldCons;

          self.infResFlowData.set( infT, .OPR_CONS, resT, oprCons );
          self.infResFlowData.set( infT, .MNT_CONS, resT, mntCons );
          self.infResFlowData.set( infT, .BLD_CONS, resT, bldCons );

          self.infResFlowData.set( infT, .TOT_CONS, resT, totCons );
          self.grpResFlowData.add( .INF, .TOT_CONS, resT, totCons );
          self.genResFlowData.add(       .TOT_CONS, resT, totCons );
        }
      }
    }
  }

  fn calcIndResCons( self : *EconSolver ) void
  {
    for( 0..indTypeC )| d |
    {
      const indT   = IndType.fromIdx( d );
      const indAct = self.econ.indState.get( .ACT_LVL, indT );

      if( indAct > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );

          const mntAcs  = self.grpResFlowData.get( .IND, .MNT_ACS,  resT );
          const bldAcs  = self.grpResFlowData.get( .IND, .BLD_ACS,  resT );

          const oprCons = self.indResFlowData.get( indT, .OPR_CONS, resT ) * indAct;
          const mntCons = self.indResFlowData.get( indT, .MNT_CONS, resT ) * mntAcs;
          const bldCons = self.indResFlowData.get( indT, .BLD_CONS, resT ) * bldAcs;

          const totCons = oprCons + mntCons + bldCons;

          self.indResFlowData.set( indT, .OPR_CONS, resT, oprCons );
          self.indResFlowData.set( indT, .MNT_CONS, resT, mntCons );
          self.indResFlowData.set( indT, .BLD_CONS, resT, bldCons );

          self.indResFlowData.set( indT, .TOT_CONS, resT, totCons );
          self.grpResFlowData.add( .IND, .TOT_CONS, resT, totCons );
          self.genResFlowData.add(       .TOT_CONS, resT, totCons );
        }
      }
    }
  }

  fn applyGenResCons( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resT    = ResType.fromIdx( r );
      const genCons = self.genResFlowData.get( .TOT_CONS, resT );

      self.resStockData.sub( .FINAL, resT, genCons );
    }
  }

  /// Independent from GEN cons
  fn applyResDecay( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resT   = ResType.fromIdx( r );
      const remain = self.resStockData.get( .BUFF, resT );

      // Decay applies to what remains AFTER general consumption
      if( remain > def.EPS )
      {
        const decayed = @ceil( remain * @min( 1.0, resT.getMetric_f64( .DECAY_RATE )));

        self.resStockData.set( .DECAY, resT, decayed );
        self.resStockData.sub( .FINAL, resT, decayed );
      }
    }
  }


// ================================ PRODUCTION PHASE ================================


  const POP_PROD_FLOOR : f64 = 0.1;

  fn calcPopResProd( self : *EconSolver ) void
  {
    inline for( 0..popTypeC )| p |
    {
      const popT   = PopType.fromIdx( p );
      const popFlm = self.econ.popState.get( .FLM_LVL, popT );

      inline for( 0..resTypeC )| r |
      {
        const resT = ResType.fromIdx( r );

        const prodRate = @max( popFlm, POP_PROD_FLOOR ); // Even starving, pops can work a bit
        const oprProd  = self.popResFlowData.get( popT, .OPR_PROD, resT ) * prodRate;

        self.popResFlowData.set( popT, .TOT_PROD, resT, oprProd );
        self.grpResFlowData.add( .POP, .TOT_PROD, resT, oprProd );
        self.genResFlowData.add(       .TOT_PROD, resT, oprProd );
      }
    }
  }

  // NOTE : Inf will never produce resources

  fn calcIndResProd( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indT   = IndType.fromIdx( d );
      const indAct = self.econ.indState.get( .ACT_LVL, indT );

      if( indAct > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );
          const oprProd = self.indResFlowData.get( indT, .OPR_PROD, resT ) * indAct;

          self.indResFlowData.set( indT, .TOT_PROD, resT, oprProd );
          self.grpResFlowData.add( .IND, .TOT_PROD, resT, oprProd );
          self.genResFlowData.add(       .TOT_PROD, resT, oprProd );
        }
      }
    }
  }

  fn applyGenResProd( self : *EconSolver ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resT    = ResType.fromIdx( r );
      const genProd = self.genResFlowData.get( .TOT_PROD, resT );

      self.resStockData.add( .FINAL, resT, genProd );
    }
  }


// ================================ FINANCES PHASE ================================


  fn clampResStocks( self : *EconSolver ) void      // TODO : save the wasted amounts as metrics
  {
    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resL = self.econ.resState.get( .LIMIT, resT );
      const resC = self.resStockData.get(  .FINAL, resT );

      if( resC > resL )
      {
        // Clamp stock but do NOT adjust production metrics
        // Industries consumed final inputs and produced final outputs
        // The overflow is a storage problem, not a production problem
        // Prices will naturally suppress overproduction via supply > demand

        const destroyed : f64 = @ceil( @max( 0.0, resC - resL ));

        self.resStockData.set( .DESTR, resT, destroyed );
        self.resStockData.sub( .FINAL, resT, destroyed );

        def.log( .WARN, 0, @src(), "{s} stock overflow : {d:.0} clamped to {d:.0} ( {d:.0} wasted )", .{ @tagName( resT ), resC, resL, resC - resL });
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
      const resT = ResType.fromIdx( r );

      const basePrice  = resT.getMetric_f64( .PRICE_BASE );
      const elasticity = resT.getMetric_f64( .PRICE_ELAS );
      const dampening  = resT.getMetric_f64( .PRICE_DAMP ); // Lerp factor (0 = no change, 1 = instant)

      // Flow-based: compare this tick's production vs this tick's consumption demand
      const finDemand = self.genResFlowData.get( .TOT_CONS, resT ); // NOTE : EXCLUDES NATURAL DECAY
      const finSupply = self.genResFlowData.get( .TOT_PROD, resT );

      const ceil : f64 = MAX_SCARC_RATIO; // Scarcity ceiling
      var  ratio : f64 = 0.0;

      if(      finSupply > def.EPS ){ ratio = @min( ceil, finDemand / finSupply ); }
      else if( finDemand > def.EPS ){ ratio = ceil; }

      const rawPrice = basePrice * @max( MIN_PRICE_FACTOR, def.pow( f64, ratio, elasticity ));
      const oldPrice = self.econ.resState.get( .PRICE, resT );
      const newPrice = def.lerp(  oldPrice, rawPrice, dampening ); // Lerp dampening

      const dltPrice = newPrice - oldPrice;
      const dltPrcnt = 100.0 * dltPrice / oldPrice;
      const offPrcnt = 100.0 * newPrice / basePrice;

      const resC = self.resStockData.get( .FINAL, resT );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0} \t| {d:.6}\t| {d:.6}\t{d:.6}\t| {d:.1}%  \tx {d:.1}%", .{ @tagName( resT ), resC, basePrice, oldPrice, newPrice, dltPrcnt, offPrcnt });

      self.econ.resState.set( .PRICE,   resT, newPrice );
      self.econ.resState.set( .PRICE_D, resT, dltPrice );
    }
  }


  const POP_MARGIN_FLOOR : f64 = -2.5;

  fn updatePopFinances( self : *EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ LOGGING POP FINANCES :" );

    const econ = self.econ;
    inline for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );
      var   popC = econ.popState.get( .COUNT, popT );

      const isPresent : bool = ( popC > def.EPS );
      if( !isPresent ){ popC = 1.0; }

      if( popC > def.EPS )
      {
        var expense : f64 = 0.0;
        var revenue : f64 = 0.0;
        var profit  : f64 = 0.0;

        // Calculating revenues and expenses
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );
          const resP = econ.resState.get( .PRICE, resT );

          if( isPresent )
          {
            expense += resP * self.popResFlowData.get( popT, .OPR_CONS, resT );
            revenue += resP * self.popResFlowData.get( popT, .OPR_PROD, resT );
          }
          else // Theoritical profitability calculations
          {
            expense += resP * popT.getResMetric_f64( .CONS, resT );
            revenue += resP * popT.getResMetric_f64( .PROD, resT );
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
        const prevSavings = econ.popState.get( .SAVINGS, popT );

        if( isPresent )
        {
          const nextSavings = prevSavings + profit;

          // NOTE : Expenses and revenues are logged per unit for ease of comparison, but stored as totals
          def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t| {d:.1}\t| +{d:.4}\t-{d:.4}\t| {d:.4}", .{ @tagName( popT ), popC, nextSavings, revenue / popC, expense / popC, margin });

          econ.popState.set( .EXPENSE,  popT, expense     );
          econ.popState.set( .REVENUE,  popT, revenue     );
          econ.popState.set( .SAVINGS,  popT, nextSavings );
        }
        else
        {
          def.log( .CONT, 0, @src(), "{s}\t: 0\t| {d:.1}\t| +N/A\t-N/A\t| {d:.4}", .{ @tagName( popT ), prevSavings, margin});

          econ.popState.zero( .EXPENSE,  popT );
          econ.popState.zero( .REVENUE,  popT );

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
      const indT = IndType.fromIdx( d );
      var   indC = econ.indState.get( .COUNT, indT );

      const isPresent : bool = ( indC > def.EPS );
      if( !isPresent ){ indC = 1.0; }

      if( indT.canBeBuiltIn( econ.location, econ.hasAtmo ))
      {
        var expense : f64 = 0.0;
        var revenue : f64 = 0.0;
        var profit  : f64 = 0.0;

        // Calculating revenues and expenses
        inline for( 0..resTypeC )| r |
        {
          const resT = ResType.fromIdx( r );
          const resP = econ.resState.get( .PRICE, resT );

          if( isPresent )
          {
            // NOTE : ignore build costs, as those are one-time payments from savings
            expense += resP * self.indResFlowData.get( indT, .OPR_CONS, resT );
            expense += resP * self.indResFlowData.get( indT, .MNT_CONS, resT );

            revenue += resP * self.indResFlowData.get( indT, .TOT_PROD, resT );
          }
          else // Theoritical profitability calculations
          {
            expense += resP * indT.getResMetric_f64( .CONS,  resT );
            expense += resP * indT.getResMetric_f64( .MAINT, resT );

            revenue += resP * indT.getResMetric_f64( .PROD,  resT );
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

        econ.indState.set( .ACT_TRGT, indT, activityTarget ); // To be used next tick

        // Updating econ metrics
        const prevCapital = econ.indState.get( .SAVINGS, indT );

        if( isPresent )
        {
          const nextCapital = prevCapital + profit;

          // NOTE : Expenses and revenues are logged per unit for ease of comparison, but stored as totals
          def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t| {d:.1}\t| +{d:.4}\t-{d:.4}\t| {d:.4}\t{d:.4}%", .{ @tagName( indT ), indC, nextCapital, revenue / indC, expense / indC, margin, activityTarget * 100.0 });

          econ.indState.set( .EXPENSE,  indT, expense     );
          econ.indState.set( .REVENUE,  indT, revenue     );
          econ.indState.set( .SAVINGS,  indT, nextCapital );
        }
        else
        {
          def.log( .CONT, 0, @src(), "{s}\t: 0\t| {d:.1}\t| +N/A\t-N/A\t| {d:.4}\t{d:.4}%", .{ @tagName( indT ), prevCapital, margin, activityTarget * 100.0 });

          econ.indState.zero( .EXPENSE,  indT );
          econ.indState.zero( .REVENUE,  indT );

          // TODO : transfer capital to gov if non-zero ( industry may have gone insolvent )
        }
      }
      else // This industry cannot be built in this econ
      {
        //NOTE : Ensures all these are zero. to trivially void all "This industry would be profitable here" signaling

        econ.indState.zero( .ACT_TRGT, indT );
        econ.indState.zero( .EXPENSE,  indT );
        econ.indState.zero( .REVENUE,  indT );

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
      const popT = PopType.fromIdx( p );
      const popC = self.econ.popState.get( .COUNT, popT );

      if( popC > def.EPS )
      {
        def.log( .INFO, 0, @src(), "$ LOGGING POP FACTORS ({s}) :", .{ @tagName( popT )});

        const baseFatality = popT.getMetric_f64( .FATALITY );
        const baseNatality = popT.getMetric_f64( .NATALITY );


        // ================ MORTALITY ================
        // Base fatality ( natural causes ) + starvation mortality

        var maxStarveRate : f64 = 0.0;
        var minResAccess  : f64 = 1.0;

        def.qlog( .CONT, 0, @src(), "Access rates  : " );

        for( 0..resTypeC )| r |
        {
          const resT     = ResType.fromIdx( r );
          const mortRate = popT.getResMetric_f64( .MORT, resT );

          if( mortRate > def.EPS )
          {
            const access = self.grpResFlowData.get( .POP, .OPR_ACS, resT );
            minResAccess = @min( minResAccess, access );

            def.log( .CONT, 0, @src(), "- {s}\t : {d:.4}", .{ @tagName( resT ), access });

            if( access < 1.0 )
            {
              def.log( .CONT, 0, @src(), "@ Experiencing {s} shortages !", .{ @tagName( resT ) });

              maxStarveRate = @max( maxStarveRate, mortRate * def.pow( f64, 1.0 - access, RES_MODIFIER_EXPONENT ));
            }
          }
        }
        const starved = @floor( popC * maxStarveRate );

        avgPopStarveRate += maxStarveRate;

        def.log( .CONT, 0, @src(), "Starve Rate  : {d:.6}", .{ maxStarveRate });


        const deathRate = baseFatality + maxStarveRate;
        const deaths    = @floor( popC * deathRate );

        avgPopDeathRate += deathRate;

        def.log( .CONT, 0, @src(), "Death Rate   : {d:.6}", .{ deathRate });


        // ================ NATALITY ================
        // Growth only occurs in the fraction of the population that has full resource access
        // Modified by resource abundance and job availability

        const resModifier = @min( def.pow( f64,    minResAccess, 1.0 / RES_MODIFIER_EXPONENT ), MAX_RES_MODIFIER );
        const jobModifier = @min( def.pow( f64, 1.0 / jobAccess, 1.0 / JOB_MODIFIER_EXPONENT ), MAX_JOB_MODIFIER );

        const birthRate   = baseNatality * resModifier * jobModifier;
        const birtherRate = 1.0 - deathRate;
        const births      = @ceil( popC * birtherRate * birthRate );

        avgPopBirthRate += birthRate;

        def.log( .CONT, 0, @src(), "Birth Rate   : {d:.6}", .{ birthRate });
        def.log( .CONT, 0, @src(), "Res Modifier : {d:.8}", .{ resModifier });
        def.log( .CONT, 0, @src(), "Job Modifier : {d:.8}", .{ jobModifier });


        // ================ POP DELTA ================

        const popCap : f64 = @floatFromInt( self.econ.getPopCap( popT ));

        const nextPop = def.clmp( popC + births - deaths, 0.0, popCap );

        def.log( .CONT, 0, @src(), "New Pop count : {d:.0}", .{ nextPop });


        // Push pop metrics to econ
        self.econ.popState.set( .COUNT,  popT, nextPop );
        self.econ.popState.set( .STARVE, popT, starved );
        self.econ.popState.set( .DEATH,  popT, deaths  );
        self.econ.popState.set( .BIRTH,  popT, births  );
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
      const resT = ResType.fromIdx( r );

      const oldStk = self.econ.resState.get(  .COUNT,   resT );
      const newStk = self.resStockData.get(   .FINAL,   resT );
      const oldAcs = self.econ.resState.get(  .ACCESS,  resT );
      const newAcs = self.genResFlowData.get( .OPR_ACS, resT );

      econ.resState.set( .COUNT,     resT, @max( 0.0, newStk ));
      econ.resState.set( .COUNT_D,   resT,   newStk - oldStk );
      econ.resState.set( .ACCESS,    resT, @max( 0.0, newAcs ));
      econ.resState.set( .ACCESS_D,  resT,   newAcs - oldAcs );

      avgGenResAccess += self.genResFlowData.get(       .OPR_ACS, resT );
      avgPopResAccess += self.grpResFlowData.get( .POP, .OPR_ACS, resT );
    //avgInfResAccess += self.grpResFlowData.get( .INF, .OPR_ACS, resT );
      avgIndResAccess += self.grpResFlowData.get( .IND, .OPR_ACS, resT );
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

    var avgPopFlm : f64 = 0.0;
    var avgInfUse : f64 = 0.0;
    var avgIndAct : f64 = 0.0;


    inline for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );
      avgPopFlm += self.econ.popState.get( .FLM_LVL, popT );
    }

    avgPopFlm /= @floatFromInt( popTypeC );
    econ.agtState.set( .POP, .ACTION, avgPopFlm );


    inline for( 0..infTypeC )| f |
    {
      const infT = InfType.fromIdx( f );
      avgInfUse += self.econ.infState.get( .USE_LVL, infT );
    }

    avgInfUse /= @floatFromInt( infTypeC );
    econ.agtState.set( .INF, .ACTION, avgInfUse );


    inline for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );
      avgIndAct += self.econ.indState.get( .ACT_LVL, indT );
    }

    avgIndAct /= @floatFromInt( indTypeC );
    econ.agtState.set( .IND, .ACTION, avgIndAct );
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
    def.qlog( .CONT, 0, @src(), "$ =================================================================================" );

    inline for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );
      const popC = self.econ.popState.get( .COUNT,  popT );
      const popL = self.econ.popState.get( .LIMIT,  popT );

      const births  : f64 = self.econ.popState.get( .BIRTH,  popT );
      const deaths  : f64 = self.econ.popState.get( .DEATH,  popT );
      const starved : f64 = self.econ.popState.get( .STARVE, popT );
      const delta   : f64 = births - deaths;

      const flmLvl  : f64 = self.econ.popState.get( .FLM_LVL, popT ) * 100;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t/ {d:.0}\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t( -{d:.0}\t)] {d:.3}%",
        .{ @tagName( popT ), popC, popL, delta, births, deaths, starved, flmLvl });
    }
  }

  pub inline fn logInfMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ INFRASTRUCTURE : Count ( Bonus )  [ Delta ]  Usage rate" );
    def.qlog( .CONT, 0, @src(), "$ =======================================================" );

    inline for( 0..infTypeC )| f |
    {
      const infT = InfType.fromIdx( f );
      const infC = self.econ.infState.get( .COUNT,   infT );

      const built  : f64 = self.econ.infState.get( .BUILT,   infT );
      const destr  : f64 = self.econ.infState.get( .DESTR,   infT );
      const delta  : f64 = built - destr;

      const bonus  : f64 = infC * infT.getMetric_f64( .CAPACITY );
      const useLvl : f64 = self.econ.infState.get( .USE_LVL, infT ) * 100.0;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t( +{d:.0}\t) [ {d:.0}\t] {d:.2}%",
        .{ @tagName( infT ), infC, bonus, delta, useLvl });
    }
  }

  pub inline fn logIndMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ INDUSTRY : Count  [ Delta ]  Activity rate / Target rate" );
    def.qlog( .CONT, 0, @src(), "$ ========================================================" );
    inline for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );
      const indC = self.econ.indState.get( .COUNT, indT );

      const built : f64 = self.econ.indState.get( .BUILT, indT );
      const destr : f64 = self.econ.indState.get( .DESTR, indT );
      const delta : f64 = built - destr;

      const actLvl    : f64 = self.econ.indState.get( .ACT_LVL,  indT ) * 100;
      const actTarget : f64 = self.econ.indState.get( .ACT_TRGT, indT ) * 100;

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0} \t[ {d:.0}\t] {d:.2}%\t/ {d:.2}%",
        .{ @tagName( indT ), indC, delta, actLvl, actTarget });
    }
  }

  pub inline fn logResMetrics( self : *const EconSolver ) void
  {
    def.qlog( .INFO, 0, @src(), "$ RESOURCE : Count / Capacity  [ Delta | Prod Cons Decay ]  Access  ( Price )" );
    def.qlog( .CONT, 0, @src(), "$ ===========================================================================" );

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resC = self.econ.resState.get( .COUNT, resT );
      const resL = self.econ.resState.get( .LIMIT, resT );
      const resP = self.econ.resState.get( .PRICE, resT );

      const prod   : f64 = self.genResFlowData.get( .TOT_PROD, resT );
      const cons   : f64 = self.genResFlowData.get( .TOT_CONS, resT );
      const decay  : f64 = self.resStockData.get(   .DECAY,    resT );
      const delta  : f64 = prod - cons;

      const avgAcs : f64 = self.genResFlowData.get( .OPR_ACS, resT );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t/ {d:.0}\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t-{d:.0}\t] {d:.3} \t ( {d:.6} )",
        .{ @tagName( resT ), resC, resL, delta, prod, cons, decay, avgAcs, resP });
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
    const resT = ResType.fromIdx( r );
    const cons = tmpSolver.genResFlowData.get( .OPR_CONS, resT );
    const prod = tmpSolver.genResFlowData.get( .OPR_PROD, resT );

    const delta = prod - cons;

    var ratio : f64 = 0.0;
    if( prod > def.EPS ){ ratio = delta / prod; }

    def.log( .CONT, 0, @src(), "{s}  \t| +{d:.0}\t-{d:.0}\t= {d:.0}\t( {d:.2}% )", .{ @tagName( resT ), prod, cons, delta, ratio * 100.0 });
  }

  def.qlog( .INFO, 0, @src(), "# POP PROFITABILITY :" );

  inline for( 0..popTypeC )| p |
  {
    const popT = PopType.fromIdx( p );
    const popC = econ.popState.get( .COUNT, popT );

    var expense : f64 = 0.0;
    var revenue : f64 = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      expense += resP * tmpSolver.popResFlowData.get( popT, .OPR_CONS, resT );
      revenue += resP * tmpSolver.popResFlowData.get( popT, .OPR_PROD, resT );
    }

    const profit = revenue - expense;

    var margin : f64 = 0.0;
    if( revenue > def.EPS ){ margin = profit / revenue; }

    def.log( .CONT, 0, @src(), "{s}\t : {d:.0}\t| +{d:.0}\t-{d:.0}\t= {d:.0}\t( {d:.2}% )", .{ @tagName( popT ), popC, revenue, expense, profit, margin * 100.0 });
  }

  def.qlog( .INFO, 0, @src(), "# IND PROFITABILITY :" );

  inline for( 0..indTypeC )| d |
  {
    const indT = IndType.fromIdx( d );
    const indC = econ.indState.get( .COUNT, indT );

    var expense : f64 = 0.0;
    var revenue : f64 = 0.0;

    inline for ( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx(r);
      const resP = econ.resState.get(.PRICE, resT);

      expense += resP * tmpSolver.indResFlowData.get( indT, .OPR_CONS, resT );
      revenue += resP * tmpSolver.indResFlowData.get( indT, .OPR_PROD, resT );
    }

    // Add maintenance cost
    const partPrice = econ.resState.get(        .PRICE, .PART );
    const mntCost   = indT.getResMetric_f64( .MAINT, .PART );
    const mntCosts  = indC * mntCost * partPrice;

    const profit = revenue - ( expense + mntCosts );

    var margin : f64 = 0.0;
    if( revenue > def.EPS ){ margin = profit / revenue; }

    def.log( .CONT, 0, @src(), "{s}\t : {d:.0}\t| +{d:.0}\t-{d:.0}\t-{d:.0}\t= {d:.0}\t( {d:.2}% )", .{ @tagName( indT ), indC, revenue, expense, mntCosts, profit, margin * 100.0 });
  }

//tmpSolver.logAllMetrics();
}


