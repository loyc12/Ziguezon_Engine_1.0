const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const res = @import( "resource.zig" );
const ecn = @import( "economy.zig" );


const resTypeCount = res.resTypeCount;
const infTypeCount = inf.infTypeCount;

const ResType = res.ResType;
const InfType = inf.InfType;

const ResInstance = res.ResInstance;
const InfInstance = inf.InfInstance;


pub inline fn resolveEcon( econ : *ecn.Economy ) void
{
  var solver : EconSolver = .{};

  solver.initFromEcon( econ );
  solver.computeResAccessRatios( econ );
  solver.computeInfActivityRatios( econ );
  solver.applyDeltas( econ );
}


const EconSolver = struct
{
  maxEfficiency : f32 = 1.0, // Global consumption-production throttle / multiplier

  // TODO : remove redundant zeroing if this becomes a performance bottleneck

  // Currently available res / infra
  resAvail : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  infAvail : [ infTypeCount ]u64 = std.mem.zeroes([ infTypeCount ]u64 ),

  // Aggregated const. / prod.
  totResCons : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  totResProd : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  // Resource bottlenecks and individual infra multiplier
  resAccessRatios   : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ),
  infActivityRatios : [ infTypeCount ]f32 = std.mem.zeroes([ infTypeCount ]f32 ),

  // Cache for cons / prod per infra
  infResCons : [ infTypeCount ][ resTypeCount ]u64 = std.mem.zeroes([ infTypeCount ][ resTypeCount ]u64 ),
  infResProd : [ infTypeCount ][ resTypeCount ]u64 = std.mem.zeroes([ infTypeCount ][ resTypeCount ]u64 ),


  fn initFromEcon( self : *EconSolver, econ: *const ecn.Economy ) void
  {
    self.totResCons = std.mem.zeroes([ resTypeCount ]u64 );
    self.totResProd = std.mem.zeroes([ resTypeCount ]u64 );

    inline for ( 0..resTypeCount )| r |
    {
      self.resAvail[ r ] = econ.resBank[ r ]; // TODO : do not forget to update WORK when updating pop in Economy
    }

    inline for( 0..infTypeCount )| i |
    {
      self.infAvail[ i ] = econ.infBank[ i ];

      if( self.infAvail[ i ] == 0 ) // If none of this infra is present, zero out the relevant arrays
      {
        inline for ( 0..resTypeCount )| r |
        {
          self.infResCons[ i ][ r ] = 0;
          self.infResProd[ i ][ r ] = 0;
        }
      }
      else // Else, fill said arrays with the maximum possible cons and prod
      {
        const infType = InfType.fromIdx( i );
        const inst    = InfInstance.initByType( infType ); // TODO : use a static comptime table if this is a performance bottleneck

        inline for ( 0..resTypeCount )| r |
        {
          const resType = ResType.fromIdx( r );

          self.infResCons[ i ][ r ] = self.infAvail[ i ] * inst.getResConsPerInf( resType );
          self.infResProd[ i ][ r ] = self.infAvail[ i ] * inst.getResProdPerInf( resType );

          self.totResCons[ r ] += self.infResCons[ i ][ r ];
          self.totResProd[ r ] += self.infResProd[ i ][ r ];
        }
      }
    }
  }

  fn computeResAccessRatios( self : *EconSolver, econ : *ecn.Economy ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      if( self.totResCons[ r ] == 0 )
      {
        self.resAccessRatios[ r ] = 1.0;
      }
      else
      {
        const availF : f32 = @floatFromInt( self.resAvail[   r ]);
        const consF  : f32 = @floatFromInt( self.totResCons[ r ]);

        self.resAccessRatios[ r ] = @min( self.maxEfficiency, availF / consF );
      }
      econ.resAccess[ r ] = self.resAccessRatios[ r ];
    }
  }

  fn computeInfActivityRatios( self : *EconSolver, econ : *ecn.Economy ) void
  {
    inline for( 0..infTypeCount )| i |
    {
      if( self.infAvail[ i ] == 0 )
      {
        self.infActivityRatios[ i ] = 0.0;
      }
      else
      {
        var ratio : f32 = self.maxEfficiency;

        // Solar modifier
        const infType = InfType.fromIdx( i );
        const inst = InfInstance.initByType( infType );

        if( inst.powerSrc == .SOLAR )
        {
          ratio *= econ.sunshine;
        }

        // Resource modifiers
        inline for( 0..resTypeCount )| r |{ if( self.infResCons[ i ][ r ] != 0 )
        {
          ratio = @min( ratio, self.resAccessRatios[ r ]);
        }}

        self.infActivityRatios[ i ] = ratio;
      }

      econ.infActivity[ i ] = self.infActivityRatios[ i ];
    }
  }

  fn applyDeltas( self : *EconSolver, econ : *ecn.Economy ) void
  {
    inline for( 0..infTypeCount )| i |
    {
      const ratio = self.infActivityRatios[ i ];

      if( ratio != 0.0 ){ inline for( 0..resTypeCount )| r |
      {
        const resType = ResType.fromIdx( r );

        // WORK supply is set to be proportional to current population during Economy's updatePop step, so no need to update it here
        if( resType != .WORK )
        {
          const prodF : f32 = @floatFromInt( self.infResProd[ i ][ r ]);
          const consF : f32 = @floatFromInt( self.infResCons[ i ][ r ]);

          // NOTE : if resources magically disapearing becomes an issue, look here
          const prodApplied : i64 = @intFromFloat( @floor( prodF * ratio ));
          const consApplied : i64 = @intFromFloat( @ceil(  consF * ratio ));

          econ.resDelta[ r ] += @intCast( prodApplied - consApplied );

          econ.addResCount( resType, @intCast( prodApplied ));
          econ.subResCount( resType, @intCast( consApplied ));
        }
      }}
    }
  }
};