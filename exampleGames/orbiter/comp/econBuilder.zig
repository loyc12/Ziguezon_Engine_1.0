const std = @import( "std" );
const def = @import( "defs" );


const ecn = @import( "economy.zig"   );
const cst = @import( "construct.zig" );

const Construct = cst.Construct;


const gbl = @import( "../gameGlobals.zig" );

const vesTypeCount = gbl.vesTypeCount;
const resTypeCount = gbl.resTypeCount;
const infTypeCount = gbl.infTypeCount;
const indTypeCount = gbl.indTypeCount;

const VesType      = gbl.VesType;
const ResType      = gbl.ResType;
const InfType      = gbl.InfType;
const IndType      = gbl.IndType;


pub const BuildEntry = struct
{
  construct  : Construct = .{ .inf = InfType.HOUSING },
  buildCount : u64 = 0,

  pub inline fn isEntryClosed( self : *const BuildEntry ) bool
  {
    return( self.buildCount == 0 );
  }

  pub inline fn getUnitPartCost( self : *const BuildEntry ) f32
  {
    return self.construct.getPartCost();
  }

  pub inline fn getRemainingPartCost( self : *const BuildEntry ) f32
  {
    const count : f32 = @floatFromInt( self.buildCount );
    return count * self.getUnitPartCost();
  }

  pub fn calcBuildableAmount( self : *BuildEntry, availParts : f32 ) f32
  {
    const unitPartCost = self.getUnitPartCost();
    const count : f32  = @floatFromInt( self.buildCount );

    if( availParts > count * unitPartCost )
    {
      return count;
    }

    return( availParts / unitPartCost );
  }
};


const BUILD_QUEUE_CAPACITY : usize = 64;
const ASSEMBLY_EFFICIENCY  : f32   = 2.0; // Max amount of parts used per assembly per tick

pub const BuildQueue = struct
{
  entries       : [ BUILD_QUEUE_CAPACITY ]BuildEntry = undefined,
  entryCount    : u64 = 0,


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

  pub inline fn getEntryCount( self : *BuildQueue ) u32
  {
    for( self.entries, 0.. )| e, idx |
    {
      if( e.buildCount == 0 ){ return @intCast( idx ); }
    }
    return self.entries.len;
  }


  pub fn update( self : *BuildQueue, econ : *ecn.Economy ) void
  {
    if( self.entryCount > 0 )
    {
      const assemblyIdx = IndType.ASSEMBLY.toIdx();

      var entriesClosed : u64 = 0;

      var availParts  = econ.indActivity[ assemblyIdx ];
          availParts *= @floatFromInt( econ.indBank[ assemblyIdx ]);
          availParts *= ASSEMBLY_EFFICIENCY;

      for( 0..self.entryCount )| idx |
      {
        var entry = &self.entries[ idx ];
        var unitsBuilt : f32 = 0;

        const unitPartCost = entry.construct.getPartCost();
        const unitsToBuild = entry.calcBuildableAmount( availParts );

        if( unitsToBuild > 0 )
        {
          unitsBuilt = @floatFromInt( econ.tryBuild( entry.construct, @intFromFloat( unitsToBuild )));

          entry.buildCount -= @intFromFloat( unitsBuilt );
          availParts       -= unitsBuilt * unitPartCost;

          // Failed to close the entry : likely cannot build anything more
          if( !entry.isEntryClosed() ){ break; }
        }

        entriesClosed += 1;

        //if( unitsToBuild > unitsBuilt ) break; // Encountered a building restriction ( cannot build any more )
        //if( availParts < unitPartCost ) break; // Used all available parts ( cannot build any more )

      }
      self.removeEntryAmount( entriesClosed );
    }
    return;
  }
};
