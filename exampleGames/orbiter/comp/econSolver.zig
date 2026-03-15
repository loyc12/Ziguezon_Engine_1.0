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
const WEEKLY_POP_GROWTH : f32 = 0.0003;

// Pop decay factors
const WEEKLY_PARCH_RATE  : f32 = 0.10;
const WEEKLY_STARVE_RATE : f32 = 0.05;
const WEEKLY_FREEZE_RATE : f32 = 0.02;

const POP_SHORTAGE_EXPONENT : f32 = 2.0; // Smooth out death rates from pop res shortages

const MIN_WORK_RATE : f32 = 0.20;


pub inline fn resolveEcon( econ : *ecn.Economy ) void
{
  var solver : EconSolver = .{ .econ = econ };

  solver.resolve();
}


const EconSolver = struct
{
  // Global consumption-production throttles / multipliers
  maxGenAccess     : f64 = 1.0,
  maxPopAccess     : f64 = 1.0,
  maxIndAccess     : f64 = 1.0,
  maxIndActivity   : f64 = 1.0,

  sunshineModifier : f32 = 1.0,
  natureModifier   : f32 = 1.0,

  // Solver data
  econ : *ecn.Economy,

  prevPopCount : f64 = 0.0,
  nextPopCount : f64 = 0.0,

  resAccessData : ecnm_d.ResAccessData = .{},
//popAccess  : [ resTypeC ]f32 = std.mem.zeroes([ resTypeC ]f32 ), // Population resource access ratios
//indAccess  : [ resTypeC ]f32 = std.mem.zeroes([ resTypeC ]f32 ), // Industrial resource access ratios ( aggregated )
//genAccess  : [ resTypeC ]f32 = std.mem.zeroes([ resTypeC ]f32 ), // Aggregated resource access ratios

  indFlowData : ecnm_d.IndFlowData     = .{}, // Per industry
//perIndCons  : [ indTypeC ][ resTypeC ]u64 = std.mem.zeroes([ indTypeC ][ resTypeC ]u64 ),
//perIndProd  : [ indTypeC ][ resTypeC ]u64 = std.mem.zeroes([ indTypeC ][ resTypeC ]u64 ),

  indActivity : ecnm_d.IndActivityData = .{},
//indActivity : [ indTypeC ]f32 = std.mem.zeroes([ indTypeC ]f32 ), // Industrial activity ratios

  resFlowData : ecnm_d.ResFlowData     = .{}, // Agregated industry
//maxPopCons   : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//maxPopProd   : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//
//maxIndCons   : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//maxIndProd   : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//
//maxGenCons   : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//maxGenProd   : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//
//finalPopCons : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//finalPopProd : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//
//finalIndCons : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//finalIndProd : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//
//finalGenCons : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),
//finalGenProd : [ resTypeC ]u64 = std.mem.zeroes([ resTypeC ]u64 ),


  pub fn resolve( self : *EconSolver ) void
  {
    self.initBaseState();   // TODO : move the zeroing or arrays to here
    self.applyResDecay();   // Decays stored resources from previous weeks
    self.applyResGrowth();  // Grow wild resources based on ecology factor

    self.calcPopNeeds();    // Computes population potential prod and cons
    self.calcIndNeeds();    // Computes industrial potential prod and cons

    self.calcResAccess();   // Computes non-WORK resource access     TODO : add access-tweaking policies / modifiers
    self.applyWorkWeek();   // Precomputes current WORK production to inform industrial WORK access
    self.calcWorkAccess();  // Computes WORK access

    self.calcIndActivity(); // Computes the final activity rate of each industry

    self.applyPopDelta();   // Update population based on access
    self.applyResDelta();   // Update resources based on access
  }


  fn initBaseState( self : *EconSolver ) void
  {
    self.prevPopCount = self.econ.popMetrics.get( .COUNT );
    self.nextPopCount = self.prevPopCount;

    // Zero solver scratch
    self.resAccessData.fillWith(   0.0 );
    self.indFlowData.fillWith(       0 );
    self.indActivity.fillWith( 0.0 );
    self.resFlowData.fillWith(       0 );

    self.econ.resetCountMetrics();
  }

  fn applyResDecay( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "Logging natural resource decay :" );

    inline for( 0..resTypeC )| r |
    {
      const resType  = ResType.fromIdx( r );
      const resBank  = self.econ.resState.get( .BANK, resType );

      if( resBank > 0.0 )
      {
        const decayRate = resType.getMetric_f64( .DECAY_RATE );
        const decay     = resBank * decayRate;

        // Update economy state
        self.econ.resState.sub( .BANK,  resType, decay );
        self.econ.resState.set( .DECAY, resType, decay );

        // Store in flow data as natural consumption ( not included in .GEN )
        self.resFlowData.set( .NAT, .REAL_CONS, resType, @intFromFloat( decay ));

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
        const growth = ecoFactor * ecoFactor * growRate;

        // Update economy state
        self.econ.resState.add( .BANK,   resType, growth );
        self.econ.resState.set( .GROWTH, resType, growth );

        // Store in flow data as natural production ( not included in .GEN )
        self.resFlowData.set( .NAT, .REAL_PROD, resType, @intFromFloat( growth ));

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}", .{ @tagName( ResType.fromIdx( r )), grow_u64 });
      }

    }
  }

  fn calcPopNeeds( self : *EconSolver ) void
  {
  //def.log( .DEBUG, 0, @src(), "Logging population prod. and cons. ({d:.0}) :", .{ self.prevPopCount });

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const maxProd = self.prevPopCount * resType.getMetric_f64( .POP_PROD );
      const maxCons = self.prevPopCount * resType.getMetric_f64( .POP_CONS );

      if( maxProd > def.EPS ) // If res produced
      {
        const maxProd_u64 : u64 = @intFromFloat( @floor( maxProd ));

        self.resFlowData.set( .POP, .MAX_PROD, resType, maxProd_u64 );

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}", .{ @tagName( ResType.fromIdx( r )), maxProd });
      }
      if( maxCons > def.EPS ) // If res consumed
      {
        const maxCons_u64 : u64 = @intFromFloat( @floor( maxCons ));

        self.resFlowData.set( .POP, .MAX_CONS, resType, maxCons_u64 );

      //def.log( .CONT, 0, @src(), "{s}  \t: -{d}", .{ @tagName( ResType.fromIdx( r )), maxCons });
      }
    }
  }

  fn calcIndNeeds( self : *EconSolver ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount = self.econ.indState.get( .BANK, indType );

    //def.log( .DEBUG, 0, @src(), "Logging bank amounts for {s} ({d}):", .{ @tagName( indType ), self.econ.indBank[ d ]});

      if( indCount > def.EPS ){ inline for ( 0..resTypeC )| r | // Skip absent industries
      {
        const resType = ResType.fromIdx( r );

        var maxProd = indCount * indType.getResProd_f64( resType );
        var maxCons = indCount * indType.getResCons_f64( resType );

        if( indType.getPowerSrc() == .SOLAR )
        {
          maxProd *= @floatCast( self.econ.sunAccess );
          maxCons *= @floatCast( self.econ.sunAccess );
        }

        const maxProd_u64 : u64 = @intFromFloat( @floor( maxProd ));
        const maxCons_u64 : u64 = @intFromFloat( @ceil(  maxCons ));

        // Per-industry flow
        self.indFlowData.set( indType, .MAX_PROD, resType, maxProd_u64 );
        self.indFlowData.set( indType, .MAX_CONS, resType, maxCons_u64 );

        // Aggregate into IND agent
        self.resFlowData.add( .IND, .MAX_PROD, resType, maxProd_u64 );
        self.resFlowData.add( .IND, .MAX_CONS, resType, maxCons_u64 );

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}\t-{d}", .{ @tagName( resType ), maxProd_u64, maxCons_u64  });
      }}
    }


  //def.qlog( .DEBUG, 0, @src(), "Logging industrial resource prod. and cons. :" );

  //inline for ( 0..resTypeC )| r | // NOTE : DEBUG INFO
  //{
  //  const maxProd = self.maxIndProd[ r ];
  //  const maxCons = self.maxIndCons[ r ];

  //  def.log( .CONT, 0, @src(), "{s}  \t: +{d}\t-{d}", .{ @tagName( ResType.fromIdx( r ) ), maxProd, maxCons  });
  //}
  }

  fn calcResAccess( self : *EconSolver ) void // TODO : Tweak population vs industry access ratio here if need be
  {
    def.qlog( .DEBUG, 0, @src(), "Logging resource availabilities and requirements :" );

    inline for( 0..resTypeC )| r |{ if( ResType.fromIdx( r ) != .WORK ) // Skipping WORK ( see calcWorkAccess() )
    {
      const resType = ResType.fromIdx( r );

      // Agregating all production and consumption
      const popMaxProd = self.resFlowData.get( .POP, .MAX_PROD, resType );
      const popMaxCons = self.resFlowData.get( .POP, .MAX_CONS, resType );

      const indMaxProd = self.resFlowData.get( .IND, .MAX_PROD, resType );
      const indMaxCons = self.resFlowData.get( .IND, .MAX_CONS, resType );

      self.resFlowData.add( .GEN, .MAX_PROD, resType, popMaxProd + indMaxProd );
      self.resFlowData.add( .GEN, .MAX_CONS, resType, popMaxCons + indMaxCons );

      // Calculating supply and demand
      const supply : f64 = self.econ.resState.get( .BANK, resType );
      const demand : f64 = @floatFromInt( self.resFlowData.get( .GEN, .MAX_CONS, resType ));

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t-{d:.0}", .{ @tagName( ResType.fromIdx( r )), supply, demand });

      if( @abs( demand ) < def.EPS )
      {
        self.resAccessData.set( .POP, resType, self.maxPopAccess );
        self.resAccessData.set( .IND, resType, self.maxIndAccess );
        self.resAccessData.set( .GEN, resType, self.maxGenAccess );

        self.econ.resState.set( .SAT_LVL, resType, self.maxGenAccess );
      }
      else
      {
        const maxAccess = supply / demand;

        // If res is needed by EITHER pop or ind ( not both ), have mark the other as fully supplied
        if( popMaxCons > 0 ){ self.resAccessData.set( .POP, resType, @min( self.maxPopAccess, maxAccess )); }
        else                { self.resAccessData.set( .POP, resType,       self.maxPopAccess             ); }

        if( indMaxCons > 0 ){ self.resAccessData.set( .IND, resType, @min( self.maxIndAccess, maxAccess )); }
        else                { self.resAccessData.set( .IND, resType,       self.maxIndAccess             ); }

        self.resAccessData.set( .GEN, resType, @min( self.maxGenAccess, maxAccess ));

        if( maxAccess < 1.0 )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage", .{ @tagName( ResType.fromIdx( r ))});
        }

        // Updating economy metrics
        self.econ.resState.set( .SAT_LVL, resType, maxAccess );
      }
    }}
  }

  fn applyWorkWeek( self : *EconSolver ) void // TODO : If some industries produce work, produce it here too
  {
    var minPopAccess : f64 = self.maxPopAccess;

    inline for( 0..resTypeC )| r |{ if( ResType.fromIdx( r ) != .WORK )
    {
      const resType = ResType.fromIdx( r );

      minPopAccess = @min( minPopAccess, self.resAccessData.get( .POP, resType ));
    }}

    const popWorkRate   : f64 = @max( minPopAccess, MIN_WORK_RATE ); // Clamping pop work rates to a minimum to prevent total supply chain collapse
    const rawWorkProd   : f64 = @floatFromInt( self.resFlowData.get( .POP, .MAX_PROD, .WORK ));
    const weeklyPopWork : u64 = @intFromFloat( popWorkRate * rawWorkProd );

    def.log( .CONT, 0, @src(), "# WORK rate\t: {d:.4}", .{ popWorkRate });

    self.resFlowData.set( .POP, .REAL_PROD, .WORK, weeklyPopWork );
    self.resFlowData.add( .GEN, .REAL_PROD, .WORK, weeklyPopWork );
  }

  fn calcWorkAccess( self : *EconSolver ) void
  {
    // Like calcResAccess() + applyResDelta(), but only for work, since we need other res to calculate work prod

    const supply : f64 = @floatFromInt( self.resFlowData.get( .POP, .REAL_PROD, .WORK ));
    const demand : f64 = @floatFromInt( self.resFlowData.get( .IND, .MAX_CONS,  .WORK ));

    def.log( .CONT, 0, @src(), "WORK  \t: {d:.0}\t-{d:.0}", .{ supply, demand });

    self.resAccessData.set( .POP, .WORK, self.maxPopAccess ); // POP will never need work, so access is always maxed

    if( demand < def.EPS ) // If WORK is somehow not needed, mark it as fully supplied
    {
      self.resAccessData.set( .IND, .WORK, self.maxIndAccess );
      self.resAccessData.set( .GEN, .WORK, self.maxGenAccess );

      // Updating economy metrics
      self.econ.resState.set( .SAT_LVL, .WORK, self.maxGenAccess );
    }
    else
    {
      const maxAccess = supply / demand;

      self.resAccessData.set( .IND, .WORK, @min( self.maxIndAccess, maxAccess ));
      self.resAccessData.set( .GEN, .WORK, @min( self.maxGenAccess, maxAccess ));

      if( maxAccess < 1.0 )
      {
        def.qlog( .CONT, 0, @src(), "@ WORK shortage" );
      }

      // Updating economy metrics
      self.econ.resState.set( .SAT_LVL, .WORK, maxAccess );
    }
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

          if( self.indFlowData.get( indType, .MAX_CONS, resType ) != 0 )
          {
            activity = @min( activity, self.resAccessData.get( .IND, resType ));
          }
        }
      }
      self.indActivity.set( indType, @floatCast( activity ));

      // Updating economy metrics
      self.econ.indState.set( .ACT_LVL, indType, @floatCast( activity ));
    }
  }

  fn applyResDelta( self : *EconSolver ) void
  {
    // ================ Industrial pass ================

    inline for( 0..indTypeC )| d |
    {
      const indType            = IndType.fromIdx( d );
      const activity_f64 : f64 = self.indActivity.get( indType );

      if( activity_f64 > def.EPS )
      {
        inline for( 0..resTypeC )| r |
        {
          const resType = ResType.fromIdx( r );

          // ProductionkWeek )
          if( resType != .WORK ) // WORK handled in applyWorkWeek()
          {
            const rawProd : f64 = @floatFromInt( self.indFlowData.get( indType, .MAX_PROD, resType ));
            const finProd : u64 = @intFromFloat( rawProd * activity_f64 );

            self.indFlowData.set( indType, .REAL_PROD, resType, finProd );
            self.resFlowData.add( .IND,    .REAL_PROD, resType, finProd );
          }

          // Consumption
          const rawCons : f64 = @floatFromInt( self.indFlowData.get( indType, .MAX_CONS, resType ));
          const finCons : u64 = @intFromFloat( rawCons * activity_f64 );

          self.indFlowData.set( indType, .REAL_CONS, resType, finCons );
          self.resFlowData.add( .IND,    .REAL_CONS, resType, finCons );
        }
      }
    }
    //def.qlog( .DEBUG, 0, @src(), "Logging general resource prod. and cons. :" );


    // ================ Population + Aplication pass ================

    inline for( 0..resTypeC )| r |
    {
      const resType    = ResType.fromIdx( r );
      const popAccess : f64 = @floatCast( self.resAccessData.get( .POP, resType ));

      if( popAccess > def.EPS and resType != .WORK ) // WORK handled in applyWorkWeek()
      {
        // Production ( Nothing atm )
        const rawPopProd : f64 = @floatFromInt( self.resFlowData.get( .POP, .MAX_PROD, resType ));
        const finPopProd : u64 = @intFromFloat( rawPopProd * popAccess );

        self.resFlowData.set( .POP, .REAL_PROD, resType, finPopProd );

        // Consumption ( FOOD, WATER, POWER )
        const rawPopCons : f64 = @floatFromInt( self.resFlowData.get( .POP, .MAX_CONS, resType ));
        const finPopCons : u64 = @intFromFloat( rawPopCons * popAccess );

        self.resFlowData.set( .POP, .REAL_CONS, resType, finPopCons );
      }

    //def.log( .CONT, 0, @src(), "{s}  \t: {d}\t( +{d}\t-{d} )", .{ @tagName( ResType.fromIdx( r )), econ.resBank[ r ], self.finalGenProd[ r ], self.finalGenCons[ r ] });

      // Agregating all production and consumption
      const popMaxProd = self.resFlowData.get( .POP, .REAL_PROD, resType );
      const popMaxCons = self.resFlowData.get( .POP, .REAL_CONS, resType );

      const indMaxProd = self.resFlowData.get( .IND, .REAL_PROD, resType );
      const indMaxCons = self.resFlowData.get( .IND, .REAL_CONS, resType );

      self.resFlowData.add( .GEN, .REAL_PROD, resType, popMaxProd + indMaxProd );
      self.resFlowData.add( .GEN, .REAL_CONS, resType, popMaxCons + indMaxCons );


      // Updating economy metrics and storage
      const econ = self.econ;

      const totalSup  : f64 = @floatFromInt( self.resFlowData.get( .GEN, .MAX_PROD,  resType ));
      const totalDem  : f64 = @floatFromInt( self.resFlowData.get( .GEN, .MAX_CONS,  resType ));

      const totalProd : f64 = @floatFromInt( self.resFlowData.get( .GEN, .REAL_PROD, resType ));
      const totalCons : f64 = @floatFromInt( self.resFlowData.get( .GEN, .REAL_CONS, resType ));


      econ.resState.set( .MAX_DEM, resType, totalDem  );
      econ.resState.set( .MAX_SUP, resType, totalSup  );

      econ.resState.set( .FIN_SUP, resType, totalProd );
      econ.resState.set( .FIN_DEM, resType, totalCons );

      econ.resState.set( .DELTA, resType, totalProd - totalCons );

      econ.addResCount( resType, @intFromFloat( @floor( totalProd )));
      econ.subResCount( resType, @intFromFloat( @ceil(  totalCons )));

    }
  }


  fn applyPopDelta( self : *EconSolver ) void
  {
    var deaths : f64 = 0.0;
    var births : f64 = 0.0;

    // ================ FOOD ================
    var foodAccess = self.maxPopAccess;
        foodAccess = @min( foodAccess, self.resAccessData.get( .POP, .FOOD ));

    if( foodAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing food shortages ! ( {d:.3} )", .{ foodAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - foodAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_STARVE_RATE;
    }

    // ================  WATER ================
    var waterAccess = self.maxPopAccess;
        waterAccess = @min( waterAccess, self.resAccessData.get( .POP, .WATER ));

    if( waterAccess < 1.0 )
    {
      def.log( .WARN, 0, @src(), "Population is experiencing water shortages ! ( {d:.3} )", .{ waterAccess });

      deaths += self.prevPopCount * def.pow( f64, 1.0 - waterAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_PARCH_RATE;
    }

    // ================ POWER ================
    var powerAccess = self.maxPopAccess;
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