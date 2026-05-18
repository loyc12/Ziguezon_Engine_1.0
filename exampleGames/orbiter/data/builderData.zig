const std = @import( "std" );
const def = @import( "defs" );


const gdf = @import( "../gameDefs.zig"    );
const ecn = gdf.ecn;

const PopType = gdf.PopType;
const InfType = gdf.InfType;
const IndType = gdf.IndType;
const VesType = gdf.VesType;
const ResType = gdf.ResType;

const resTypeC = ResType.count;


pub const RECYCLING_RES_FACTOR  : f64 = -0.25; // [ -1.0, 0.0 ], How much resources will be salvaged
pub const RECYCLING_CNST_FACTOR : f64 =  0.10; // [  0.0, 1.0 ], How much of the initial construction effort is needed for destruction


// ================================ CONSTRUCT ================================

pub const ConstructTag = enum( u4 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  infT,
  indT,
//vesT,
  none,
};

pub const Construct = union( ConstructTag ) // Union of buildable things
{
  infT : InfType,
  indT : IndType,
//vesT : VesType,
  none : void,


  pub fn canBeBuiltIn( c : Construct, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    return switch( c )
    {
      .infT => | f | f.canBeBuiltIn( loc, hasAtmo ),
      .indT => | d | d.canBeBuiltIn( loc, hasAtmo ),
    //.vesT => | v | v.canBeBuiltIn( loc, hasAtmo ),
      .none => false,
    };
  }

  pub fn getMass( c : Construct ) f64
  {
    return switch( c )
    {
      .infT => | f | f.getMetric_f64( .MASS ),
      .indT => | d | d.getMetric_f64( .MASS ),
    //.vesT => | v | v.getMetric_f64( .MASS ),
      .none =>  0.0,
    };
  }

  pub fn getAreaCost( c : Construct ) f64
  {
    return switch( c )
    {
      .infT => | f | f.getMetric_f64( .AREA_COST ),
      .indT => | d | d.getMetric_f64( .AREA_COST ),
    //.vesT =>  0.0,
      .none =>  0.0,
    };
  }

  pub fn getCnstCost( c : Construct ) f64
  {
    return switch( c )
    {
      .infT => | f | f.getMetric_f64( .CNST_COST ),
      .indT => | d | d.getMetric_f64( .CNST_COST ),
    //.vesT => | v | v.getMetric_f64( .CNST_COST ),
      .none =>  0.0,
    };
  }

  pub fn getCapacity( c : Construct ) f64
  {
    return switch( c )
    {
      .infT => | f | f.getMetric_f64( .CAPACITY ),
      .indT =>  0.0,
    //.vesT => | v | v.getMetric_f64( .CAPACITY ),
      .none =>  0.0,
    };
  }

  pub fn getResBldCost( c : Construct, resT : ResType ) f64
  {
    return switch( c )
    {
      .infT => | f | f.getResMetric_f64( .BUILD, resT ),
      .indT => | d | d.getResMetric_f64( .BUILD, resT ),
    //.vesT => | v | v.getResMetric_f64( .BUILD, resT ),
      .none =>  0.0,
    };
  }
  pub fn getResMntCost( c : Construct, resT : ResType ) f64
  {
    return switch( c )
    {
      .infT => | f | f.getResMetric_f64( .MAINT, resT ), // Paid continually based on usage
      .indT => | d | d.getResMetric_f64( .MAINT, resT ), // Paid continually based on activity
    //.vesT => | v | v.getResMetric_f64( .MAINT, resT ), // Paid after arrival based on travel duration
      .none =>  0.0,
    };
  }
};


// ================================ REQUESTER ================================

pub const RequesterTag = enum( u4 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  popT,
  infT,
  indT,
//com,
  gov,
  none,
};

pub const Requester = union( RequesterTag ) // Union of builder (sub)agents
{
  popT : PopType,
  infT : InfType,
  indT : IndType,
//com  : void,
  gov  : void,
  none : void,


  pub fn getAgentSavings( econ : *ecn.Economy, q : Requester ) f64
  {
    return switch( q )
    {
      .popT => | p | econ.popState.get( .SAVINGS, p ),
      .infT => | f | econ.infState.get( .SAVINGS, f ),
      .indT => | d | econ.indState.get( .SAVINGS, d ),
    //.com  =>       econ.comState.set( .SAVINGS    ),
      .gov  =>       econ.govState.set( .SAVINGS    ),
      .none =>  0.0,
    };
  }

  pub fn addAgentSavings( econ : *ecn.Economy, q : Requester, val : f64 ) void
  {
    switch( q )
    {
      .popT => | p | econ.popState.add( .SAVINGS, p, val ),
      .infT => | f | econ.infState.add( .SAVINGS, f, val ),
      .indT => | d | econ.indState.add( .SAVINGS, d, val ),
    //.com  =>       econ.comState.add( .SAVINGS,    val ),
      .gov  =>       econ.govState.add( .SAVINGS,    val ),
      .none =>       return,
    }


    // Debug logging
    const requesterName = switch( q )
    {
      .popT => | p | @tagName( p ),
      .infT => | f | @tagName( f ),
      .indT => | d | @tagName( d ),
    //.com  => "COMMERCIAL",
      .gov  => "GOVERNMENT",
      .none => "*NONE*",
    };

    def.log( .DEBUG, 0, @src(), "# Gave {d:.2}$ to {s}", .{ val, requesterName });
  }

  pub fn subAgentSavings( econ : *ecn.Economy, q : Requester, val : f64 ) void
  {
    switch( q )
    {
      .popT => | p | econ.popState.sub( .SAVINGS, p, val ),
      .infT => | f | econ.infState.sub( .SAVINGS, f, val ),
      .indT => | d | econ.indState.sub( .SAVINGS, d, val ),
    //.com  =>       econ.comState.sub( .SAVINGS,    val ),
      .gov  =>       econ.govState.sub( .SAVINGS,    val ),
      .none =>       return,
    }


    // Debug logging
    const requesterName = switch( q )
    {
      .popT => | p | @tagName( p ),
      .infT => | f | @tagName( f ),
      .indT => | d | @tagName( d ),
    //.com  => "COMMERCIAL",
      .gov  => "GOVERNMENT",
      .none => "*NONE*",
    };

    def.log( .DEBUG, 0, @src(), "# Took {d:.2}$ from {s}", .{ val, requesterName });
  }
};


// ================================ ENTRY TYPE & MODE ================================

pub const EntryTypeEnum = enum( u8 )
{
  CNSTR,
  RECYC,
  DESTR,
//MAINT,
};

pub const EntryModeEnum = enum( u8 )
{
  ADD_TO,
  SET_TO,
  RAISE_TO,
  LOWER_TO,
  CANCEL,
};


// ================================ BUILD ENTRY STRUCT ================================

pub const BuildEntry = struct
{
  // NOTE : Consider moving resource and money pools to a per-agent matrix if this is too expensive
  stashedRes   : gdf.ecnm_d.ResStockArray = .{}, // How much unused resources is there stored away

  stashedFunds : f64 = 0.0, // How much unused money is there to buy resources with
  stashedCnst  : f64 = 0.0, // How much unused construction ( "effort" ) is there to build a unit with
  unitCount    : f64 = 0.0, // How many units are there left to build

  construct : Construct     = .{ .none = {} },
  requester : Requester     = .{ .none = {} },
  entryType : EntryTypeEnum = .CNSTR,

  priority : u8 = 0, // Higher priority entries should be built first


  // ================ RESOURCE COSTS ================

  /// Returns negative values if refunding resources
  pub inline fn getUnitResCost( self : *const BuildEntry, resT : ResType ) f64
  {
    return switch( self.entryType )
    {
      .CNSTR => self.construct.getResBldCost( resT ),
      .RECYC => self.construct.getResBldCost( resT ) * RECYCLING_RES_FACTOR,
      .DESTR => 0.0,
    };
  }

  /// Returns negative values if refunding resources
  pub inline fn getTotalResCost( self : *const BuildEntry, resT : ResType ) f64
  {
    return self.unitCount * self.getUnitResCost( resT );
  }

  pub inline fn getStoredResStock( self : *const BuildEntry, resT : ResType ) f64
  {
    return self.stashedRes.get( resT );
  }

  pub inline fn getStoredResSum( self : *const BuildEntry ) f64
  {
    var resSum : f64 = 0;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      resSum += self.getStoredResStock( resT );
    }

    return resSum;
  }

  pub inline fn getRemainResCost( self : *const BuildEntry, resT : ResType ) f64
  {
    if( self.entryType != .CNSTR ){ return 0.0; }

    return self.getTotalResCost( resT ) - self.getStoredResStock( resT );
  }

  /// Calculates how many units can be built from a specific resource's current stocks
  pub inline fn getBuildableWithRes( self : *const BuildEntry, resT : ResType ) f64
  {
    if( self.entryType != .CNSTR ){ return self.unitCount; }

    const resCost  = self.getUnitResCost(   resT );
    const resStock = self.stashedRes.get( resT );

    return @divFloor( resStock, resCost );
  }


  /// Calculates how many units can be built from any resource's current stocks
  pub fn getBuildableWithAnyRes( self : *const BuildEntry) f64
  {
    if( self.entryType != .CNSTR ){ return self.unitCount; }

    var buildable = self.unitCount;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      buildable  = @min( buildable, self.getBuildableWithRes( resT ));
    }

    return buildable;
  }

  // Returns false is it encountered a resource shortage
  pub fn tryBuyRes( self : *BuildEntry, econ : *ecn.Economy ) bool
  {
    if( self.entryType != .CNSTR ){ return true; }

    var resTypeCount : f64  = 0.0;
    var resShortage  : bool = false;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      // Counts how many different resource types need to be purchased
      if( self.getRemainResCost( resT ) > 0.0 ){ resTypeCount += 1.0; }
    }

    if( resTypeCount == 0 ){ return true; }


    // Split funds equally across all resources
    // NOTE : This is a naive approach
    // TODO : Rework once this causes issues
    const fundsPerResType = self.stashedFunds / resTypeCount;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      var   boughtAmount = self.getRemainResCost( resT );
            boughtAmount = @min( boughtAmount, @divFloor( fundsPerResType, resP ));
      const econResStock = econ.resState.get( .COUNT, resT );

      if( boughtAmount < econResStock )
      {
        boughtAmount = econResStock;
        resShortage  = true;
      }
      if( boughtAmount > def.EPS )
      {
        self.stashedRes.add(       resT, boughtAmount );
        econ.resState.sub( .COUNT,   resT, boughtAmount );
        econ.resState.sub( .COUNT_D, resT, boughtAmount );

        // NOTE : money "vanishes" here, but this is fine, as money "appears" on resource production as well
      }
    }

    return( !resShortage );
  }


  // ================ CONSTRUCTION COSTS ================

  pub inline fn getUnitCnstCost( self : *const BuildEntry ) f64
  {
    return switch( self.entryType )
    {
      .CNSTR => self.construct.getCnstCost(),
      .RECYC => self.construct.getCnstCost() * RECYCLING_CNST_FACTOR,
      .DESTR => 0.0,
    };
  }

  pub inline fn getTotalCnstCost( self : *const BuildEntry ) f64
  {
    return self.unitCount * self.getUnitCnstCost();
  }

  pub inline fn getStoredCnst( self : *const BuildEntry ) f64
  {
    return self.stashedCnst;
  }

  pub inline fn getRemainCnstCost( self : *const BuildEntry ) f64
  {
    if( self.entryType == .DESTR ){ return 0.0; }

    return self.getTotalCnstCost() - self.getStoredCnst();
  }

  pub inline fn getBuildableWithCnst( self : *const BuildEntry ) f64
  {
    if( self.entryType == .DESTR ){ return self.unitCount; }

    const cnstCost = self.getUnitCnstCost();

    return @divFloor( self.stashedCnst, cnstCost );
  }

  /// Returns the unused cnst
  pub fn tryGrantCnst( self : *BuildEntry, availCnst : f64 ) f64
  {
    if( self.entryType == .DESTR ){ return availCnst; }

    const transferedCnst = @min( availCnst, self.getRemainCnstCost());

    self.stashedCnst += transferedCnst;

    return availCnst - transferedCnst;

  }


  // ================ FINANCIAL COSTS ================

  /// Uses current resource costs. Result is not inter-tick stable
  pub fn getUnitCashCost( self : *const BuildEntry, econ : *const ecn.Economy ) f64
  {
    if( self.entryType == .DESTR ){ return 0.0; }

    var cashCost = 0.0;       // TODO : integrate assembly cnstr payments in costs


    if( self.entryType == .RECYC ){ return cashCost; }

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      cashCost += resP * self.getUnitResCost( resT );
    }

    return cashCost;
  }

  /// Uses current resource costs. Result is not inter-tick stable
  pub inline fn getTotalCashCost( self : *const BuildEntry, econ : *const ecn.Economy ) f64
  {
    return self.unitCount * self.getUnitResCost( econ );
  }

  /// Uses current resource costs. Result is not inter-tick stable
  pub fn getRemainCashCost( self : *const BuildEntry, econ : *const ecn.Economy ) f64
  {
    if( self.entryType == .DESTR ){ return 0.0; }

    var cashCost = 0.0;       // TODO : integrate assembly cnstr payments in costs


    if( self.entryType == .RECYC ){ return cashCost; }

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      cashCost += resP * self.getRemainResCost( resT );
    }

    return cashCost;
  }

  /// Returns the unused funds
  pub fn tryGrantFunds( self : *BuildEntry, econ : *const ecn.Economy, availFunds : f64 ) f64
  {
    if( self.entryType == .DESTR ){ return availFunds; }

    const transferedFunds = @min( availFunds, self.getRemainCashCost( econ ));

    self.stashedFunds += transferedFunds;

    return availFunds - transferedFunds;
  }


  // ================ HELPER FUNCTIONS ================

  pub inline fn isValid( self : *const BuildEntry ) bool
  {
    switch( self.requester )
    {
      .none => return false,
       else => {},
    }
    switch( self.construct )
    {
      .none => return false,
       else => {},
    }
    return( true );
  }

  pub inline fn isClosed( self : *const BuildEntry ) bool
  {
    return( self.unitCount < 1.0 - def.EPS );
  }

  pub inline fn deactivate( self : *BuildEntry ) bool
  {
    self.* = .{}; // TODO : check if this resets the entry properly
  }


  pub inline fn matchesWithPart( self : *const BuildEntry, other : *const BuildEntry ) bool
  {
    if( !def.areContEqual( self.construct, other.construct )){ return false; }
    if( !def.areContEqual( self.requester, other.requester )){ return false; }

    return true;
  }


  pub inline fn matchesWithFull( self : *const BuildEntry, other : *const BuildEntry ) bool
  {
    if( !def.areContEqual( self.construct, other.construct )){ return false; }
    if( !def.areContEqual( self.requester, other.requester )){ return false; }
    if( !def.areContEqual( self.entryType, other.entryType )){ return false; }

    return true;
  }


  /// Calculates the maximum amount of units that can be constructed with currently allocated resources and "construction effort"
  pub inline fn getBuildableAmount( self : *const BuildEntry ) f64
  {
    return switch( self.entryType )
    {
      .CNSTR => @min( self.getBuildableWithCnst(), self.getBuildableWithAnyRes() ),
      .RECYC =>       self.getBuildableWithCnst(),
      .DESTR =>       self.unitCount,
    };
  }

  pub fn tryBuildUnits( self : *BuildEntry, econ : *ecn.Economy ) f64
  {
    const targetBuildCount = self.getBuildableAmount();
    if(   targetBuildCount < def.EPS ){ return 0.0; }

    var realBuildCount : f64 = 0.0;

    switch( self.entryType )
    {
      .CNSTR => { realBuildCount = econ.tryBuilding( self.construct, targetBuildCount ); },
      .RECYC => { realBuildCount = econ.tryDestroying(   self.construct, targetBuildCount ); },
      .DESTR => { realBuildCount = econ.tryDestroying(   self.construct, targetBuildCount ); },
    }

    if( realBuildCount < def.EPS ){ return 0.0; }

    self.unitCount -= realBuildCount;

    if( self.entryType != .DESTR )
    {
      // Removing consumed resources / Adding resources recycled
      inline for( 0..resTypeC )| r |
      {
        const resT = ResType.fromIdx( r );

        self.stashedRes.add( resT, -realBuildCount * self.getUnitResCost( resT ));
      }

      // Removing consumed construction effort
      self.stashedCnst -= ( realBuildCount * self.getUnitCnstCost() );
    }

    return realBuildCount;
  }


  // ================ DEBUG FUNCTIONS ================

  pub fn debugLogSimple( self : *const BuildEntry ) void
  {
    const constructName = switch( self.construct )
    {
      .infT => | f | @tagName( f ),
      .indT => | d | @tagName( d ),
    //.vesT => | v | @tagName( v ),
      .none => "*NONE*",
    };
    const requesterName = switch( self.requester )
    {
      .popT => | p | @tagName( p ),
      .infT => | f | @tagName( f ),
      .indT => | d | @tagName( d ),
    //.com  => "COMMERCIAL",
      .gov  => "GOVERNMENT",
      .none => "*NONE*",
    };
    const entryType = switch( self.entryType )
    {
      .CNSTR => "CONSTRUCTING",
      .RECYC => "RECYCLING",
      .DESTR => "DESTROYING",
    };

    def.log( .CONT, 0, @src(), "# {s} -> {s} {d:.0} units of {s}", .{ requesterName, entryType, self.unitCount, constructName });
  }

  pub inline fn debugLogComplex( self : *const BuildEntry ) void
  {
    self.debugLogSimple();
    def.log( .CONT, 0, @src(), " - {d:.2}$ | {d:.2}c | {d:.0}r | #{d:.0}", .{ self.stashedFunds, self.stashedCnst, self.getStoredResSum(), self.priority });
  }
};


//remainStocks : gdf.ecnm_d.ResStockArray = .{}, // How much unused resources is there stored away
//
//remainFunds  : f64 = 0.0, // How much unused money is thereto buy resources with
//remainCnst   : f64 = 0.0, // How much unused construction cost ( "effort" ) is there to build a unit with
//unitCount    : f64 = 0.0, // How many units are there left to build
//
//construct : Construct     = .{ .none = {} },
//requester : Requester     = .{ .none = {} },
//entryType : EntryTypeEnum = .CNSTR,
//
//priority : u8 = 0, // Higher priority entries should be built first