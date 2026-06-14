const std = @import( "std" );
const utl = @import( "utils" );


pub const ecnSlvr = @import( "econSolver.zig"  );
pub const ecnBldr = @import( "econBuilder.zig" );
pub const ecnEco  = @import( "ecology.zig"     );

pub const BuildQueue = ecnBldr.BuildQueue;
pub const Ecology    = ecnEco.EcoState;

const dbgBld = @import( "econAutoBuild.zig" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig" );

const EconLoc = gdf.EconLoc;

const PowerSrc  = gdf.PowerSrc;
const VesType   = gdf.VesType;
const ResType   = gdf.ResType;
const PopType   = gdf.PopType;
const InfType   = gdf.InfType;
const IndType   = gdf.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const popTypeC  = PopType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;


const MIN_RES_CAP = 10_000.0;

pub const Economy = struct
{
  location       : EconLoc = .GROUND,
  settlementType : gdf.SettlementType = .surface,

  isValid   : bool = false,
  isActive  : bool = false,
  hasAtmo   : bool = false,

  stepCount : u64 = 0,
  sunshine  : f64 = 0.0, // How much sunlight reachs the econ's location from the sun
  sunAccess : f32 = 0.0, // How much sunlight is accessible to the econ, ( scaled + clamped )

  ecology    : ?Ecology    = null,
  buildQueue : ?BuildQueue = null,

  resState : gdf.rsrc_d.ResStateData = .{},
  popState : gdf.popl_d.PopStateData = .{},
  infState : gdf.nfrs_d.InfStateData = .{},
  indState : gdf.ndst_d.IndStateData = .{},

  agtState : gdf.ecnm_d.AgentStateData = .{},
  areaData : gdf.ecnm_d.EconAreaData   = .{},

  govState : gdf.gvmt_d.GovMonetaryData = .{},
//comState :

  // ================================ INIT ================================

  pub inline fn newDeadEcon( loc : EconLoc ) Economy
  {
    var econ : Economy = .{};

    econ.softInit( loc );

    return econ;
  }

  pub inline fn softInit( self : *Economy, loc : EconLoc ) void
  {
    self.softInitForSettlement( loc, .fromCompatLocation( loc ) );
  }

  /// Resets lifecycle flags while preserving the new settlement-rule metadata.
  pub inline fn softInitForSettlement( self : *Economy, loc : EconLoc, settlementType : gdf.SettlementType ) void
  {
    self.isValid    = true;
    self.isActive   = false;
    self.hasAtmo    = false;
    self.location   = loc;
    self.settlementType = settlementType;
    self.ecology    = null;
    self.buildQueue = null;
  }


  pub inline fn newLiveEcon( loc : EconLoc, area : f64, landCover : f64, atmo : bool ) Economy
  {
    var econ : Economy = .{};

    econ.hardInit( loc, area, landCover, atmo );

    return econ;
  }

  pub inline fn hardInit( self : *Economy, loc : EconLoc, area : f64, landCover : f64, atmo : bool ) void
  {
    self.hardInitForSettlement( loc, .fromCompatLocation( loc ), area, landCover, atmo );
  }

  /// Fully initializes an economy using settlement metadata instead of deriving
  /// economy rules from the temporary `EconLoc` compatibility value.
  pub inline fn hardInitForSettlement( self : *Economy, loc : EconLoc, settlementType : gdf.SettlementType, area : f64, landCover : f64, atmo : bool ) void
  {
    self.softInitForSettlement( loc, settlementType );

    self.hasAtmo  = atmo;

    self.resState.fillWith( 0.0 );
    self.popState.fillWith( 0.0 );
    self.infState.fillWith( 0.0 );
    self.indState.fillWith( 0.0 );

    self.agtState.fillWith( 0.0 );
    self.areaData.fillWith( 0.0 );

    self.areaData.set( .BODY,  area      );
    self.areaData.set( .INHAB, landCover );

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      self.resState.set( .LIMIT, resT, MIN_RES_CAP );
      self.resState.set( .PRICE, resT, resT.getMetric_f64( .PRICE_BASE ));
    }

    inline for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );

      self.indState.set( .ACT_TRGT, indT, 1.0 );
    }

    self.buildQueue = BuildQueue.init();

    self.updateAreas();

    if( self.hasEcology() )
    {
      self.ecology = .init( self );
    }
  }


  // ================================ DEBUG INIT ================================

  // Setups the economy needed to support value * 10k pop
  pub inline fn debugSetEconState( self : *Economy, value : u64, sunshine : f64 ) void
  {
    self.debugSetInfCounts( value );
    self.debugSetIndCounts( value );
    self.debugSetResCounts( value );
    self.debugSetPopCounts( value );

    // Updating dependant systems based on newly updated counts
    self.updateAreas();
    self.updateInfUsage();
    self.updateSunshine( sunshine );

    if( self.hasEcology() ){ self.ecology.?.seed( self ); }

    // Logging new metrics
    self.logSpecialMetrics();
    ecnSlvr.debugTestEcon( self );
  }

  pub inline fn debugSetPopCounts(  self : *Economy, value : u64 ) void
  {
    self.setPopCount( .WORKER, value * gdf.G_FLAGS.DEFAULT_POP );
  }

  pub inline fn debugSetResCounts(  self : *Economy, value : u64 ) void
  {
    _ = value;

    const depotSeedUse = self.getDepotStorageCapacity() * 0.20;
    const depotWeight  = self.getDebugDepotSeedWeight();

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resL  = self.resState.get( .LIMIT, resT );

    // Start at 20% of cap - leaves room for production without crashing prices
      var amount = resL * 0.2;

      const seedWeight = switch( resT )
      {
        .LABOUR  => 1.00,
        .FUEL  => 0.05,
        .FOOD  => 0.25,
        .WATER => 0.25,
        .POWER => 0.25,
        .ORE   => 0.25,
        .INGOT => 0.25,
        .PART  => 0.05,
      };

      if( resT.usesSharedDepot() and depotWeight > utl.EPS )
      {
        // Shared storage seed: distribute one depot fill target across ordinary
        // resources instead of filling each resource as if it had its own depot.
        const storeRate = resT.getMetric_f64( .STORE_RATE );
        amount = ( depotSeedUse * seedWeight / depotWeight ) / storeRate;
      }
      else
      {
        amount *= seedWeight;
      }

      amount = @ceil( amount );

      self.resState.set( .COUNT, resT, amount );
    }
  }

  pub inline fn debugSetInfCounts( self : *Economy, value : u64 ) void
  {
    if( self.location != .GROUND or !self.hasAtmo )
    {
      self.infState.set( .COUNT, .HABITAT,  @floatFromInt( value * 1024 )); // TODO : RECOMPUTE AND VALIDATE
    }
    self.infState.set(   .COUNT, .HOUSING,  @floatFromInt( value * 1024 ));
    self.infState.set(   .COUNT, .ASSEMBLY, @floatFromInt( value *  128 ));
    self.infState.set(   .COUNT, .DEPOT,    @floatFromInt( value *  128 ));

    self.updateResCaps();
    self.updatePopCaps();
  }

  pub inline fn debugSetIndCounts( self : *Economy, value : u64 ) void
  {
    if( self.hasAtmo )
    {
      self.indState.set( .COUNT, .AGRONOMIC,   @floatFromInt( value *  4 ));
      self.indState.set( .COUNT, .HYDROPONIC,  @floatFromInt( value *  4 ));
      self.indState.set( .COUNT, .WATER_PLANT, @floatFromInt( value *  4 ));
      self.indState.set( .COUNT, .SOLAR_PLANT, @floatFromInt( value * 20 ));
      self.indState.set( .COUNT, .POWER_PLANT, @floatFromInt( value *  4 ));

      self.indState.set( .COUNT, .REFINERY,    @floatFromInt( value *  1 ));
      self.indState.set( .COUNT, .GROUND_MINE, @floatFromInt( value * 20 ));
      self.indState.set( .COUNT, .FOUNDRY,     @floatFromInt( value * 20 ));
      self.indState.set( .COUNT, .FACTORY,     @floatFromInt( value * 40 ));
    }
    else if( self.location == .GROUND )
    {
      // Airless ground body (Moon, Mars without atmo, etc.)
      self.indState.set( .COUNT, .HYDROPONIC,  @floatFromInt( value *   8 ));
      self.indState.set( .COUNT, .WATER_PLANT, @floatFromInt( value *   6 ));
      self.indState.set( .COUNT, .SOLAR_PLANT, @floatFromInt( value *  20 ));
      self.indState.set( .COUNT, .POWER_PLANT, @floatFromInt( value *   4 ));

      self.indState.set( .COUNT, .REFINERY,    @floatFromInt( value *   1 ));
      self.indState.set( .COUNT, .PROBE_MINE,  @floatFromInt( value * 500 ));
      self.indState.set( .COUNT, .GROUND_MINE, @floatFromInt( value *  18 ));
      self.indState.set( .COUNT, .FOUNDRY,     @floatFromInt( value *  20 ));
      self.indState.set( .COUNT, .FACTORY,     @floatFromInt( value *  40 ));
    }
    else // NOTE : Will collapse without imports
    {
      // Orbital / Lagrange
      self.indState.set( .COUNT, .HYDROPONIC,  @floatFromInt( value * 10 ));
      self.indState.set( .COUNT, .WATER_PLANT, @floatFromInt( value * 10 ));
      self.indState.set( .COUNT, .SOLAR_PLANT, @floatFromInt( value * 50 ));
    }
  }


  // ================================ DEBUG LOGS ================================

  pub inline fn logSpecialMetrics( self : *const Economy ) void
  {
    if( self.ecology != null )
    {
      self.ecology.?.logEco();
    }

    const areaUsed = self.areaData.get( .USED );
    const areaCap  = self.areaData.get( .CAP  );

    utl.qlog( .INFO, @src(), "$ Logging general metrics :" );
    utl.log(  .CONT, @src(), "Step count  : {d:.6}", .{ self.stepCount });
    utl.log(  .CONT, @src(), "Sunshine    : {d:.6} / {d:.6}", .{ self.sunAccess, self.sunshine });
    utl.log(  .CONT, @src(), "Development : {d:.0} / {d:.0} ( {d:.2}% )", .{ areaUsed, areaCap, ( areaUsed / areaCap) * 100.0 });
  }


  // ================================ POPULATION ================================

  pub fn getTotalPopCap( self : *const Economy ) u64
  {
    var totalCap : u64 = 0;

    inline for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );

      totalCap += self.getPopCap( popT );
    }

    return totalCap;
  }
  pub inline fn getTotalPopCount( self : *const Economy ) u64
  {
    var totalCount : u64 = 0;

    inline for( 0..popTypeC )| p |
    {
      const popT = PopType.fromIdx( p );

      totalCount += self.getPopCount( popT );
    }

    return totalCount;
  }

  pub fn updatePopCaps( self : *Economy ) void
  {
    inline for( 0..popTypeC )| r |
    {
      const popT    = PopType.fromIdx( r );
      const popCost = popT.getMetric_f64( .HSNG_COST );

      const infT = popT.getInfStore();
      const infC = self.infState.get( .COUNT, infT );
      const cap  = infT.getMetric_f64( .CAPACITY );

      self.popState.set( .LIMIT, popT, infC * cap / popCost );
    }
  }
  pub inline fn getPopCap( self : *const Economy, popT : PopType ) u64
  {
    return @intFromFloat( self.popState.get( .LIMIT, popT ));
  }
  pub inline fn getPopCount( self : *const Economy, popT : PopType ) u64
  {
    return @intFromFloat( self.popState.get( .COUNT, popT ));
  }

  /// Ignores popCap
  pub inline fn setPopCount( self : *Economy, popT : PopType, value : u64 ) void
  {
    self.popState.set( .COUNT, popT, @floatFromInt( value ));
  }
  pub inline fn addPopCount( self : *Economy, popT : PopType, value : u64 ) void
  {
    const cap      = self.getPopCap(   popT );
    const oldCount = self.getPopCount( popT );
    const newCount = @min( value +| oldCount, cap );

    if( newCount - oldCount != value )
    {
      utl.log( .WARN, @src(), "@ Tried to add {d} pops to economy, but only had space for {d}", .{ value, newCount - oldCount });
    }
    self.setPopCount( popT, newCount );
  }
  pub inline fn subPopCount( self : *Economy, popT : PopType, value : u64 ) void
  {
    const oldCount = self.getPopCount( popT );
    const newCount = @max( oldCount -| value, 0 ); // Writen like this for clarity

    if( oldCount - newCount != value )
    {
      utl.log( .WARN, @src(), "@ Tried to remove {d} pops from economy, but only had {d} left", .{ value, oldCount - newCount });
    }
    self.setPopCount( popT, newCount );
  }


  // ================================ RESSOURCES ================================

  fn getDebugDepotSeedWeight( self : *const Economy ) f64
  {
    _ = self;

    var totalWeight : f64 = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );

      if( resT.usesSharedDepot() )
      {
        totalWeight += switch( resT )
        {
          .FUEL  => 0.05,
          .FOOD  => 0.25,
          .WATER => 0.25,
          .POWER => 0.25,
          .ORE   => 0.25,
          .INGOT => 0.25,
          .PART  => 0.05,
          else   => 0.00,
        };
      }
    }

    return totalWeight;
  }

  /// Returns the single ordinary-resource depot pool for the current economy.
  pub inline fn getDepotStorageCapacity( self : *const Economy ) f64
  {
    const depotCount = self.infState.get( .COUNT, .DEPOT );
    const depotCap   = InfType.DEPOT.getMetric_f64( .CAPACITY );

    return MIN_RES_CAP + ( depotCount * depotCap );
  }

  pub inline fn getResStorageUse( self : *const Economy, resT : ResType, amount : f64 ) f64
  {
    _ = self;

    if( !resT.usesSharedDepot() ){ return 0.0; }

    return amount * resT.getMetric_f64( .STORE_RATE );
  }

  pub fn getDepotStorageUse( self : *const Economy ) f64
  {
    var used : f64 = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const resC = self.resState.get( .COUNT, resT );

      used += self.getResStorageUse( resT, resC );
    }

    return used;
  }

  pub fn updateResCaps( self : *Economy ) void
  {
    const depotCapacity = self.getDepotStorageCapacity();

    inline for( 0..resTypeC )| r |
    {
      const resT = ResType.fromIdx( r );
      const storeRate = resT.getMetric_f64( .STORE_RATE );

      var nextLimit : f64 = 0.0;

      if( resT.usesSharedDepot() )
      {
        // Compatibility limit: maximum stock if the shared depot were dedicated
        // to this resource. Actual overflow uses aggregate depot consumption.
        nextLimit = depotCapacity / @max( storeRate, utl.EPS );
      }
      else
      {
        const infT = resT.getInfStore();
        const infC = self.infState.get(  .COUNT, infT );

        const capacity = infT.getMetric_f64( .CAPACITY );

        if( storeRate > utl.EPS )
        {
          nextLimit =  MIN_RES_CAP + ( infC * capacity / storeRate );
        }
        else
        {
          // Infinite storage ( or resource doesn't need storage )
          nextLimit = MIN_RES_CAP + ( infC * capacity / utl.EPS );
        }
      }

      self.resState.set( .LIMIT, resT, nextLimit );

    }
  }
  pub inline fn getResCap( self : *const Economy, resT : ResType ) u64
  {
    return @intFromFloat( self.resState.get( .LIMIT, resT ));
  }
  pub inline fn getResCount( self : *const Economy, resT : ResType ) u64
  {
    return @intFromFloat( self.resState.get( .COUNT, resT ));
  }

  pub inline fn setResCount( self : *Economy, resT : ResType, value : u64 ) void
  {
    const cap = self.getResCap( resT );
    self.resState.set( .COUNT, resT, @floatFromInt( @min( value, cap )));
  }
  pub inline fn addResCount( self : *Economy, resT : ResType, value : u64 ) void
  {
    const cap     = self.getResCap(   resT );
    const current = self.getResCount( resT );
    const new_val = @min( value + current, cap );
    self.resState.set( .COUNT, resT, @floatFromInt( new_val ));
  }
  pub inline fn subResCount( self : *Economy, resT : ResType, value : u64 ) void
  {
    const current = self.getResCount( resT );
    const count   = @min( value, current );
    self.resState.set( .COUNT, resT, @floatFromInt( current - count ));

    if( value != count )
    {
      utl.log( .WARN, @src(), "@ Tried to remove {d} resT of type {s} from economy, but only had {d} left", .{ value, @tagName( resT ), count });
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn getInfCount( self : *const Economy, infT : InfType ) u64
  {
    return @intFromFloat( self.infState.get( .COUNT, infT ));
  }
  pub inline fn setInfCount( self : *Economy, infT : InfType, value : u64 ) void
  {
    self.infState.set( .COUNT, infT, @floatFromInt( value ));
  }
  pub inline fn addInfCount( self : *Economy, infT : InfType, value : u64 ) void
  {
    const current = self.getInfCount( infT );
    self.infState.set( .COUNT, infT, @floatFromInt( value + current ));
  }
  pub inline fn subInfCount( self : *Economy, infT : InfType, value : u64 ) void
  {
    const current = self.getInfCount( infT );
    const count   = @min( value, current );
    self.infState.set( .COUNT, infT, @floatFromInt( current - count ));

    if( value != count )
    {
      utl.log( .WARN, @src(), "@ Tried to remove {d} infT of type {s} from economy, but only had {d} left", .{ value, @tagName( infT ), count });
    }
  }


  // ================================ INDUSTRY ================================

  pub inline fn getIndCount( self : *const Economy, indT : IndType ) u64
  {
    return @intFromFloat( self.indState.get( .COUNT, indT ));
  }
  pub inline fn setIndCount( self : *Economy, indT : IndType, value : u64 ) void
  {
    self.indState.set( .COUNT, indT, @floatFromInt( value ));
  }
  pub inline fn addIndCount( self : *Economy, indT : IndType, value : u64 ) void
  {
    const current = self.getIndCount( indT );
    self.indState.set( .COUNT, indT, @floatFromInt( current + value ));
  }
  pub inline fn subIndCount( self : *Economy, indT : IndType, value : u64 ) void
  {
    const current = self.getIndCount( indT );
    const count   = @min( value, current );
    self.indState.set( .COUNT, indT, @floatFromInt( current - count ));

    if( value != count )
    {
      utl.log( .WARN, @src(), "@ Tried to remove {d} ind of type {s} from economy, but only had {d} left", .{ value, @tagName( indT ), count });
    }
  }


  // ================================ ENVIRONMENT ================================

  const SUN_GROUND_LOSS_FACTOR = 0.5;
  const SUN_MAX_ACCESS_FACTOR  = 2.0;
  const SUN_SHORTAGE_EXPONENT  = 2.0;

  pub inline fn updateSunshine( self : *Economy, sunshine : f64 ) void
  {
    self.sunshine = sunshine;

    var tmp : f64 = 0;

    switch( self.location )
    {
      .GROUND =>
      {
        const developedArea = self.areaData.get( .USED );
        const surfaceArea   = self.areaData.get( .BODY );

        const overgroundRatio = surfaceArea / developedArea;

        if( developedArea < surfaceArea )
        {
          tmp = SUN_GROUND_LOSS_FACTOR * sunshine;
        }
        else
        {
          const sunlessRatio = utl.pow( f64, 1.0 - overgroundRatio, SUN_SHORTAGE_EXPONENT );
          tmp = SUN_GROUND_LOSS_FACTOR * sunshine * ( 1.0 - sunlessRatio );
        }
      },

      .ORBIT => tmp = sunshine * 0.98,
      else   => tmp = sunshine,
    }

    self.sunAccess = @floatCast( utl.clmp( tmp, utl.EPS, SUN_MAX_ACCESS_FACTOR ));
  }

  pub inline fn hasEcology( self : *const Economy ) bool
  {
    return( self.location == .GROUND and self.hasAtmo );
  }

  pub inline fn getEcoFactor( self : *const Economy ) f64
  {
    if( !self.hasEcology() ){ return 0.0; }

    if( self.ecology != null )
    {
      return self.ecology.?.ecoFactor;
    }
    else
    {
      utl.qlog( .WARN, @src(), "Cannot get ecology factor : uninitialized" );
      return 0.0;
    }
  }


  // ================================ AREA ================================

  pub inline fn getHabitatArea( self : *const Economy ) f64
  {
    const habCount : f64 = @floatFromInt( self.getInfCount( .HABITAT ));

    return habCount * InfType.HABITAT.getMetric_f64( .CAPACITY );
  }

  pub fn updateAreas( self : *Economy ) void
  {
    const habitatArea = self.getHabitatArea();
    const bodyArea    = self.areaData.get( .BODY  );
    const inhabRatio  = self.areaData.get( .INHAB );

    // Compute LAND
    const landArea = bodyArea * inhabRatio;
    self.areaData.set( .LAND, landArea );

    // Compute CAP
    if( self.location == .GROUND and self.hasAtmo )
    {
      self.areaData.set( .CAP, habitatArea + landArea );
    }
    else
    {
      self.areaData.set( .CAP, habitatArea );
    }

    // Compute USED
    var areaUsed : f64 = 0.0;

    inline for( 0..infTypeC )| f |{ if( f != InfType.HABITAT.toIdx() )
    {
      const infT = InfType.fromIdx( f );
      const infC = self.infState.get( .COUNT, infT );

      areaUsed += infC * infT.getMetric_f64( .AREA_COST );
    }}
    inline for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );
      const indC = self.indState.get( .COUNT, indT );

      areaUsed += indC * indT.getMetric_f64( .AREA_COST );
    }

    self.areaData.set( .USED, areaUsed );

    // Compute AVAIL
    const areaCap = self.areaData.get( .CAP );

    if( areaCap > areaUsed )
    {
      self.areaData.set( .AVAIL, areaCap - areaUsed );
    }
    else
    {
      utl.log( .WARN, @src(), "Negative available area in location of type {s} : using {d:.2} / {d:.2}", .{ @tagName( self.location ), areaUsed, areaCap });
      self.areaData.zero( .AVAIL );
    }
  }


  // ================================ CONSTRUCTION ================================

  pub inline fn tryBuilding( self : *Economy, c : gdf.Construct, amount : f64 ) f64
  {
    if( utl.areContEqual( c, .{ .none = {} }))
    {
      utl.qlog( .WARN, @src(), "Trying to build .none construct : aborting" );
      return 0;
    }

    if( !c.canBeBuiltIn( self.location, self.hasAtmo ))
    {
      utl.qlog( .WARN, @src(), "Invalid location conditions : aborting" );
      return 0;
    }

    const areaCost   = c.getAreaCost();
    var  builtAmount = @floor( amount );


    // Habitats generate area instead of consuming it
    if( utl.areContEqual( c, .{ .infT = .HABITAT }))
    {
      // Update area metrics immediately to prevent undershoot on successive calls
      const newArea = builtAmount * InfType.HABITAT.getMetric_f64( .CAPACITY );

      self.areaData.add( .AVAIL, newArea );
      self.areaData.add( .CAP,   newArea );
    }
    else if( areaCost > utl.EPS ) // Excludes vessels
    {
      const areaAvail = self.areaData.get( .AVAIL );

      if( areaAvail < areaCost )
      {
      // utl.qlog( .WARN, @src(), "Not enough area for a single unit : aborting" );
        return 0;
      }
      if( areaAvail < builtAmount * areaCost )
      {
      //utl.qlog( .WARN, @src(), "Not enough area : adjusting amount" );
        builtAmount = @divFloor( areaAvail, areaCost );
      }


      // Update area metrics immediately to prevent overshoot on successive calls
      const usedArea = builtAmount * areaCost;

      self.areaData.add( .USED,  usedArea );
      self.areaData.sub( .AVAIL, usedArea );
    }


    // Updating the relevant counts
    switch( c )
    {
      .infT => | f |
      {
        self.infState.add( .COUNT, f, builtAmount );
        self.infState.add( .BUILT, f, builtAmount );
      },
      .indT => | d |
      {
        self.indState.add( .COUNT, d, builtAmount );
        self.indState.add( .BUILT, d, builtAmount );
      },
    //.vesT =>
    //{
    //  // TODO : build vessels
    //},
      .none => unreachable,
    }

    return builtAmount;
  }


  pub inline fn tryDestroying( self : *Economy, c : gdf.Construct, amount : f64 ) f64
  {
    if( utl.areContEqual( c, .{ .none = {} }))
    {
      utl.qlog( .WARN, @src(), "Trying to destruct .none construct : aborting" );
      return 0;
    }

    var destroyedAmount = @floor( amount );

    // Habitats generate area instead of consuming it
    if( utl.areContEqual( c, .{ .infT = .HABITAT }))
    {
      // TODO : prevent desroying habitats in use
    }


    // Updating the relevant counts
    switch( c )
    {
      .infT => | f |
      {
        destroyedAmount = @min( destroyedAmount, self.infState.get( .COUNT, f ));

        self.infState.sub( .COUNT, f, destroyedAmount );
        self.infState.add( .DESTR, f, destroyedAmount );
      },
      .indT => | d |
      {
        destroyedAmount = @min( destroyedAmount, self.indState.get( .COUNT, d ));

        self.indState.sub( .COUNT, d, destroyedAmount );
        self.indState.add( .DESTR, d, destroyedAmount );
      },
    //.vesT =>
    //{
    //  // TODO : build vessels
    //},
      .none => unreachable,
    }

    return destroyedAmount;
  }


  // ================================ UPDATING ================================

  inline fn updateEcology( self : *Economy ) void
  {
    if( !self.hasEcology() ){ return; }

    if( self.ecology != null )
    {
      self.ecology.?.update( self );
    }
    else
    {
      utl.qlog( .WARN, @src(), "Cannot tick ecology : uninitialized" );
    }
  }

  inline fn applyInflation( self : *Economy ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }

  inline fn tickBuildQueue( self : *Economy ) void
  {
    inline for( 0..infTypeC )| f |
    {
      const infT = InfType.fromIdx( f );

      self.infState.zero( .BUILT, infT );
      self.infState.zero( .DESTR, infT );
    }
    inline for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );

      self.indState.zero( .BUILT, indT );
      self.indState.zero( .DESTR, indT );
    }

    if( self.buildQueue != null )
    {
      self.buildQueue.?.tickQueue( self );
      self.buildQueue.?.debugLogBuildQueue();
    }
    else
    {
      utl.qlog( .WARN, @src(), "Cannot tick build queue : uninitialized" );
    }

  }

  inline fn updateInfUsage( self : *Economy ) void
  {
    // ASSEMBLY
    // NOTE : updated by econBuilder


    // HOUSING
    const popC : f64 = @floatFromInt( self.getTotalPopCount() );
    const popL : f64 = @floatFromInt( self.getTotalPopCap()   );

    self.infState.set( .USE_LVL, .HOUSING, popC / popL );


    // HABITAT
    const areaUsed : f64 = self.areaData.get( .USED );
    var   habitUse : f64 = 0.0;

    if( self.location != .GROUND or !self.hasAtmo )
    {
      // Non-ground or no-atmo : all area IS habitat area, use areaCap as fallback
      const areaCap : f64 = self.areaData.get( .CAP  );

      if( areaCap > utl.EPS )
      {
        habitUse = @min( 1.0, areaUsed / areaCap );
      }
    }
    else
    {
      // Ground with Atmo : account for non-habitat area
      const habitArea : f64 = self.getHabitatArea();

      if( habitArea > utl.EPS )
      {
        const landArea : f64 = self.areaData.get( .LAND );

        // How much of the used area exceeds what free land provides?
        const areaOnHabit = @max( 0.0, areaUsed - landArea );

        habitUse = areaOnHabit / habitArea;
      }
    }
    self.infState.set( .USE_LVL, .HABITAT, habitUse );


    // DEPOT
    const depotCap = self.getDepotStorageCapacity();
    const depotUse = self.getDepotStorageUse();

    self.infState.set( .USE_LVL, .DEPOT, depotUse / depotCap );


  // TODO : Activate once INF is added as a real agent
  //// AVERAGING USAGE RATES
  //var avgInfUse : f64 = 0.0;

  //inline for( 0..infTypeC )| f |
  //{
  //  const infT = InfType.fromIdx( f );
  //  avgInfUse += self.infState.get( .USE_LVL, infT );
  //}

  //avgInfUse /= @floatFromInt( infTypeC );

  //self.agtState.set( .INF, .AVG_ACT, avgInfUse );
  }


  pub fn tickLocalGov( self : *Economy ) void
  {
    _ = self; // TODO : IMPLEMENT ME
  }

  pub fn tryTick( self : *Economy, sunshine : f64 ) bool
  {
    if( !self.isValid ){  return false; }
    if( !self.isActive ){ return false; }

    self.stepCount += 1;

    self.updateSunshine( sunshine );
    self.tickEcon();

    return true;
  }

  inline fn preStepUpdates( self : *Economy ) void
  {
    // General Metrics
    self.updateResCaps();  // Depends on infCount
    self.updatePopCaps();  // Depends on infCount
    self.updateAreas();    // Depends on infCount
    self.updateInfUsage(); // Depends on Area, infCount, indCount
    self.updateEcology();  // Depends on infUsage, indActivity

    // Economic Metrics
    self.applyInflation();  // TODO : IMPLEMENT THIS
  }

  fn tickEcon( self : *Economy ) void
  {

    self.preStepUpdates();

    const solver = ecnSlvr.stepEcon( self );

    self.postStepUpdates();

    // Debug Actions
    dbgBld.debugAutoBuild( self );
    self.logSpecialMetrics();
    solver.logAllMetrics();
  }

  inline fn postStepUpdates( self : *Economy ) void
  {
    self.tickBuildQueue();
    self.tickLocalGov();   // TODO : IMPLEMENT THIS

  }
};


test "Economy constructors initialize required fields"
{
  const dead = Economy.newDeadEcon( .ORBIT );

  try std.testing.expect( dead.isValid );
  try std.testing.expect( !dead.isActive );
  try std.testing.expectEqual( EconLoc.ORBIT, dead.location );
  try std.testing.expectEqual( false, dead.hasAtmo );

  const live = Economy.newLiveEcon( .GROUND, 1000.0, 0.25, false );

  try std.testing.expect( live.isValid );
  try std.testing.expect( !live.isActive );
  try std.testing.expectEqual( EconLoc.GROUND, live.location );
  try std.testing.expectEqual( false, live.hasAtmo );
  try std.testing.expect( live.buildQueue != null );
}

test "Economy DEPOT usage sums ordinary resource storage"
{
  gdf.rsrc_d.loadResourceData();
  gdf.nfrs_d.loadInfrastructureData();

  var econ = Economy.newLiveEcon( .GROUND, 1000.0, 1.0, true );

  econ.infState.set( .COUNT, .HOUSING, 1.0 );
  econ.infState.set( .COUNT, .DEPOT,   1.0 );
  econ.updatePopCaps();
  econ.updateResCaps();

  const depotCap = econ.getDepotStorageCapacity();

  econ.resState.set( .COUNT, .LABOUR, depotCap );
  econ.resState.set( .COUNT, .FOOD,   depotCap * 0.25 );
  econ.resState.set( .COUNT, .ORE,    depotCap * 0.25 );

  econ.updateInfUsage();

  try std.testing.expectApproxEqAbs( @as( f64, 0.5 ), econ.infState.get( .USE_LVL, .DEPOT ), 0.0001 );
}
