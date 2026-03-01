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


// Pop growth factor ( x4 each century ) // TODO : change min growth of less than 1.0 to chance to grow by 1.0
const WEEKLY_POP_GROWTH  : f32 = 0.000266631;

// Pop decay factors
const WEEKLY_PARCH_RATE  : f32 = 0.15;
const WEEKLY_STARVE_RATE : f32 = 0.05;
const WEEKLY_FREEZE_RATE : f32 = 0.01;

const MIN_WORK_RATE      : f32 = 0.20;


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


  // NOTE : Remove redundant zeroing if this becomes a performance bottleneck

  maxPopCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  maxPopProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  maxIndCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  maxIndProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  maxGenCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  maxGenProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),


//genPopResCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
//genPopResProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

//genIndResCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
//genIndResProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  popAccess   : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Population resource access ratios
  indAccess   : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Industrial resource access ratios ( aggregated )
  genAccess   : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Aggregated resource access ratios

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

    self.calcPopNeeds();    // Computes population potential prod and cons
    self.calcIndNeeds();    // Computes industrial potential prod and cons

    self.calcResAccess();   // Computes non-WORK resource access     TODO : add access-tweaking policies / modifiers
    self.applyWorkWeek();   // Precomputes current WORK production to inform industrial WORK access
    self.calcWorkAccess();  // Computes WORK access

    self.calcIndActivity(); // Computes the final activity rate of each industry

    self.applyResDelta();   // Update resources based on access
    self.applyPopDelta();   // Update population based on access
  }


  fn initBaseState( self : *EconSolver ) void
  {
    self.prevPopCount = @floatFromInt( self.econ.popCount );
    self.nextPopCount = self.prevPopCount;
  }

  fn applyResDecay( self : *EconSolver ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      if( self.econ.resBank[ r ] != 0 )
      {
        const resType = ResType.fromIdx( r );

        const res_f32 : f32 = @floatFromInt( self.econ.resBank[ r ]);

        self.econ.resBank[ r ] -= @intFromFloat( @floor( res_f32 * resType.getDecayRate() ));
      }
    }
  }

  fn calcPopNeeds( self : *EconSolver ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      const resType = ResType.fromIdx( r );
      const delta   = self.prevPopCount * resType.getPerPopDelta();

      if( delta > def.EPS ) // If res produced
      {
        const maxProd : u64 = @intFromFloat( @floor( delta ));

        self.maxPopProd[ r ]  = maxProd;
        self.maxGenProd[ r ] += maxProd;
      }
      else if( delta < -def.EPS ) // If res consumed
      {
        const maxCons : u64 = @intFromFloat( @floor( -delta ));

        self.maxPopCons[ r ]  = maxCons;
        self.maxGenCons[ r ] += maxCons;
      }
    }
  }

  fn calcIndNeeds( self : *EconSolver ) void
  {
    inline for( 0..indTypeCount )| i |
    {
      if( self.econ.indBank[ i ] != 0 ) // Arrays already filled with zeroes, no need to work in double when indCount is 0 as well
      {
        const indType = IndType.fromIdx( i );
        const inst    = IndInstance.initByType( indType ); // TODO : use a static comptime table if this is a performance bottleneck

        inline for ( 0..resTypeCount )| r |
        {
          const resType = ResType.fromIdx( r );

          const maxProd = self.econ.indBank[ i ] * inst.getResProdPerInd( resType );
          const maxCons = self.econ.indBank[ i ] * inst.getResConsPerInd( resType );

          self.perIndProd[ i ][ r ] = maxProd;
          self.maxIndProd[ r ]     += maxProd;
          self.maxGenProd[ r ]     += maxProd;

          self.perIndCons[ i ][ r ] = maxCons;
          self.maxIndCons[ r ]     += maxCons;
          self.maxGenCons[ r ]     += maxCons;
        }
      }
    }
  }

  fn calcResAccess( self : *EconSolver ) void
  {
    // Skips WORK res, as it is calc later
    inline for( 0..resTypeCount )| r |{ if( ResType.fromIdx( r ) != .WORK )
    {
      const available : f32 = @floatFromInt( self.econ.resBank[ r ]);
      const required  : f32 = @floatFromInt( self.maxGenCons[ r ]);


      if( @abs( required ) < def.EPS )
      {
        self.popAccess[ r ] = self.maxPopAccess;
        self.indAccess[ r ] = self.maxIndAccess;
        self.genAccess[ r ] = self.maxGenAccess;
      }
      else
      {
        const maxAccess = available / required;

        // TODO : Tweak population vs industry access ratio here if need be

        // If res is needed by EITHER pop or ind ( not both ), have mark the other as fully supplied
        if( self.maxPopCons[ r ] > 0 ){ self.popAccess[ r ] = @min( self.maxPopAccess, maxAccess ); }
        else                          { self.popAccess[ r ] =       self.maxPopAccess;              }

        if( self.maxIndCons[ r ] > 0 ){ self.indAccess[ r ] = @min( self.maxIndAccess, maxAccess ); }
        else                          { self.indAccess[ r ] =       self.maxIndAccess;              }

        self.genAccess[ r ] = @min( self.maxGenAccess, maxAccess ); // Global res access
      }
    }}
  }

  fn applyWorkWeek( self : *EconSolver ) void
  {
    const workIdx    = ResType.WORK.toIdx();

    var minPopAccess = self.maxPopAccess;

    inline for( 0..resTypeCount )| r |{ if( ResType.fromIdx( r ) != .WORK )
    {
      minPopAccess = @min( minPopAccess, self.popAccess[ r ]);
    }}

    const popWorkRate = @max( minPopAccess, MIN_WORK_RATE ); // Clamping pop work rates to a minimum to prevent total supply chain collapse

    const rawWorkProd   : f32 = @floatFromInt( self.maxPopProd[ workIdx ]);
    const weeklyPopWork : u64 = @intFromFloat( @floor( popWorkRate * rawWorkProd ));


    // TODO : If some industries produce work, produce it here


    self.finalPopProd[ workIdx ] = weeklyPopWork;
    self.finalGenProd[ workIdx ] = weeklyPopWork;
  }

  fn calcWorkAccess( self : *EconSolver ) void // Like calcResAccess(), but only for work, since we need other res to calculate work prod
  {
    const workIdx  = ResType.WORK.toIdx();

    const available : f32 = @floatFromInt( self.finalPopProd[ workIdx ]);
    const required  : f32 = @floatFromInt( self.maxGenCons[   workIdx ]);


    self.popAccess[ workIdx ] = self.maxPopAccess; // POP will never need work, so access is maxed

    if( @abs( required ) < def.EPS ) // If WORK is somehow not needed, mark it as fully supplied
    {
      self.indAccess[ workIdx ] = self.maxIndAccess;
      self.genAccess[ workIdx ] = self.maxGenAccess;
    }
    else
    {
      const maxAccess = available / required;

      self.indAccess[ workIdx ] = @min( self.maxIndAccess, maxAccess );
      self.genAccess[ workIdx ] = @min( self.maxGenAccess, maxAccess );
    }
  }

  fn calcIndActivity( self : *EconSolver ) void
  {
    inline for( 0..indTypeCount )| i |
    {
      var activity : f32 = self.maxIndActivity;

      if( self.econ.indBank[ i ] == 0 ) // Skips absent industries
      {
        activity = 0.0;
      }
      else
      {
        const indType = IndType.fromIdx( i );
        const inst    = IndInstance.initByType( indType );

        // Solar modifier
        if( inst.powerSrc == .SOLAR ) // Limits activity based on available sunshine
        {
          activity = @min( activity, self.econ.sunshine * self.sunshineModifier );
        }

        // Resource modifiers
        inline for( 0..resTypeCount )| r |
        {
          if( self.perIndCons[ i ][ r ] != 0 ) // Non consumed resources do not affect industrial activity
          {
            activity = @min( activity, self.indAccess[ r ]);
          }
        }
      }
      self.indActivity[ i ] = activity ;
    }
  }

  fn applyResDelta( self : *EconSolver ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      // Iterating over population
      const popResAccess = self.popAccess[ r ];

      if( popResAccess > def.EPS )
      {
        // Production ( WORK )
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
      inline for( 0..indTypeCount )| i |
      {
        const indActivity = self.indActivity[ i ];

        if( indActivity > def.EPS )
        {
          // Production
          const rawIndProd   : f32 = @floatFromInt( self.perIndProd[ i ][ r ]);
          const finalIndProd : u64 = @intFromFloat( @floor( rawIndProd * indActivity ));

          self.finalIndProd[ r ] += finalIndProd;
          self.finalGenProd[ r ] += finalIndProd;

          // Consumption
          const rawIndCons   : f32 = @floatFromInt( self.perIndCons[ i ][ r ]);
          const finalIndCons : u64 = @intFromFloat( @floor( rawIndCons * indActivity ));

          self.finalIndCons[ r ] += finalIndCons;
          self.finalGenCons[ r ] += finalIndCons;
        }
      }

      // Updating economy
      const econ = self.econ;

      econ.prevResProd[ r ] = self.finalGenProd[ r ];
      econ.prevResCons[ r ] = self.finalGenCons[ r ];

      const resType = ResType.fromIdx( r );

      self.econ.addResCount( resType, self.finalGenProd[ r ]);
      self.econ.subResCount( resType, self.finalGenCons[ r ]);
    }
  }


  fn applyPopDelta( self : *EconSolver ) void
  {
    // NOTE : Iterated over pop-consumed res only

    // FOOD access
    const foodIdx  = ResType.FOOD.toIdx();
    var foodAccess = self.maxPopAccess;

    if( self.finalPopCons[ foodIdx ] > 0 )
    {
      foodAccess = @min( foodAccess, self.popAccess[ foodIdx ]);
    }
    if( foodAccess < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Population is experiencing food shortages !" );

      self.nextPopCount *= 1.0 - ( WEEKLY_STARVE_RATE * ( 1.0 - foodAccess ));
    }

    // WATER access
    const waterIdx  = ResType.WATER.toIdx();
    var waterAccess = self.maxPopAccess;

    if( self.finalPopCons[ waterIdx ] > 0 )
    {
      waterAccess = @min( waterAccess, self.popAccess[ waterIdx ]);
    }
    if( waterAccess < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Population is experiencing water shortages !" );

      self.nextPopCount *= 1.0 - ( WEEKLY_PARCH_RATE * ( 1.0 - waterAccess ));
    }

    // POWER access
    const powerIdx  = ResType.POWER.toIdx();
    var powerAccess = self.maxPopAccess;

    if( self.finalPopCons[ powerIdx ] > 0 )
    {
      powerAccess = @min( powerAccess, self.popAccess[ powerIdx ]);
    }
    if( powerAccess < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Population is experiencing power shortages !" );

      self.nextPopCount *= 1.0 - ( WEEKLY_FREEZE_RATE * ( 1.0 - powerAccess ));
    }

    def.log( .DEBUG, 0, @src(), "Pop access : F = {d:.3} - W = {d:.3} - P = {d:.3}", .{ foodAccess, waterAccess, powerAccess });


    self.nextPopCount = @floor( self.nextPopCount ); // Rounding down deaths

    // Applying growth to non-shorted population ( POWER is ignored )
    if( foodAccess > 1.0 - def.EPS and waterAccess > 1.0 - def.EPS)
    {
      const suppliedPopRatio = @min( powerAccess, waterAccess );

      self.nextPopCount += suppliedPopRatio * WEEKLY_POP_GROWTH * self.nextPopCount;
      self.nextPopCount  = @ceil( self.nextPopCount );
    }

    const popCap : f32 = @floatFromInt( self.econ.getPopCap() );

    const prevPopCount_i64 : i64 = @intFromFloat(           self.prevPopCount               );
    const nextPopCount_i64 : i64 = @intFromFloat( def.clmp( self.nextPopCount, 0.0, popCap ));

    // Updating economy
    const econ = self.econ;

    econ.popCount  = @intCast( nextPopCount_i64 );
    econ.popDelta  = nextPopCount_i64 - prevPopCount_i64;
    econ.popAccess = @min( foodAccess, waterAccess, powerAccess );

  //econ.popCount = 1000; // NOTE : DEBUG
  }
};