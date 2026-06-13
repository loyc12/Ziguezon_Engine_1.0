const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


const gdf = @import( "../gameDef.zig" );
const ecn = gdf.ecn;

const VesType  = gdf.VesType;
const ResType  = gdf.ResType;
const InfType  = gdf.InfType;
const IndType  = gdf.IndType;

const vesTypeC = VesType.count;
const resTypeC = ResType.count;
const infTypeC = InfType.count;
const indTypeC = IndType.count;


const bld = gdf.bldr_d;

const BuildEntry = bld.BuildEntry;
const Construct  = bld.Construct;
const EconAgent  = bld.EconAgent;
const EntryType  = bld.EntryTypeEnum;
const EntryMode  = bld.EntryModeEnum;



// TODO :
// - call from EconSolver instead of Econ itself ( pass in slvr, not econ )
// - have a dedicated build phase in solver, so we can properly calculate res delta
// - build entries in parallel instead of sequentially
// - setup priority ordering
// - setup per-agentGroup queues instead of monoqueue


pub const BuildQueue = struct
{
  pub const BUILD_QUEUE_CAPACITY : usize = 127;

  pub const EntryArray = [ BUILD_QUEUE_CAPACITY ]BuildEntry;


  entries : EntryArray = undefined,

  maxEntryCount  : u64 = 0,
  totCnstrAvail  : f64 = 0.0,
  totUnitsBuilt  : u64 = 0, // For debug logging only
  totEntryClosed : u64 = 0, // For debug logging only



  pub fn init() BuildQueue
  {
    var queue : BuildQueue = .{ .maxEntryCount = 0 };

    for( 0..BUILD_QUEUE_CAPACITY )| i |
    {
      queue.entries[ i ].reset();
    }

    return queue;
  }

  pub fn hasMatchingEntry( self : *BuildQueue, c : Construct, q : EconAgent ) bool
  {
    for( self.entries )| e |
    {
      if( e.matchesWithPart( .{ .construct = c, .agent = q }))
      {
        return true;
      }
    }
    return false;
  }

// ================================ EXTERNAL API ================================

  pub fn tryAddEntry( self : *BuildQueue, c : Construct, q : EconAgent, t : EntryType, m : EntryMode, count : u64 ) bool
  {
    const count_f : f64 = @floatFromInt( count );

    // If construct already in list, set amount to be built based on mode
    if( self.maxEntryCount > 0 )
    {
      for( 0..self.maxEntryCount )| idx |
      {
        var e = &self.entries[ idx ];

        if( self.hasMatchingEntry( c, q ))
        {
          if( e.entryType != t ) // TODO : Find something better to do with conflicting entryTypes here
          {
            utl.qlog( .WARN, @src(), "EntryType mismatch : deleting previous entry with conflicting entryType" );

            e.unitCount = 0.0;
          }
          else
          {
            switch( m )
            {
              .ADD_TO   => e.unitCount +=       count_f,
              .SET_TO   => e.unitCount  =       count_f,
              .RAISE_TO => e.unitCount  = @max( count_f, e.unitCount ),
              .LOWER_TO => e.unitCount  = @min( count_f, e.unitCount ),
              .CANCEL   => e.unitCount  = 0.0,
            }

            return true;
          }
        }
      }
    }

    // If no matching entry found, try adding a new one
    if( m != .CANCEL ){ return self.addNewEntry( c, q, t, m, count_f ); }

    return false;
  }

  fn addNewEntry( self : *BuildQueue, c : Construct, q : EconAgent, t : EntryType, m : EntryMode, count : f64 ) bool
  {
    if( m == .CANCEL )
    {
      utl.qlog( .WARN, @src(), "Cannot cancel non-existant entry form build queue" );
      return false;
    }
    if( self.maxEntryCount >= BUILD_QUEUE_CAPACITY )
    {
      utl.qlog( .WARN, @src(), "Cannot add entry to build queue : no more space left in queue" );
      return false;
    }

    // Add entry to the end of list
    self.entries[ self.maxEntryCount ] =
    .{
      .construct = c,
      .agent = q,
      .entryType = t,
      .unitCount = count,
      .priority  = 1,
    };

    self.entries[ self.maxEntryCount ].debugLogSimple();

    self.maxEntryCount += 1; // NOTE : the following entries should already have been be zeroed

    return true;
  }

  /// Returns the unused funds
  pub fn tryFundEntry( self : *BuildQueue, econ : *const ecn.Economy, c : Construct, q : EconAgent, t : EntryType, funds : f64 ) f64
  {
    if( t == .DESTR ){ return funds; } // Destruction will never need funds

    var remainingFunds = funds;

    // If construct already in list, set amount to be built based on mode
    if( self.maxEntryCount > 0 )
    {
      for( 0..self.maxEntryCount )| idx |
      {
        var e = &self.entries[ idx ];

        if( e.matchesWithFull( .{ .construct = c, .agent = q, .entryType = t }))
        {
          remainingFunds = e.tryGrantFunds( econ, funds );
          e.debugLogComplex();
          break;
        }
      }
    }
    return remainingFunds;
  }

  fn dumpEntryByIdx( self : *BuildQueue, econ : *ecn.Economy, idx : usize ) void
  {
    const e = &self.entries[ idx ];

    // Calculated agent refund
    var refund = e.stashedFunds;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );
      const resC = e.stashedRes.get(          resT );

      // Selling off resources and adding them to the econ's stores
      refund += (                  resP * resC );
      econ.resState.add( .COUNT,   resT,  resC );
      econ.resState.add( .COUNT_D, resT,  resC );
    }
    if( refund > utl.EPS )
    {
      EconAgent.addAgentSavings( econ, e.agent, refund );
    }

    e.reset(); // NOTE : Invalidates entry so it is remove on the next compactEntries() call
  }


  // ================================ SIMPLE ACCESSORS ================================

  pub inline fn getTotalUnitCount( self : *const BuildQueue ) f64
  {
    var total : f64 = 0;

    for( 0..self.maxEntryCount )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += e.unitCount;
      }
    }

    return total;
  }

  pub inline fn getTotalRemainResCost( self : *const BuildQueue, resT : ResType ) f64
  {
    var total : u64 = 0;

    for( 0..self.maxEntryCount )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += e.getRemainResCost( resT );
      }
    }

    return total;
  }

  pub inline fn getTotalRemainCnstCost( self : *const BuildQueue, resT : ResType ) f64
  {
    var total : u64 = 0;

    for( 0..self.maxEntryCount )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += e.getRemainCnstCost( resT );
      }
    }

    return total;
  }

  pub inline fn getTotalRemainCashCost( self : *const BuildQueue, resT : ResType ) f64
  {
    var total : u64 = 0;

    for( 0..self.maxEntryCount )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += e.getRemainCashCost( resT );
      }
    }

    return total;
  }


  // ================================ UPDATE FUNCTIONS ================================


  fn compactEntries( self : *BuildQueue ) void
  {
    var dstIdx : usize = 0;
    var srcIdx : usize = 0;

    while( true )
    {
      if( srcIdx >= self.maxEntryCount or srcIdx >= BUILD_QUEUE_CAPACITY )
      {
        break;
      }

      var src = &self.entries[ srcIdx ];
      var dst = &self.entries[ dstIdx ];

      // Look for valid src entries
      if( src.isValid() )
      {
        // If srcIdx greater than dstIdx, copy over to dst and nullify src
        if( srcIdx > dstIdx )
        {
          dst.reset();
          dst = src;
          src.reset();
        }

        dstIdx += 1;
      }

      srcIdx += 1;
    }

    self.maxEntryCount = dstIdx + 1; // Should always be the number of valid entries found
  }


  pub fn tickQueue( self : *BuildQueue, econ : *ecn.Economy ) void
  {
    self.totUnitsBuilt  = 0;
    self.totEntryClosed = 0;

    const assemblyCount = econ.infState.get( .COUNT, .ASSEMBLY );
    const assemblyRate  = InfType.ASSEMBLY.getMetric_f64( .CAPACITY );
    self.totCnstrAvail  = @floor( assemblyCount * assemblyRate );

    var remainCnst = self.totCnstrAvail;

    if( self.maxEntryCount > 0 )
    {
      var idx : usize = 0;

      while( idx < self.maxEntryCount )
      {
        const e = &self.entries[ idx ];
        idx    += 1;

        if( e.isValid() )
        {
          if( !e.isClosed() )
          {
            // NOTE : tryFundEntry() should have been called by beforehand to be able to buy the resources it may need
            _ = e.tryBuyRes( econ );

            // TODO : have assemblies get paid for the cnst used

            remainCnst = e.tryGrantCnst( remainCnst );

            self.totUnitsBuilt += @intFromFloat( e.tryBuildUnits( econ ));
          }

          if( e.isClosed() )
          {
            self.dumpEntryByIdx( econ, idx );
            self.totEntryClosed += 1;
          }
        }
        else
        {
          self.totEntryClosed += 1; // Ensures compactEntries() gets called
        }
      }

      if( self.totEntryClosed > 0 )
      {
        self.compactEntries();
      }
    }

    econ.infState.set( .USE_LVL, .ASSEMBLY, 1.0 - ( remainCnst / self.totCnstrAvail ) );
  }


  // ================ DEBUG FUNCTIONS ================

  pub fn debugLogBuildQueue( self : *BuildQueue ) void
  {
    if( self.maxEntryCount > 0 )
    {
      utl.qlog( .INFO, @src(), "# Logging build queue entries :" );
      utl.log(  .CONT, @src(), "EntryCount : {d} ( Cnstr : {d} | UnitsBuilt {d} | EntryClosed : {d} )", .{ self.maxEntryCount, self.totCnstrAvail, self.totUnitsBuilt, self.totEntryClosed });


      for( 0..self.maxEntryCount )| idx |
      {
        const e = &self.entries[ idx ];

        if( e.isValid() )
        {
          e.debugLogComplex();
        }
      }
    }
  }
};
