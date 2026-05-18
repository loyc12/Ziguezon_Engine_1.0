const std = @import( "std" );
const def = @import( "defs" );


const gdf = @import( "../gameDefs.zig" );
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
const Requester  = bld.Requester;
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
      queue.entries[ i ] = .{};
    }

    return queue;
  }

  pub fn hasMatchingEntry( self : *BuildQueue, c : Construct, q : Requester ) bool
  {
    for( self.entries )| e |
    {
      if( e.matchesWithPart( &BuildEntry{ .construct = c, .requester = q }))
      {
        return true;
      }
    }
    return false;
  }

// ================================ EXTERNAL API ================================

  pub fn tryAddEntry( self : *BuildQueue, c : Construct, q : Requester, t : EntryType, m : EntryMode, count : u64 ) bool
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
            def.qlog( .WARN, 0, @src(), "EntryType mismatch : overriding type and clearing previous unitCount" );

            e.entryType = t;
            e.unitCount = 0.0;
          }

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

    // If no matching entry found, try adding a new one
    return self.addNewEntry( c, q, t, m, count_f );
  }

  fn addNewEntry( self : *BuildQueue, c : Construct, q : Requester, t : EntryType, m : EntryMode, count : f64 ) bool
  {
    if( m == .CANCEL )
    {
      def.qlog( .WARN, 0, @src(), "Cannot cancel non-existant entry form build queue" );
      return false;
    }
    if( self.maxEntryCount >= BUILD_QUEUE_CAPACITY )
    {
      def.qlog( .WARN, 0, @src(), "Cannot add entry to build queue : no more space left in queue" );
      return false;
    }

    // Add entry to the end of list
    self.entries[ self.maxEntryCount ] =
    .{
      .construct = c,
      .requester = q,
      .entryType = t,
      .unitCount = count,
      .priority  = 1,
    };

    self.entries[ self.maxEntryCount ].debugLogSimple();

    self.maxEntryCount += 1; // NOTE : the following entries should already have been be zeroed

    return true;
  }

  /// Returns the unused funds
  pub fn tryFundEntry( self : *BuildQueue, econ : *const ecn.Economy, c : Construct, q : Requester, t : EntryType, funds : f64 ) f64
  {
    if( t == .DESTR ){ return funds; } // Destruction will never need funds

    var remainingFunds = funds;

    // If construct already in list, set amount to be built based on mode
    if( self.maxEntryCount > 0 )
    {
      for( 0..self.maxEntryCount )| idx |
      {
        var e = &self.entries[ idx ];

        if( e.matchesWith( .{ .construct = c, .requester = q, .entryType = t }))
        {
          remainingFunds = e.tryGrantFunds( econ, funds );
          e.debugLogComplex();
          break;
        }
      }
    }
    return remainingFunds;
  }

  fn clearEntryByIdx( self : *BuildQueue, econ : *ecn.Economy, idx : usize ) void
  {
    const e = &self.entries[ idx ];

    // Calculated requester refund
    var refund = e.stashedFunds;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );
      const resC = e.stashedRes.get(        resT );

      // Selling off resources and adding them to the econ's stores
      refund += (           resP * resC );
      econ.resState.add( .COUNT,   resT,  resC );
      econ.resState.add( .COUNT_D, resT,  resC );
    }

    Requester.addAgentSavings( econ, e.requester, refund );

    e.* = .{}; // NOTE : Invalidates entry so it is remove on the next compactEntries() call
  }


  // ================================ SIMPLE ACCESSORS ================================

  pub inline fn getTotalEntryCount( self : *const BuildQueue ) u64
  {
    var total : u64 = 0;

    for( 0..self.maxEntryCount )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += 1;
      }
    }

    return total;
  }

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
    var dstEntryIdx : usize = 0;
    var srcEntryIdx : usize = 1;

    while( true )
    {
      var e = &self.entries[ srcEntryIdx ];

      if( !e.isValid() )
      {
        srcEntryIdx += 1;
      }
      else
      {
        self.entries[ dstEntryIdx ] = self.entries[ srcEntryIdx ];
        dstEntryIdx += 1;
        srcEntryIdx += 1;
      }

      if( srcEntryIdx >= self.maxEntryCount or srcEntryIdx >= BUILD_QUEUE_CAPACITY )
      {
        break; // Redundant but why not
      }
    }

    self.maxEntryCount = dstEntryIdx + 1; // Should always be the number of valid entries found
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
            self.clearEntryByIdx( econ, idx );
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

  pub fn debugLog( self : *BuildQueue ) void
  {
    if( self.maxEntryCount > 0 )
    {
      def.qlog( .INFO, 0, @src(), "# Logging build queue entries :" );
      def.log(  .CONT, 0, @src(), "EntryCount : {d} ( CnstrPoints : {d} | UnitsBuilt {d} | EntryClosed : {d} )", .{ self.maxEntryCount, self.totCnstrAvail, self.totUnitsBuilt, self.totUnitsBuilt });


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
