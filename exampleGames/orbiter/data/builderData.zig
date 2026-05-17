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
      .none => {   },
    }
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
      .none => {   },
    }
  }
};


// ================================ ENTRY TYPE & MODE ================================

pub const EntryTypeEnum = enum( u8 )
{
  CNSTR,
  DECNS,
  DESTR,
};

pub const EntryModeEnum = enum( u8 )
{
  SET_TO,
  ADD_TO,
  RAISE_TO,
  LOWER_TO,
  CANCEL,
};


// ================================ BUILD ENTRY STRUCT ================================

pub const BuildEntry = struct
{
  // NOTE : move resource and money pools to a per-agent matrix if this is too expensive
  remainStocks : gdf.ecnm_d.ResStockArray = .{}, // How much unused resources is there stored away

  remainFunds  : f64 = 0.0, // How much unused money is thereto buy resources with
  remainCnst   : f64 = 0.0, // How much unused construction cost ( "effort" ) is there to build a unit with
  unitCount    : f64 = 0.0, // How many units are there left to build

  construct : Construct     = .{ .none = {} },
  requester : Requester     = .{ .none = {} },
  entryType : EntryTypeEnum = .CNSTR,

  priority : u8 = 0, // Higher priority entries should be built first


  // ================ RESOURCE COSTS ================

  pub inline fn getUnitResCost( self : *const BuildEntry, resT : ResType ) f64
  {
    return self.construct.getResBldCost( resT );
  }

  pub inline fn getTotalResCost( self : *const BuildEntry, resT : ResType ) f64
  {
    return self.unitCount * self.getUnitResCost( resT );
  }

  pub inline fn getStoredResStock( self : *const BuildEntry, resT : ResType ) f64
  {
    return self.remainStocks.get( resT );
  }

  pub inline fn getRemainResCost( self : *const BuildEntry, resT : ResType ) f64
  {
    return self.getTotalResCost( resT ) - self.getStoredResStock( resT );
  }

  pub inline fn getBuildableWithRes( self : *const BuildEntry, resT : ResType ) f64
  {
    const resCost  = self.getUnitResCost( resT );
    const resStock = self.remainStocks.get( resT );

    return @divFloor( resStock, resCost );
  }

  /// Calculates the maximum amount of units that can be constructed with currently allocated resources
  pub fn getBuildableWithAnyRes( self : *const BuildEntry) f64
  {
    var buildable = self.unitCount;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      buildable  = @min( buildable, self.getBuildableWithRes( resT ));
    }

    return buildable;
  }

  // Returns false is it econcountered a resource shortage
  pub fn tryBuyRes( self : *BuildEntry, econ : *ecn.Economy ) bool
  {
    var resTypeCount : f64  = 0;
    var resShortage  : bool = false;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      // Count how many different resources remain to be purchased
      if( self.getRemainResCost( resT ) > 0.0 ){ resTypeCount += 1.0; }
    }

    if( resTypeCount == 0 ){ return true; }


    const fundsPerResType = self.remainFunds / resTypeCount;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      var purchaseAmount = @divFloor( fundsPerResType, resP );
      const econResStock = econ.resState.get( .COUNT, resT );

      if( purchaseAmount < econResStock )
      {
        purchaseAmount = econResStock;
        resShortage    = true;
      }
      if( purchaseAmount > def.EPS )
      {
        self.remainStocks.add( resT, purchaseAmount );
      //econ.resState.sub( .COUNT, resT, purchaseAmount ); // NOTE : pass consumption to solver instead

        // NOTE : money "vanishes" here, but this is fine, as money "appears" on resource production as well
      }
    }

    return( !resShortage );
  }

  // ================ CONSTRUCTION COSTS ================

  pub inline fn getUnitCnstCost( self : *const BuildEntry ) f64
  {
    return self.construct.getCnstCost();
  }

  pub inline fn getTotalCnstCost( self : *const BuildEntry ) f64
  {
    return self.unitCount * self.getUnitCnstCost();
  }

  pub inline fn getStoredCnstPrgrs( self : *const BuildEntry ) f64
  {
    return self.remainCnst;
  }

  pub inline fn getRemainCnstCost( self : *const BuildEntry ) f64
  {
    return self.getTotalCnstCost() - self.getStoredCnstPrgrs();
  }

  pub inline fn getBuildableWithCnst( self : *const BuildEntry ) f64
  {
    const cnstCost  = self.getUnitCnstCost();

    return @divFloor( self.remainCnst, cnstCost );
  }

  /// Returns the unused cnst
  pub fn tryGrantCnst( self : *BuildEntry, availCnst : f64 ) f64
  {
    const transferedCnst = @min( availCnst, self.getRemainCnstCost());

    self.remainCnst += transferedCnst;

    return availCnst - transferedCnst;


    // TODO : integrate assembly payments from requester here
  }

  // ================ FINANCIAL COSTS ================

  /// Uses current resource costs. Result is not inter-tick stable
  pub fn getUnitMoneyCost( self : *const BuildEntry, econ : *const ecn.Economy ) f64
  {
    var moneyCost = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      moneyCost += resP * self.getUnitResCost( resT );
    }

    return moneyCost;
  }

  /// Uses current resource costs. Result is not inter-tick stable
  pub inline fn getTotalMoneyCost( self : *const BuildEntry, econ : *const ecn.Economy ) f64
  {
    const  count : f64 = @floatFromInt( self.unitCount );
    return count * self.getUnitResCost( econ );
  }

  /// Uses current resource costs. Result is not inter-tick stable
  pub fn getRemainMoneyCost( self : *const BuildEntry, econ : *const ecn.Economy ) f64
  {
    var moneyCost = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resP = econ.resState.get( .PRICE, resT );

      moneyCost += resP * self.getRemainResCost( resT );
    }

    return moneyCost;
  }

  /// Returns the unused funds
  pub fn tryGrantFunds( self : *BuildEntry, econ : *const ecn.Economy, availFunds : f64 ) f64
  {
    const transferedFunds = @min( availFunds, self.getRemainMoneyCost( econ ));

    self.remainFunds += transferedFunds;

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
    return( self.unitCount < def.EPS );
  }

  pub inline fn deactivate( self : *BuildEntry ) bool
  {
    self.* = .{}; // TODO : check if this resets the entry properly
  }


  pub inline fn matchesWith( self : *BuildEntry, other : *BuildEntry ) bool
  {
    if( !def.areContEqual( self.construct, other.construct )){ return false; }
    if( !def.areContEqual( self.requester, other.requester )){ return false; }
    if( !def.areContEqual( self.entryType, other.entryType )){ return false; }

    return true;
  }


  /// Calculates the maximum amount of units that can be constructed with currently allocated resources and "construction effort"
  pub inline fn getBuildableAmount( self : *const BuildEntry ) f64
  {
    return @min( self.getBuildableWithAnyRes(), self.getBuildableWithCnst() );
  }

  pub fn tryBuildUnits( self : *BuildEntry, econ : *ecn.Economy ) f64
  {
    const targetBuildCount = self.getBuildableAmount();
    if(   targetBuildCount < def.EPS ){ return 0.0; }

    const realBuildCount = econ.tryBuild( self.construct, targetBuildCount );
    if(   realBuildCount < def.EPS ){ return 0.0; }

    self.unitCount -= realBuildCount;

    // Removing consumed resources
    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      self.remainStocks.sub( resT, realBuildCount * self.getUnitResCost( resT ));
    }

    // Removing consumed construction effort
    self.remainCnst -= ( realBuildCount * self.getUnitCnstCost() );

    return realBuildCount;
  }

  // ================ DEBUG FUNCTIONS ================

  pub inline fn debugLogSimple( self : *const BuildEntry ) void
  {
    const constructName = switch( self.construct )
    {
      .infT => | f | @tagName( f ),
      .indT => | d | @tagName( d ),
    //.vesT => | v | @tagName( v ),
      .none => "NONE",
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
    const typeName = @tagName( self.entryType );

    def.log( .CONT, 0, @src(), "{s} -> {d:.0} x {s} ( {s} )", .{ requesterName, self.unitCount, constructName, typeName });
  }
};