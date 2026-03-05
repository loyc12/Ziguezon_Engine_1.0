const std = @import( "std" );
const def = @import( "defs" );

const ves = @import( "vessel.zig" );
const res = @import( "resource.zig" );
const inf = @import( "infrastructure.zig" );
const ind = @import( "industry.zig" );
const cst = @import( "construct.zig" );

const ecn = @import( "economy.zig" );


pub const vesTypeCount = ves.vesTypeCount;
pub const resTypeCount = res.resTypeCount;
pub const infTypeCount = inf.infTypeCount;
pub const indTypeCount = ind.indTypeCount;

pub const VesType = ves.VesType;
pub const ResType = res.ResType;
pub const InfType = inf.InfType;
pub const IndType = ind.IndType;

pub const VesInstance = ves.VesInstance;
pub const ResInstance = res.ResInstance;
pub const InfInstance = inf.InfInstance;
pub const IndInstance = ind.IndInstance;

pub const Construct = cst.Construct;


pub const BuildEntry = struct
{
  construct  : Construct = .{ .inf = InfType.HOUSING },
  buildCount : u64 = 0,

  pub inline fn isEntryClosed( self : *const BuildEntry ) bool
  {
    return( self.buildCount == 0 );
  }

  pub inline fn getUnitPartCost( self : *const BuildEntry ) u64
  {
    return self.construct.getPartCost();
  }

  pub inline fn getRemainingPartCost( self : *const BuildEntry ) u64
  {
    return ( self.buildCount * self.getUnitPartCost() );
  }

  pub fn calcBuildableAmount( self : *BuildEntry, availParts : u64 ) u64
  {
    const unitPartCost = self.getUnitPartCost();

    if( availParts > self.buildCount * unitPartCost )
    {
      return self.buildCount;
    }

    return @divFloor( availParts, unitPartCost );
  }
};


const BUILD_QUEUE_CAPACITY : usize = 64;
const ASSEMBLY_EFFICIENCY  : f32   = 2.0; // Max amount of parts used per assembly per tick

pub const BuildQueue = struct
{
  entries       : [ BUILD_QUEUE_CAPACITY ]BuildEntry = undefined,
  entryCount    : u64 = 0,
  leftoverParts : u64 = 0,


  pub fn init() BuildQueue
  {
    var queue : BuildQueue = .{ .entryCount = 0, .leftoverParts = 0 };

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
    if( self.entryCount > 0 and @TypeOf( c ) == @TypeOf( self.entries[ self.entryCount - 1 ].construct ))
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


  pub fn update( self : *BuildQueue, econ : *ecn.Economy ) void
  {
    if( self.entryCount == 0 )
    {
      econ.addResCount( .PART, self.leftoverParts );
      self.leftoverParts = 0;
      return;
    }

    const assemblyIdx = IndType.ASSEMBLY.toIdx();

    var availParts_f32  = ASSEMBLY_EFFICIENCY;
        availParts_f32 *= econ.indActivity[ assemblyIdx ];
        availParts_f32 *= @floatFromInt( econ.indBank[ assemblyIdx ]);

    var availParts : u64 = @intFromFloat( @floor( availParts_f32 ));
        availParts      += self.leftoverParts;

    var entriesClosed : u64 = 0;

    for( 0..self.entryCount )| idx |
    {
      var entry : *BuildEntry = &self.entries[ idx ];
      var unitsBuilt : u64 = 0;

      const unitPartCost = entry.construct.getPartCost();
      const unitsToBuild = entry.calcBuildableAmount( availParts );

      if( unitsToBuild > 0 )
      {
        unitsBuilt = econ.tryBuild( entry.construct, unitsToBuild );

        entry.buildCount -= unitsBuilt;
        availParts       -= unitsBuilt * unitPartCost;
      }

      // Encountered a building restriction
      if( unitsToBuild != unitsBuilt )
      {
        self.leftoverParts += availParts;
        break;
      }

      // Closed the current building order ( all unit built )
      if( entry.isEntryClosed() )
      {
        entriesClosed += 1;
        continue;
      }

      // Used all availalbe parts
      if( availParts < unitPartCost )
      {
        self.leftoverParts += availParts;
        break;
      }

      break;
    }
    self.removeEntryAmount( entriesClosed );
  }
};
