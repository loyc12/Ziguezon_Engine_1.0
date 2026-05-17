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
// - refund cancelations in res and cash
// - build entries in parallel instead of sequentially
// - setup priority ordering
// - setup per-agentGroup queues instead of a single one


pub const BuildQueue = struct
{
  pub const BUILD_QUEUE_CAPACITY : usize = 127;

  pub const BuildEntryArray = [ BUILD_QUEUE_CAPACITY ]BuildEntry;


  entries : BuildEntryArray = undefined,

  maxEntryIdx   : u64 = 0,
  totUnitsBuilt : u64 = 0, // For debug logging only


  pub fn init() BuildQueue
  {
    var queue : BuildQueue = .{ .maxEntryIdx = 0 };

    for( 0..BUILD_QUEUE_CAPACITY )| i |
    {
      queue.entries[ i ] = .{};
    }

    return queue;
  }

  pub fn hasMatchingEntry( self : *BuildQueue, c : Construct, q : Requester, t : EntryType ) bool
  {
    for( self.entries )| e |
    {
      if( e.matchesWith( .{ .construct = c, .requester = q, .entryType = t }))
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
    if( self.maxEntryIdx > 0 )
    {
      for( 0..self.maxEntryIdx )| idx |
      {
        var e = &self.entries[ idx ];

        if( def.areContEqual( c, e.construct ) and def.areContEqual( q, e.requester ))
        {
          const eT1 = e.entryType;
          const eT2 = t;

          if( m == .CANCEL )
          {
            e.unitCount = 0.0;
            return true;
          }

          if( eT1 == eT2 )
          {
            switch( m )
            {
              .SET_TO   => e.unitCount  = count_f,
              .ADD_TO   => e.unitCount += count_f,
              .RAISE_TO => e.unitCount  = @max( count_f, e.unitCount ),
              .LOWER_TO => e.unitCount  = @min( count_f, e.unitCount ),
              .CANCEL   => unreachable,
            }
            return true;
          }
          else // EntryType mismatch ( ex : CNSTR vs DESTR )
          {
            // TODO : IMPLEMENT THIS LOGIC
          }

          // NOTE : money refunds should be done in clearEntry(), called from update()
        }
      }
    }

    return self.addNewEntry( c, q, t, m, count_f );
  }

  fn addNewEntry( self : *BuildQueue, c : Construct, q : Requester, t : EntryType, m : EntryMode, count : f64 ) bool
  {
    if( m == .CANCEL )
    {
      def.qlog( .WARN, 0, @src(), "Cannot cancel non-existant entry form build queue" );
      return false;
    }
    if( self.maxEntryIdx >= BUILD_QUEUE_CAPACITY )
    {
      def.qlog( .WARN, 0, @src(), "Cannot add entry to build queue : no more space left in queue" );
      return false;
    }


    // Add entry to the end of list
    self.entries[ self.maxEntryIdx ] =
    .{
      .construct = c,
      .requester = q,
      .entryType = t,
      .unitCount = count
    };

    def.qlog( .DEBUG, 0, @src(), "# New build entry :" );
    self.entries[ self.maxEntryIdx ].debugLogSimple();

    self.maxEntryIdx += 1;

    // NOTE : the following entries should already have been be zeroed

    return true;
  }

  /// Returns the unused funds
  pub fn tryFundEntry( self : *BuildQueue, econ : *const ecn.Economy, c : Construct, q : Requester, t : EntryType, funds : f64 ) f64
  {
    // If construct already in list, set amount to be built based on mode
    if( self.maxEntryIdx > 0 )
    {
      for( 0..self.maxEntryIdx )| idx |
      {
        var e = &self.entries[ idx ];

        if( e.matchesWith( .{ .construct = c, .requester = q, .entryType = t }))
        {
          return e.tryGrantFunds( econ, funds );
        }
      }
    }
    return funds;
  }

  fn clearEntryByIdx( self : *BuildQueue, econ : *ecn.Economy, idx : usize ) void
  {
    // TODO : Put remaining resources into BUILD_PROD of requester

    // TODO : Give remaining funds back to requester

    _ = econ;

    const e = &self.entries[ idx ];
    e.* = .{}; // NOTE : makes entries invalid on purpose
  }


  // ================================ SIMPLE ACCESSORS ================================

  pub inline fn getTotalEntryCount( self : *const BuildQueue ) u64
  {
    var total : u64 = 0;

    for( 0..self.maxEntryIdx )| idx |
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

    for( 0..self.maxEntryIdx )| idx |
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

    for( 0..self.maxEntryIdx )| idx |
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

    for( 0..self.maxEntryIdx )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += e.getRemainCnstCost( resT );
      }
    }

    return total;
  }

  pub inline fn getTotalRemainMoneyCost( self : *const BuildQueue, resT : ResType ) f64
  {
    var total : u64 = 0;

    for( 0..self.maxEntryIdx )| idx |
    {
      var e = &self.entries[ idx ];

      if( e.isValid() )
      {
        total += e.getRemainMoneyCost( resT );
      }
    }

    return total;
  }


  // ================================ UPDATE FUNCTIONS ================================


  fn compactEntries( self : *BuildQueue ) void
  {
    var entryOffset    : usize = 0;
    var newMaxEntryIdx : usize = 0;

    for( 0..self.maxEntryIdx )| idx |
    {
      var e = &self.entries[ idx ];

      if( !e.isValid() )
      {
        entryOffset += 1;

        if( idx + entryOffset > self.maxEntryIdx )
        {
          break; // Stop offseting entries once all that remains is already zeroed
        }

        self.entries[ idx ] = self.entries[ idx + entryOffset ];
      }
      else
      {
        newMaxEntryIdx += 1;
      }
    }

    self.maxEntryIdx = newMaxEntryIdx;
  }


  pub fn tickQueue( self : *BuildQueue, econ : *ecn.Economy ) void
  {
    self.totUnitsBuilt = 0;

    var cnstUseRatio : f64 = 0.0;

    if( self.maxEntryIdx > 0 )
    {
      var entriesClosed : u64 = 0;

      const assemblyCount = econ.infState.get( .COUNT, .ASSEMBLY );
      const assemblyRate  = InfType.ASSEMBLY.getMetric_f64( .CAPACITY );
      const maxAvailCnst  = @floor( assemblyCount * assemblyRate );

      var remainCnst  = maxAvailCnst;
      var idx : usize = 0;

      while( idx < self.maxEntryIdx )
      {
        const e = &self.entries[ idx ];
        idx    += 1;

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
          entriesClosed += 1;
        }
      }

      if( entriesClosed > 0 )
      {
        self.compactEntries();
      }
      cnstUseRatio = 1.0 - ( remainCnst / maxAvailCnst );
    }

    econ.infState.set( .USE_LVL, .ASSEMBLY, cnstUseRatio );
  }
};
