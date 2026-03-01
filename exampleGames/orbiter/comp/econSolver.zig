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
const WEEKLY_POP_GROWTH  : f32 = 1.000266631;

// Pop decay factors
const WEEKLY_PARCH_RATE  : f32 = 0.25;
const WEEKLY_STARVE_RATE : f32 = 0.10;
const WEEKLY_FREEZE_RATE : f32 = 0.05;

const MIN_WORK_RATE      : f32 = 0.25;


pub inline fn resolveEcon( econ : *ecn.Economy ) void
{
  var solver : EconSolver = .{ .econ = econ };

  solver.resolve();
}


const EconSolver = struct
{
  econ : *ecn.Economy,

  prevPopCount : f32 = 0.0,
  nextPopCount : f32 = 0.0,

  availableWork : f32 = 0.0,

  // Global consumption-production throttle / multiplier
  maxResAccess   : f32 = 1.0,
  maxIndActivity : f32 = 1.0,

  // NOTE : Remove redundant zeroing if this becomes a performance bottleneck

  popResCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  popResProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  indResCons : [ indTypeCount ][ resTypeCount ]u64 = std.mem.zeroes([ indTypeCount ][ resTypeCount ]u64 ),
  indResProd : [ indTypeCount ][ resTypeCount ]u64 = std.mem.zeroes([ indTypeCount ][ resTypeCount ]u64 ),

  popResAccess : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Population resource access ratios
  indResAccess : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ), // Industrial resource access ratios ( aggregated )
  indActivity  : [ indTypeCount ]f32 = std.mem.zeroes([ indTypeCount ]f32 ), // Industrial activity ratios

  totResCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // Final resources consumption
  totResProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // Final resources production


  pub fn resolve( self : *EconSolver ) void
  {
    self.initBaseState();
    self.applyResDecay();

    self.calcPopNeeds();    // Also computes max potential work
    self.calcIndNeeds();    // Also computes max potential prod

    self.calcResAccess();   // Decide how res are allocated   TODO : add access-tweaking policies

    self.calcIndActivity(); // The final efficiency of each industry type

    self.applyResDelta();   // Update res based on access
    self.applyPopDelta();   // Update pop based on access
  }


  fn initBaseState( self : *EconSolver ) void
  {
    self.prevPopCount  = @floatFromInt( self.econ.popCount );
    self.nextPopCount  = self.prevPopCount;
    self.availableWork = self.prevPopCount * res.ResType.WORK.getPerPopDelta();
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

      if( delta > def.EPS )
      {
        const maxProd : u64 = @intFromFloat( @floor( delta ));

        self.popResProd[ r ]  = maxProd;
        self.totResProd[ r ] += maxProd;
      }
      else if( delta < -def.EPS )
      {
        const maxCons : u64 = @intFromFloat( @floor( -delta ));

        self.popResCons[ r ]  = maxCons;
        self.totResCons[ r ] += maxCons;
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

          self.indResProd[ i ][ r ] = maxProd;
          self.indResCons[ i ][ r ] = maxCons;

          self.totResProd[ r ] += maxProd;
          self.totResCons[ r ] += maxCons;
        }
      }
    }
  }

  fn calcResAccess( self : *EconSolver ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      const available : f32 = @floatFromInt( self.econ.resBank[ r ]);
      const required  : f32 = @floatFromInt( self.totResCons[   r ]);

      if( @abs( required ) < def.EPS )
      {
        self.popResAccess[ r ] = 1.0;
        self.indResAccess[ r ] = 1.0;
      }
      else // TODO : Tweak population vs industry access ratio here if need be
      {
        const access = @min( self.maxResAccess, available / required );

        self.popResAccess[ r ] = access;
        self.indResAccess[ r ] = access;
      }
    }
  }

  fn calcIndActivity( self : *EconSolver ) void
  {
    inline for( 0..indTypeCount )| i |
    {
      var activity : f32 = self.maxIndActivity;

      if( self.econ.indBank[ i ] == 0 )
      {
        activity  = 0.0;
      }
      else
      {
        const indType = IndType.fromIdx( i );
        const inst    = IndInstance.initByType( indType );

        // Solar modifier
        if( inst.powerSrc == .SOLAR )
        {
          activity  = @min( activity , self.econ.sunshine );
        }

        // Resource modifiers
        inline for( 0..resTypeCount )| r |{ if( self.indResCons[ i ][ r ] != 0 )
        {
          activity  = @min( activity , self.indResAccess[ r ]);
        }}
      }

      self.indActivity[ i ]      = activity ;
      self.econ.indActivity[ i ] = activity ;
    }
  }

  fn applyResDelta( self : *EconSolver ) void
  {
    // Clearing to fill with ratio-affected values instead
    self.totResProd = std.mem.zeroes([ resTypeCount ]u64 );
    self.totResCons = std.mem.zeroes([ resTypeCount ]u64 );

    inline for( 0..resTypeCount )| r |
    {
      const popRatio = self.popResAccess[ r ];

      if( popRatio > def.EPS )
      {
        const rawPopProd : f32 = @floatFromInt( self.popResProd[ r ]);
        const rawPopCons : f32 = @floatFromInt( self.popResCons[ r ]);

        self.popResProd[ r ] = @intFromFloat( @floor( rawPopProd * popRatio ));
        self.popResCons[ r ] = @intFromFloat( @floor( rawPopCons * popRatio ));

        self.totResProd[ r ] += self.popResProd[ r ];
        self.totResCons[ r ] += self.popResCons[ r ];
      }

      inline for( 0..indTypeCount )| i |
      {
        const indRatio = self.indActivity[ i ];

        if( indRatio > def.EPS )
        {
          const rawIndProd : f32 = @floatFromInt( self.indResProd[ i ][ r ]);
          const rawIndCons : f32 = @floatFromInt( self.indResCons[ i ][ r ]);

          self.indResProd[ i ][ r ] = @intFromFloat( @floor( rawIndProd * indRatio ));
          self.indResCons[ i ][ r ] = @intFromFloat( @floor( rawIndCons * indRatio ));

          self.totResProd[ r ] += self.indResProd[ i ][ r ];
          self.totResCons[ r ] += self.indResCons[ i ][ r ];
        }
      }

      const resType = ResType.fromIdx( r );

      if( resType == .WORK )
      {
        self.econ.resBank[ r ] = self.totResProd[ r ];
      }
      else
      {
        self.econ.addResCount( resType, self.totResProd[ r ]);
        self.econ.subResCount( resType, self.totResCons[ r ]);
      }

      self.econ.resProd[ r ] += self.totResProd[ r ];
      self.econ.resCons[ r ] += self.totResCons[ r ];
    }
  }


  fn applyPopDelta( self : *EconSolver ) void
  {
    var foodAccess  : f32 = 1.0;
    var waterAccess : f32 = 1.0;
    var powerAccess : f32 = 1.0;

    const foodIdx  = ResType.FOOD.toIdx();
    const waterIdx = ResType.WATER.toIdx();
    const powerIdx = ResType.POWER.toIdx();

    if( self.popResCons[ foodIdx ] > 0 )
    {
      foodAccess = @min( foodAccess, self.popResAccess[ foodIdx ]);
    }
    if( self.popResCons[ waterIdx ] > 0 )
    {
      waterAccess = @min( waterAccess, self.popResAccess[ waterIdx ]);
    }
    if( self.popResCons[ powerIdx ] > 0 )
    {
      powerAccess = @min( powerAccess, self.popResAccess[ powerIdx ]);
    }


    if( foodAccess < 1.0 )
    {
      def.qlog( .INFO, 0, @src(), "Population is experiencing food shortages !" );

      self.nextPopCount *= 1.0 - ( WEEKLY_STARVE_RATE * ( 1.0 - foodAccess ));
    }
    if( waterAccess < 1.0 )
    {
      def.qlog( .INFO, 0, @src(), "Population is experiencing water shortages !" );

      self.nextPopCount *= 1.0 - ( WEEKLY_PARCH_RATE * ( 1.0 - waterAccess ));
    }
    if( powerAccess < 1.0 )
    {
      def.qlog( .INFO, 0, @src(), "Population is experiencing power shortages !" );

      self.nextPopCount *= 1.0 - ( WEEKLY_FREEZE_RATE * ( 1.0 - powerAccess ));
    }

    if( foodAccess > 1.0 - def.EPS and waterAccess > 1.0 - def.EPS)
    {
      self.nextPopCount *= WEEKLY_POP_GROWTH;
    }

    const popCap           : f32 = @floatFromInt( self.econ.getPopCap() );
    const prevPopCount_i64 : i64 = @intFromFloat( @ceil(           self.prevPopCount               ));
    const nextPopCount_i64 : i64 = @intFromFloat( @ceil( def.clmp( self.nextPopCount, 0.0, popCap )));

    self.econ.popCount     = @intCast( nextPopCount_i64 );
    self.econ.popDelta     = nextPopCount_i64 - prevPopCount_i64;
    self.econ.popResAccess = @min( foodAccess, waterAccess, powerAccess );
  }
};