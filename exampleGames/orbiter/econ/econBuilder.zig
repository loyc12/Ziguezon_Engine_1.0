const std = @import( "std" );
const def = @import( "defs" );


const gdf = @import( "../gameDefs.zig" );
const ecn = gdf.ecn;

const VesType  = gdf.VesType;
const ResType  = gdf.ResType;
const InfType  = gdf.InfType;
const IndType  = gdf.IndType;

const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;


const cst = @import( "construct.zig" );

const Construct = cst.Construct;


pub const BuildEntry = struct
{
  construct    : Construct = .{ .inf = InfType.HOUSING },
  buildCount   : u64 = 0,
  partProgress : u64 = 0,

  pub inline fn isEntryClosed( self : *const BuildEntry ) bool
  {
    return( self.buildCount == 0 );
  }

  pub inline fn getUnitPartCost( self : *const BuildEntry ) f64
  {
    return self.construct.getPartCost();
  }

  pub inline fn getTotalPartCost( self : *const BuildEntry ) f64
  {
    const  count : f64 = @floatFromInt( self.buildCount );
    return count * self.getUnitPartCost();
  }

  pub fn calcBuildableAmount( self : *BuildEntry, availParts : f64 ) f64
  {
    const unitPartCost = self.getUnitPartCost();
    const count : f64  = @floatFromInt( self.buildCount );

    if( availParts > count * unitPartCost )
    {
      return @floor( count );
    }

    return @floor( availParts / unitPartCost );
  }
};


const BUILD_QUEUE_CAPACITY : usize = 255;

pub const BuildQueue = struct
{
  entries       : [ BUILD_QUEUE_CAPACITY ]BuildEntry = undefined,
  entryCount    : u64 = 0,
  totUnitsBuilt : u64 = 0,


  pub fn init() BuildQueue
  {
    var queue : BuildQueue = .{ .entryCount = 0 };

    for( 0..BUILD_QUEUE_CAPACITY )| i |
    {
      queue.entries[ i ] =
      .{
        .construct  = .{ .inf = InfType.HABITAT },
        .buildCount = 0,
      };
    }

    return queue;
  }

  pub fn addEntry( self : *BuildQueue, c : Construct, count : u64 ) bool
  {
    if( count == 0 ){ return false; }

    // If construct same as last in list, increment amount to be built
    if( self.entryCount > 0 and std.meta.eql( c, self.entries[ self.entryCount - 1 ].construct ))
    {
      self.entries[ self.entryCount - 1 ].buildCount += count;
      return true;
    }

    // If list is full, deny the build order
    if( self.entryCount >= BUILD_QUEUE_CAPACITY )
    {
      def.qlog( .WARN, 0, @src(), "Cannot add entry to build queue : no more spaces" );
      return false;
    }

    self.entryCount += 1;
    self.entries[ self.entryCount - 1 ] = .{ .construct = c, .buildCount = count };

    return true;
  }

  pub fn removeEntryAmount( self : *BuildQueue, amount : u64 ) void
  {
    if( amount == 0 ){ return; }

    if( amount < self.entryCount )
    {
      var idx : usize = 0;

      // Remove completed entries ( swap-remove from front to back )
      while( idx + amount < self.entryCount )
      {
        self.entries[ idx ] = self.entries[ idx + amount ];

        idx += 1;
      }
      self.entryCount -= amount;
    }
    else
    {
      // Clear all entries
      self.entryCount = 0;
    }
  }


  pub inline fn getTotalBuildCount( self : *const BuildQueue ) u64
  {
    var total : u64 = 0;

    for( self.entries )| e |
    {
      if( e.buildCount == 0 ){ return total; }
      total += e.buildCount;
    }
    return total;
  }

  pub inline fn getEntryCount( self : *const BuildQueue ) u32
  {
    for( self.entries, 0.. )| e, idx |
    {
      if( e.buildCount == 0 ){ return @intCast( idx ); }
    }
    return self.entries.len;
  }

  pub inline fn getTotalPartCost( self : *const BuildQueue ) f64
  {
    var total : f64 = 0;
    for( self.entries )| e |
    {
      if( e.buildCount != 0 )
      {
        total += e.getTotalPartCost();
      }
      else break;
    }
    return total;
  }


  pub fn update( self : *BuildQueue, econ : *ecn.Economy ) void
  {
    self.totUnitsBuilt = 0;

    if( self.entryCount > 0 )
    {
      var entriesClosed : u64 = 0;

      const assemblyCount = econ.infState.get( .COUNT, .ASSEMBLY );
      const assemblyRate  = InfType.ASSEMBLY.getMetric_f64( .CAPACITY );
      const assemblyCap   = @ceil( assemblyCount * assemblyRate );

      const availParts = @min( assemblyCap, econ.buildBudget );
      var  remainParts = availParts;


      for( 0..self.entryCount )| idx |
      {
        var entry = &self.entries[ idx ];
        var unitsBuilt : u64 = 0;

        remainParts += @floatFromInt( entry.partProgress );
        entry.partProgress = 0;

        const unitPartCost = entry.construct.getPartCost();
        const unitsToBuild = entry.calcBuildableAmount( remainParts );

        if( unitsToBuild > def.EPS )
        {
          unitsBuilt = econ.tryBuild( entry.construct, unitsToBuild, false );
          const unitsBuilt_f : f64 = @floatFromInt( unitsBuilt );

          remainParts        -= unitsBuilt_f * unitPartCost;
          entry.buildCount   -= unitsBuilt;
          self.totUnitsBuilt += unitsBuilt;
        }


        // Failed to close the entry : likely cannot build anything more
        if( !entry.isEntryClosed() )
        {
          def.log( .DEBUG, 0, @src(), "@ Could not close build queue : stashed remaining {d} parts", .{ remainParts });
          entry.partProgress += @intFromFloat( remainParts );
          break;
        }

        entriesClosed += 1;
      }

      // Update assembly usage metric
      if( assemblyCap > def.EPS )
      {
        const partsUsed = availParts - remainParts;
        econ.infState.set( .USE_LVL, .ASSEMBLY, partsUsed / assemblyCap );
      }
      else
      {
        econ.infState.set( .USE_LVL, .ASSEMBLY, 0.0 );
      }

      self.removeEntryAmount( entriesClosed );
    }

    if( self.entryCount == 0 )
    {
      def.qlog( .DEBUG, 0, @src(), "$ Succesfully closed build queue" );
    }

    return;
  }
};
