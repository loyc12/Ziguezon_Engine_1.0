const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const ind = @import( "industry.zig" );
const res = @import( "resource.zig" );

const ecn = @import( "economy.zig" );


const resTypeCount = res.resTypeCount;
const infTypeCount = inf.infTypeCount;
const indTypeCount = ind.indTypeCount;

const ResType = res.ResType;
const InfType = inf.InfType;
const IndType = ind.IndType;

const ResInstance = res.ResInstance;
const InfInstance = inf.InfInstance;
const IndInstance = ind.IndInstance;


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
  econ : *ecn.Economy,

  prevPopCount  : f32 = 0.0,
  nextPopCount  : f32 = 0.0,

  // Global consumption-production throttles / multipliers
  maxGenAccess  : f32 = 1.0,
  maxPopAccess  : f32 = 1.0,
  maxIndAccess  : f32 = 1.0,
  maxIndActivity: f32 = 1.0,

  sunshineModifier : f32 = 1.0,
  natureModifier   : f32 = 1.0,



  // NOTE : Remove redundant zeroing if this becomes a performance bottleneck

  maxPopCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  maxPopProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  maxIndCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  maxIndProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  maxGenCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  maxGenProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),


  popAccess  : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Population resource access ratios
  indAccess  : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Industrial resource access ratios ( aggregated )
  genAccess  : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Aggregated resource access ratios

  indActivity : [ indTypeCount ]f32 = std.mem.zeroes([ indTypeCount ]f32 ), // Industrial activity ratios

  perIndCons  : [ indTypeCount ][ resTypeCount ]u64 = std.mem.zeroes([ indTypeCount ][ resTypeCount ]u64 ),
  perIndProd  : [ indTypeCount ][ resTypeCount ]u64 = std.mem.zeroes([ indTypeCount ][ resTypeCount ]u64 ),


  finalPopCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  finalPopProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  finalIndCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  finalIndProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  finalGenCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  finalGenProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),


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
    self.prevPopCount = @floatFromInt( self.econ.popCount );
    self.nextPopCount = self.prevPopCount;

    self.econ.resetCountMetrics();
  }

  fn applyResDecay( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "Logging natural resource decay :" );

    inline for( 0..resTypeCount )| r |
    {
      if( self.econ.resBank[ r ] != 0 )
      {
        const resType   = ResType.fromIdx( r );
        const decayRate = resType.getDecayRate();

        const decay_f32 : f32 = @floatFromInt( self.econ.resBank[ r ]);
        const decay_u64 : u64 = @intFromFloat( @floor( decay_f32 * decayRate ));

        self.econ.resBank[ r ]     -= decay_u64;
        self.econ.prevResDecay[ r ] = decay_u64;

      //def.log( .CONT, 0, @src(), "{s}  \t: -{d}", .{ @tagName( ResType.fromIdx( r )), decay_u64 });
      }
    }
  }

  fn applyResGrowth( self : *EconSolver ) void
  {
    const ecoFactor = self.econ.getEcologyFactor();

  //def.qlog( .DEBUG, 0, @src(), "Logging natural resource growth :" );

    inline for( 0..resTypeCount )| r |
    {
      const resType  = ResType.fromIdx( r );
      const growRate = resType.getGrowthRate();

      if( growRate >= def.EPS ) // Most res do not grow. Skipping those
      {
        const grow_u64 : u64 = @intFromFloat( ecoFactor * ecoFactor * growRate );

        self.econ.resBank[ r ]      += grow_u64;
        self.econ.prevResGrowth[ r ] = grow_u64;

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}", .{ @tagName( ResType.fromIdx( r ) ), grow_u64 });
      }

    }
  }

  fn calcPopNeeds( self : *EconSolver ) void
  {
  //def.log( .DEBUG, 0, @src(), "Logging population prod. and cons. ({d:.0}) :", .{ self.prevPopCount });

    inline for( 0..resTypeCount )| r |
    {
      const resType = ResType.fromIdx( r );
      const delta   = self.prevPopCount * resType.getPerPopDelta();

      if( delta > def.EPS ) // If res produced
      {
        const maxProd : u64 = @intFromFloat( @floor( delta ));

        self.maxPopProd[ r ]  = maxProd;
        self.maxGenProd[ r ] += maxProd;

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}", .{ @tagName( ResType.fromIdx( r )), maxProd });
      }
      else if( delta < -def.EPS ) // If res consumed
      {
        const maxCons : u64 = @intFromFloat( @floor( -delta ));

        self.maxPopCons[ r ]  = maxCons;
        self.maxGenCons[ r ] += maxCons;

      //def.log( .CONT, 0, @src(), "{s}  \t: -{d}", .{ @tagName( ResType.fromIdx( r )), maxCons });
      }
    }
  }

  fn calcIndNeeds( self : *EconSolver ) void
  {
    inline for( 0..indTypeCount )| d |{ if( self.econ.indBank[ d ] != 0 ) // Skips absent industries
    {
      const indType = IndType.fromIdx( d );
      const inst    = IndInstance.initByType( indType ); // TODO : use a static comptime table if this is a performance bottleneck

    //def.log( .DEBUG, 0, @src(), "Logging bank amounts for {s} ({d}):", .{ @tagName( indType ), self.econ.indBank[ d ]});

      inline for ( 0..resTypeCount )| r |
      {
        const resType = ResType.fromIdx( r );

        var maxProd = self.econ.indBank[ d ] * inst.getResProdPerInd( resType );
        var maxCons = self.econ.indBank[ d ] * inst.getResConsPerInd( resType );

        if( inst.powerSrc == .SOLAR ) // Limits activity based on available sunshine
        {
          const maxProd_f32 : f32 = @floatFromInt( maxProd );
          const maxCons_f32 : f32 = @floatFromInt( maxCons );

          maxProd = @intFromFloat( @floor( maxProd_f32 * self.econ.sunAccess ));
          maxCons = @intFromFloat( @floor( maxCons_f32 * self.econ.sunAccess ));
        }

        self.perIndProd[ d ][ r ] = maxProd;
        self.maxIndProd[ r ]     += maxProd;
        self.maxGenProd[ r ]     += maxProd;

        self.perIndCons[ d ][ r ] = maxCons;
        self.maxIndCons[ r ]     += maxCons;
        self.maxGenCons[ r ]     += maxCons;

      //def.log( .CONT, 0, @src(), "{s}  \t: +{d}\t-{d}", .{ @tagName( resType ), maxProd, maxCons  });
      }
    }}


  //def.qlog( .DEBUG, 0, @src(), "Logging industrial resource prod. and cons. :" );

  //inline for ( 0..resTypeCount )| r | // NOTE : DEBUG INFO
  //{
  //  const maxProd = self.maxIndProd[ r ];
  //  const maxCons = self.maxIndCons[ r ];

  //  def.log( .CONT, 0, @src(), "{s}  \t: +{d}\t-{d}", .{ @tagName( ResType.fromIdx( r ) ), maxProd, maxCons  });
  //}
  }

  fn calcResAccess( self : *EconSolver ) void // TODO : Tweak population vs industry access ratio here if need be
  {
    // Skips WORK res, as it is calc later
    def.qlog( .DEBUG, 0, @src(), "Logging resource availabilities and requirements :" );

    inline for( 0..resTypeCount )| r |{ if( ResType.fromIdx( r ) != .WORK ) // Skipping WORK ( see calcWorkAccess() )
    {
      const available : f32 = @floatFromInt( self.econ.resBank[ r ]);
      const required  : f32 = @floatFromInt( self.maxGenCons[   r ]);

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t-{d}", .{ @tagName( ResType.fromIdx( r )), available, required });

      if( @abs( required ) < def.EPS )
      {
        self.popAccess[ r ] = self.maxPopAccess;
        self.indAccess[ r ] = self.maxIndAccess;
        self.genAccess[ r ] = self.maxGenAccess;

        // Updating economy metrics
        self.econ.resAccess[ r ] = self.maxGenAccess;
      }
      else
      {
        const maxAccess = available / required;

        // If res is needed by EITHER pop or ind ( not both ), have mark the other as fully supplied
        if( self.maxPopCons[ r ] > 0 ){ self.popAccess[ r ] = @min( self.maxPopAccess, maxAccess ); }
        else                          { self.popAccess[ r ] =       self.maxPopAccess;              }

        if( self.maxIndCons[ r ] > 0 ){ self.indAccess[ r ] = @min( self.maxIndAccess, maxAccess ); }
        else                          { self.indAccess[ r ] =       self.maxIndAccess;              }

        self.genAccess[ r ] = @min( self.maxGenAccess, maxAccess );

        if( maxAccess < 1.0 )
        {
          def.log( .CONT, 0, @src(), "@ {s} shortage", .{ @tagName( ResType.fromIdx( r ))});
        }

        // Updating economy metrics
        self.econ.resAccess[ r ] = maxAccess;
      }
    }}
  }

  fn applyWorkWeek( self : *EconSolver ) void // TODO : If some industries produce work, produce it here too
  {
    const workIdx = ResType.WORK.toIdx();

    var minPopAccess = self.maxPopAccess;

    inline for( 0..resTypeCount )| r |{ if( ResType.fromIdx( r ) != .WORK ) // Skipping WORK ( see calcWorkAccess )
    {
      minPopAccess = @min( minPopAccess, self.popAccess[ r ]);
    }}

    const popWorkRate = @max( minPopAccess, MIN_WORK_RATE ); // Clamping pop work rates to a minimum to prevent total supply chain collapse

    const rawWorkProd   : f32 = @floatFromInt( self.maxPopProd[ workIdx ]);
    const weeklyPopWork : u64 = @intFromFloat( @floor( popWorkRate * rawWorkProd ));

    def.log( .CONT, 0, @src(), "# WORK rate\t: {d:.4}", .{ popWorkRate });


    self.finalPopProd[ workIdx ] = weeklyPopWork;
    self.finalGenProd[ workIdx ] = weeklyPopWork;
  }

  fn calcWorkAccess( self : *EconSolver ) void
  {
    // Like calcResAccess() + applyResDelta(), but only for work, since we need other res to calculate work prod

    const workIdx = ResType.WORK.toIdx();

    const available : f32 = @floatFromInt( self.finalPopProd[ workIdx ]); // + self.econ.resBank[ workIdx ]);
    const required  : f32 = @floatFromInt( self.maxGenCons[   workIdx ]);

    def.log( .CONT, 0, @src(), "WORK  \t: {d}\t-{d}", .{ available, required });

    self.popAccess[ workIdx ] = self.maxPopAccess; // POP will never need work, so access is always maxed

    if( @abs( required ) < def.EPS ) // If WORK is somehow not needed, mark it as fully supplied
    {
      self.indAccess[ workIdx ] = self.maxIndAccess;
      self.genAccess[ workIdx ] = self.maxGenAccess;

      // Updating economy metrics
      self.econ.resAccess[ workIdx ] = self.maxGenAccess;
    }
    else
    {
      const maxAccess = available / required;

      self.indAccess[ workIdx ] = @min( self.maxIndAccess, maxAccess );
      self.genAccess[ workIdx ] = @min( self.maxGenAccess, maxAccess );

      if( maxAccess < 1.0 )
      {
        def.qlog( .CONT, 0, @src(), "@ WORK shortage" );
      }

      // Updating economy metrics
      self.econ.resAccess[ workIdx ] = maxAccess;
    }
  }

  fn calcIndActivity( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "Logging industrial activity :" );

    inline for( 0..indTypeCount )| d |
    {
      var activity : f32 = self.maxIndActivity;

      if( self.econ.indBank[ d ] == 0 ) // Skips absent industries
      {
        activity = 0.0;
      }
      else
      {
        // NOTE : Sunshine ratio effect moved to maxResProd phase, to avoid planning for impossible supplies

        inline for( 0..resTypeCount )| r |
        {
          if( self.perIndCons[ d ][ r ] != 0 ) // Non consumed resources do not affect industrial activity
          {
            activity = @min( activity, self.indAccess[ r ]);
          }
        }
      }
      self.indActivity[ d ] = activity ;

      // Updating economy metrics
      self.econ.indActivity[ d ] = activity;
    }
  }

  fn applyResDelta( self : *EconSolver ) void
  {
  //def.qlog( .DEBUG, 0, @src(), "Logging general resource prod. and cons. :" );

    inline for( 0..resTypeCount )| r |
    {
      // Iterating over population
      const popResAccess = self.popAccess[ r ];

      const resType = ResType.fromIdx( r );

      if( popResAccess > def.EPS and resType != .WORK ) // Skipping WORK ( see applyWorkWeek() )
      {
        // Production ( nothing for now )
        const rawPopProd   : f32 = @floatFromInt( self.maxPopProd[ r ]);
        const finalPopProd : u64 = @intFromFloat( @floor( rawPopProd * popResAccess ));

        self.finalPopProd[ r ]  = finalPopProd;
        self.finalGenProd[ r ] += finalPopProd;

        // Consumption ( FOOD, WATER, POWER )
        const rawPopCons   : f32 = @floatFromInt( self.maxPopCons[ r ]);
        const finalPopCons : u64 = @intFromFloat( @floor( rawPopCons * popResAccess ));

        self.finalPopCons[ r ]  = finalPopCons;
        self.finalGenCons[ r ] += finalPopCons;
      }

      // Iterating over industry
      inline for( 0..indTypeCount )| d |
      {
        const indActivity = self.indActivity[ d ];

        if( indActivity > def.EPS )
        {
          // Production
          if( resType != .WORK ) // Skipping WORK ( see applyWorkWeek() )
          {
            const rawIndProd   : f32 = @floatFromInt( self.perIndProd[ d ][ r ]);
            const finalIndProd : u64 = @intFromFloat( @floor( rawIndProd * indActivity ));

            self.finalIndProd[ r ] += finalIndProd;
            self.finalGenProd[ r ] += finalIndProd;
          }

          // Consumption
          const rawIndCons   : f32 = @floatFromInt( self.perIndCons[ d ][ r ]);
          const finalIndCons : u64 = @intFromFloat( @floor( rawIndCons * indActivity ));

          self.finalIndCons[ r ] += finalIndCons;
          self.finalGenCons[ r ] += finalIndCons;
        }
      }

    //def.log( .CONT, 0, @src(), "{s}  \t: {d}\t( +{d}\t-{d} )", .{ @tagName( ResType.fromIdx( r )), econ.resBank[ r ], self.finalGenProd[ r ], self.finalGenCons[ r ] });

      // Updating economy metrics and storage
      const econ = self.econ;

      econ.prevResReq[ r ] = self.maxGenCons[ r ];

      econ.prevResProd[ r ] = self.finalGenProd[ r ];
      econ.prevResCons[ r ] = self.finalGenCons[ r ];

      econ.addResCount( resType, self.finalGenProd[ r ]);
      econ.subResCount( resType, self.finalGenCons[ r ]);

      econ.resDelta[ r ] += @intCast( self.finalGenProd[ r ]);
      econ.resDelta[ r ] -= @intCast( self.finalGenCons[ r ]);
    }
  }


  fn applyPopDelta( self : *EconSolver ) void
  {
    // NOTE : Iterates over pop-consumed res only

    var deaths : f32 = 0.0;
    var births : f32 = 0.0;

    // FOOD access
    const foodIdx  = ResType.FOOD.toIdx();
    var foodAccess = self.maxPopAccess;

    foodAccess = @min( foodAccess, self.popAccess[ foodIdx ]);

    if( foodAccess < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Population is experiencing food shortages !" );

      deaths += self.prevPopCount * def.pow( f32, 1.0 - foodAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_STARVE_RATE;
    }

    // WATER access
    const waterIdx  = ResType.WATER.toIdx();
    var waterAccess = self.maxPopAccess;

    waterAccess = @min( waterAccess, self.popAccess[ waterIdx ]);

    if( waterAccess < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Population is experiencing water shortages !" );

      deaths += self.prevPopCount * def.pow( f32, 1.0 - waterAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_PARCH_RATE;
    }

    // POWER access
    const powerIdx  = ResType.POWER.toIdx();
    var powerAccess = self.maxPopAccess;

    powerAccess = @min( powerAccess, self.popAccess[ powerIdx ]);

    if( powerAccess < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Population is experiencing power shortages !" );

      deaths += self.prevPopCount * def.pow( f32, 1.0 - powerAccess, POP_SHORTAGE_EXPONENT ) * WEEKLY_FREEZE_RATE;
    }

    const suppliedRatio = def.pow( f32, @max( @min( foodAccess, waterAccess ), 1.0 ), 1.0 / POP_SHORTAGE_EXPONENT );

    births = self.prevPopCount * suppliedRatio * WEEKLY_POP_GROWTH;

    def.log( .INFO, 0, @src(), "Pop access : F {d:.4}\tW {d:.4}\tP {d:.4}", .{ foodAccess, waterAccess, powerAccess });
    def.log( .CONT, 0, @src(), "Deaths     : {d:.8}", .{ deaths });
    def.log( .CONT, 0, @src(), "Births     : {d:.8}", .{ births });
    def.log( .CONT, 0, @src(), "Supplied   : {d:.8}", .{ suppliedRatio });


    // Updating economy
    const econ = self.econ;

    const popCap : f32 = @floatFromInt( self.econ.getPopCap() );

    const prevPopCount_i64 : i64 = @intFromFloat( self.prevPopCount );
    const nextPopCount_i64 : i64 = @intFromFloat( def.clmp( self.prevPopCount - @floor( deaths ) + @ceil( births ), 0.0, popCap ));

    econ.popCount  = @intCast( nextPopCount_i64 );
    econ.popDelta  = nextPopCount_i64 - prevPopCount_i64;
    econ.popAccess = @min( foodAccess, waterAccess, powerAccess );
  }
};