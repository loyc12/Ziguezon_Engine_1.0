const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub const gdf = @import( "gameDef.zig" );

const bodyCount = gdf.G_CONSTS.bodyCount;
const initialEconomyCapacity = 16;
const economyAllocChunkSize  = 16;


// ================ GAMEDATA STRUCTS ================

pub var G_DATA : GameData = .{};

pub const GameData = struct
{
  times  : GameTimes    = .{},
  target : TargetInfo   = .{},
  views  : OrbiterViews = .{},

  bodyRegistry   : BodyRegistry = .{},
  orbitParentIds : [ bodyCount ]eng.EntityId = std.mem.zeroes([ bodyCount ]eng.EntityId ),

  economies : EconomyStore = .{},
};


/// Game-owned economy storage for the Phase 1 ownership migration.
/// Keeps the global state object small while expanding live storage in chunks.
pub const EconomyStore = struct
{
  alloc  : std.mem.Allocator = undefined,
  list   : std.ArrayList( gdf.ecn.Economy ) = .empty,

  isInit : bool = false,


  pub fn init( self : *EconomyStore, alloc : std.mem.Allocator ) bool
  {
    if( self.isInit ){ return true; }

    self.alloc  = alloc;
    self.list   = .empty;
    self.isInit = true;

    if( !self.ensureCapacity( initialEconomyCapacity ))
    {
      self.deinit();
      return false;
    }

    return true;
  }

  pub fn deinit( self : *EconomyStore ) void
  {
    if( !self.isInit ){ return; }

    self.list.deinit( self.alloc );
    self.* = .{};
  }


  pub inline fn clear( self : *EconomyStore ) void
  {
    if( !self.isInit ){ return; }

    self.list.clearRetainingCapacity();
  }

  pub inline fn getCount( self : *const EconomyStore ) usize
  {
    return self.list.items.len;
  }

  /// Returns the highest live economy index, or null when storage is empty.
  pub inline fn getMaxEconIdx( self : *const EconomyStore ) ?usize
  {
    const count = self.getCount();
    if( count == 0 ){ return null; }

    return count - 1;
  }

  fn ensureCapacity( self : *EconomyStore, neededCapacity : usize ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .ERROR, @src(), "Cannot grow EconomyStore : uninitialized" );
      return false;
    }
    if( self.list.capacity >= neededCapacity ){ return true; }

    var newCapacity = self.list.capacity;
    if( newCapacity == 0 ){ newCapacity = initialEconomyCapacity; }

    while( newCapacity < neededCapacity )
    {
      newCapacity += economyAllocChunkSize;
    }

    self.list.ensureTotalCapacityPrecise( self.alloc, newCapacity ) catch
    {
      utl.log( .ERROR, @src(), "Failed to grow EconomyStore to {d} entries", .{ newCapacity });
      return false;
    };

    return true;
  }

  pub fn create( self : *EconomyStore, loc : gdf.EconLoc ) ?gdf.EconomyId
  {
    if( !self.isInit )
    {
      utl.log( .ERROR, @src(), "Cannot create economy at {s} : EconomyStore is uninitialized", .{ @tagName( loc )});
      return null;
    }

    const nextIdx = self.getCount();
    if( !self.ensureCapacity( nextIdx + 1 ))
    {
      utl.log( .ERROR, @src(), "Cannot create economy at {s} : failed to expand storage", .{ @tagName( loc )});
      return null;
    }

    const id = gdf.EconomyId.fromIdx( nextIdx );

    self.list.appendAssumeCapacity( .{} );
    self.list.items[ id.toIdx() ].softInit( loc );

    return id;
  }

  pub inline fn get( self : *EconomyStore, id : gdf.EconomyId ) ?*gdf.ecn.Economy
  {
    if( !id.isValid() ){ return null; }
    if( id.toIdx() >= self.getCount() ){ return null; }

    return &self.list.items[ id.toIdx() ];
  }

  pub inline fn getConst( self : *const EconomyStore, id : gdf.EconomyId ) ?*const gdf.ecn.Economy
  {
    if( !id.isValid() ){ return null; }
    if( id.toIdx() >= self.getCount() ){ return null; }

    return &self.list.items[ id.toIdx() ];
  }

  /// Ticks live economies by storage order instead of walking body components.
  pub fn tickAll( self : *EconomyStore ) u32
  {
    var econCount : u32 = 0;

    for( self.list.items )| *econ |
    {
      if( econ.tryTick( econ.sunshine ))
      {
        econCount += 1;
      }
    }

    return econCount;
  }
};


pub const BodyRegistry = struct
{
  ids : [ bodyCount ]eng.EntityId = std.mem.zeroes([ bodyCount ]eng.EntityId ),


  pub inline fn clear( self : *BodyRegistry ) void
  {
    self.ids = std.mem.zeroes([ bodyCount ]eng.EntityId );
  }

  pub inline fn idOf( self : *const BodyRegistry, bodyName : gdf.BodyName ) eng.EntityId
  {
    return self.ids[ bodyName.toIdx() ];
  }

  pub inline fn setId( self : *BodyRegistry, bodyName : gdf.BodyName, id : eng.EntityId ) void
  {
    self.ids[ bodyName.toIdx() ] = id;
  }

  pub inline fn clearId( self : *BodyRegistry, bodyName : gdf.BodyName ) void
  {
    self.ids[ bodyName.toIdx() ] = 0;
  }

  pub fn nameOf( self : *const BodyRegistry, id : eng.EntityId ) ?gdf.BodyName
  {
    if( id == 0 ){ return null; }

    for( gdf.bodyOrder )| bodyName |
    {
      if( self.idOf( bodyName ) == id ){ return bodyName; }
    }

    return null;
  }

  pub inline fn containsId( self : *const BodyRegistry, id : eng.EntityId ) bool
  {
    return self.nameOf( id ) != null;
  }
};


pub const OrbiterViews = struct
{
  bodyTrans   : ?gdf.BodyTransView   = null,
  orbitTick   : ?gdf.OrbitTickView   = null,
  orbitRender : ?gdf.OrbitRenderView = null,


  pub inline fn clear( self : *OrbiterViews ) void
  {
    self.bodyTrans   = null;
    self.orbitTick   = null;
    self.orbitRender = null;
  }

  pub fn getBodyTrans( self : *OrbiterViews, ng : *eng.Engine ) ?*gdf.BodyTransView
  {
    return getCachedView( gdf.BodyTransView, .{ eng.TransComp, gdf.bdy.BodyComp }, &self.bodyTrans, ng );
  }

  pub fn getOrbitTick( self : *OrbiterViews, ng : *eng.Engine ) ?*gdf.OrbitTickView
  {
    return getCachedView( gdf.OrbitTickView, .{ eng.TransComp, gdf.orb.OrbitComp, gdf.bdy.BodyComp }, &self.orbitTick, ng );
  }

  pub fn getOrbitRender( self : *OrbiterViews, ng : *eng.Engine ) ?*gdf.OrbitRenderView
  {
    return getCachedView( gdf.OrbitRenderView, .{ eng.TransComp, eng.ShapeComp, gdf.orb.OrbitComp, gdf.bdy.BodyComp }, &self.orbitRender, ng );
  }

  fn getCachedView( comptime ViewType : type, comptime CompTypes : anytype, viewSlot : *?ViewType, ng : *eng.Engine ) ?*ViewType
  {
    if( viewSlot.* )|* view |
    {
      if( view.isStillValid( &ng.world )){ return view; }
    }

    viewSlot.* = ng.world.getCompView( CompTypes ) orelse return null;
    if( viewSlot.* )|* view |{ return view; }

    return null;
  }
};


pub const GameTimes = struct
{
  speedSetting : SpeedFactor = .DAY,
  secsPerStep  : i128 = SpeedFactor.DAY.getStepLen(),

  bodyStepOffset : i128 = 0,
  econStepOffset : i128 = 0,


  pub inline fn changeSpeed( self : *GameTimes, delta : i8 )void
  {
    self.speedSetting = self.speedSetting.change( delta );
    self.secsPerStep  = self.speedSetting.getStepLen();
  }
  pub inline fn stepTime( self : *GameTimes ) void // Run every tick
  {
    if( eng.G_ENG.isPaused() ){ return; }

    const tickPerSec : i128 = @intCast( eng.G_CNFGS.Startup_Target_TickRate );

    self.bodyStepOffset += @divFloor( self.secsPerStep, tickPerSec );
    self.econStepOffset += @divFloor( self.secsPerStep, tickPerSec );
  }

  pub inline fn shouldBodyTick( self : *GameTimes ) bool
  {
    if( eng.G_ENG.isPaused() ){ return false; }

    return( self.bodyStepOffset >= gdf.G_CONSTS.bodyStepLen );
  }
  pub inline fn consumeBodyTick( self : *GameTimes ) void
  {
    self.bodyStepOffset -= gdf.G_CONSTS.bodyStepLen;
  }

  pub inline fn shouldEconTick( self : *GameTimes ) bool
  {
    if( eng.G_ENG.isPaused() ){ return false; }

    return( self.econStepOffset >= gdf.G_CONSTS.econStepLen );
  }
  pub inline fn consumeEconTick( self : *GameTimes ) void
  {
    self.econStepOffset -= gdf.G_CONSTS.econStepLen;
  }
};


// ================================ RELATION CACHE FUNCTIONS ================================

pub inline fn clearOrbitParentCache() void
{
  G_DATA.orbitParentIds = std.mem.zeroes([ bodyCount ]eng.EntityId );
}

pub fn refreshOrbitParentCacheEntry( ng : *eng.Engine, bodyName : gdf.BodyName ) bool
{
  const bodyId = G_DATA.bodyRegistry.idOf( bodyName );
  if( bodyId == 0 )
  {
    utl.log( .ERROR, @src(), "Cannot refresh orbit-parent cache for {s} : body has no live entity", .{ @tagName( bodyName )});
    return false;
  }

  const store = ng.world.getRelationStore( gdf.Orbits ) orelse
  {
    utl.qlog( .ERROR, @src(), "Cannot refresh orbit-parent cache : Orbits relation is not registered" );
    return false;
  };

  var iter = store.sourceIterator( bodyId );
  const first = iter.next();

  if( bodyName == gdf.G_CONSTS.starBody )
  {
    if( first != null )
    {
      utl.qlog( .ERROR, @src(), "Star body unexpectedly has an Orbits relation" );
      return false;
    }

    G_DATA.orbitParentIds[ bodyName.toIdx() ] = 0;
    return true;
  }

  if( first == null )
  {
    utl.log( .ERROR, @src(), "Cannot refresh orbit-parent cache for {s} : missing Orbits relation", .{ @tagName( bodyName )});
    return false;
  }
  if( iter.next() != null )
  {
    utl.log( .ERROR, @src(), "Cannot refresh orbit-parent cache for {s} : multiple Orbits relation targets", .{ @tagName( bodyName )});
    return false;
  }

  const parentId = first.?.key.targetId;
  if( !ng.world.isEntityAlive( parentId ))
  {
    utl.log( .ERROR, @src(), "Cannot refresh orbit-parent cache for {s} : parent Entity {d} is not alive", .{ @tagName( bodyName ), parentId });
    return false;
  }
  if( G_DATA.bodyRegistry.nameOf( parentId ) == null )
  {
    utl.log( .ERROR, @src(), "Cannot refresh orbit-parent cache for {s} : parent Entity {d} is not a registered body", .{ @tagName( bodyName ), parentId });
    return false;
  }

  G_DATA.orbitParentIds[ bodyName.toIdx() ] = parentId;
  return true;
}

pub fn rebuildOrbitParentCache( ng : *eng.Engine ) bool
{
  clearOrbitParentCache();

  var success = true;
  for( gdf.bodyOrder )| bodyName |
  {
    if( !refreshOrbitParentCacheEntry( ng, bodyName )){ success = false; }
  }

  return success;
}

pub inline fn getOrbitedIdCached( bodyName : gdf.BodyName ) eng.EntityId
{
  return G_DATA.orbitParentIds[ bodyName.toIdx() ];
}

// ================================ WORLD STORE FUNCTIONS ================================

pub fn registerOrbiterStores( ng : *eng.Engine ) bool
{
  G_DATA.views.clear();
  G_DATA.bodyRegistry.clear();
  clearOrbitParentCache();

  if( !ng.world.registerComp( eng.TransComp ))
  {
    utl.qlog( .ERROR, @src(), "Failed to register TransComp" );
    return false;
  }
  if( !ng.world.registerComp( eng.ShapeComp ))
  {
    _ = ng.world.unregisterComp( eng.TransComp );

    utl.qlog( .ERROR, @src(), "Failed to register ShapeComp" );
    return false;
  }
  if( !ng.world.registerComp( eng.SpriteComp ))
  {
    _ = ng.world.unregisterComp( eng.ShapeComp );
    _ = ng.world.unregisterComp( eng.TransComp );

    utl.qlog( .ERROR, @src(), "Failed to register SpriteComp" );
    return false;
  }
  if( !ng.world.registerComp( gdf.orb.OrbitComp ))
  {
    _ = ng.world.unregisterComp( eng.SpriteComp );
    _ = ng.world.unregisterComp( eng.ShapeComp  );
    _ = ng.world.unregisterComp( eng.TransComp  );

    utl.qlog( .ERROR, @src(), "Failed to register OrbitComp" );
    return false;
  }
  if( !ng.world.registerComp( gdf.bdy.BodyComp ))
  {
    _ = ng.world.unregisterComp( gdf.orb.OrbitComp );
    _ = ng.world.unregisterComp( eng.SpriteComp    );
    _ = ng.world.unregisterComp( eng.ShapeComp     );
    _ = ng.world.unregisterComp( eng.TransComp     );

    utl.qlog( .ERROR, @src(), "Failed to register BodyComp" );
    return false;
  }
  if( !ng.world.registerRelation( gdf.Orbits ))
  {
    _ = ng.world.unregisterComp( gdf.bdy.BodyComp  );
    _ = ng.world.unregisterComp( gdf.orb.OrbitComp );
    _ = ng.world.unregisterComp( eng.SpriteComp    );
    _ = ng.world.unregisterComp( eng.ShapeComp     );
    _ = ng.world.unregisterComp( eng.TransComp     );

    utl.qlog( .ERROR, @src(), "Failed to register Orbits relation" );
    return false;
  }

  if( !G_DATA.economies.init( utl.getDefaultAlloc() ))
  {
    _ = ng.world.unregisterRelation( gdf.Orbits    );
    _ = ng.world.unregisterComp( gdf.bdy.BodyComp  );
    _ = ng.world.unregisterComp( gdf.orb.OrbitComp );
    _ = ng.world.unregisterComp( eng.SpriteComp    );
    _ = ng.world.unregisterComp( eng.ShapeComp     );
    _ = ng.world.unregisterComp( eng.TransComp     );

    utl.qlog( .ERROR, @src(), "Failed to initialize EconomyStore" );
    return false;
  }
  G_DATA.economies.clear();

  return true;
}

pub fn unregisterOrbiterStores( ng : *eng.Engine ) void
{
  G_DATA.views.clear();

  for( gdf.bodyOrder )| bodyName |
  {
    const id = G_DATA.bodyRegistry.idOf( bodyName );

    if( ng.world.isEntityAlive( id ))
    {
      _ = ng.world.destroyEntity( id );
    }

    G_DATA.bodyRegistry.clearId( bodyName );
  }

  _ = ng.world.unregisterRelation( gdf.Orbits    );
  _ = ng.world.unregisterComp( gdf.bdy.BodyComp  );
  _ = ng.world.unregisterComp( gdf.orb.OrbitComp );
  _ = ng.world.unregisterComp( eng.SpriteComp    );
  _ = ng.world.unregisterComp( eng.ShapeComp     );
  _ = ng.world.unregisterComp( eng.TransComp     );

  clearOrbitParentCache();
  G_DATA.economies.deinit();
}


pub const TargetInfo = struct
{
  camFollow : bool = false,
  hasMoved  : bool = false,

  targetId   : eng.EntityId = 0,
  targetBody : ?gdf.BodyName = null,


  pub fn changeTargetToBody( self : *TargetInfo, bodyName : gdf.BodyName ) void
  {
    const targetId = G_DATA.bodyRegistry.idOf( bodyName );
    if( targetId == 0 )
    {
      utl.log( .WARN, @src(), "Target body {s} has no live entity : clearing target", .{ @tagName( bodyName )});
      self.targetId   = 0;
      self.targetBody = null;
      self.hasMoved   = true;
      return;
    }

    self.targetId   = targetId;
    self.targetBody = bodyName;
    self.hasMoved   = true;
  }

  pub fn changeTargetTo( self : *TargetInfo, targetId : eng.EntityId ) void
  {
    if( targetId == 0 )
    {
      self.targetId   = 0;
      self.targetBody = null;
      self.hasMoved   = true;
      return;
    }

    const bodyName = G_DATA.bodyRegistry.nameOf( targetId ) orelse
    {
      utl.qlog( .WARN, @src(), "Target does not exist : defaulting to Id 0 ( none )" );
      self.targetId   = 0;
      self.targetBody = null;
      self.hasMoved   = true;
      return;
    };

    self.targetId   = targetId;
    self.targetBody = bodyName;
    self.hasMoved   = true;
  }

  pub fn changeTargetBy( self : *TargetInfo, delta : i64 ) void
  {
    const current : i64 = if( self.targetBody )| bodyName |
      @intCast( gdf.getBodyOrderIdx( bodyName ) orelse 0 )
    else
      -1;

    var next = current + delta;

    if( next < 0 ){ next = 0; }
    const maxIdx : i64 = @intCast( gdf.bodyOrder.len - 1 );
    if( next > maxIdx ){ next = maxIdx; }

    self.changeTargetToBody( gdf.bodyOrder[ @intCast( next )] );
  }

  pub fn moveCamOver( self : *TargetInfo, view : anytype ) void
  {
    if( self.targetId == 0 )
    {
      utl.qlog( .TRACE, @src(), "targetId is 0 : returning" );
      return;
    }

    // Centers the camera on current valid target
    if( self.camFollow and self.hasMoved )
    {
      self.hasMoved = false;

      const targetTrans = view.get( eng.TransComp, self.targetId );

      if( targetTrans )| trans |
      {
        eng.G_ENG.camera.cam.pos = trans.pos;
        utl.qlog( .TRACE, @src(), "View centered on target" );
      }
      else
      {
        utl.qlog( .WARN, @src(), "Target does not exist : cannot center view" );
        self.camFollow = false;
      }
    }
  }
};


// ================ GAMEDATA SUB-STRUCTS ================

pub const SpeedFactor = enum( i8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  PAUSED = 0,
  SECOND,
  MINUTE,
  HOUR,
  DAY,
  WEEK,
  MONTH,
  YEAR,


  pub inline fn getStepLen( self : SpeedFactor ) i128
  {
    return switch( self )
    {
      .PAUSED => 0,
      .SECOND => 1,
      .MINUTE => utl.Duration.secPerMin(),
      .HOUR   => utl.Duration.secPerHour(),
      .DAY    => utl.Duration.secPerDay() * 1,
      .WEEK   => utl.Duration.secPerDay() * 7,
      .MONTH  => utl.Duration.secPerDay() * 30,
      .YEAR   => utl.Duration.secPerDay() * 365,
    };
  }

  pub inline fn change( self : SpeedFactor, delta : i8 ) SpeedFactor
  {
    const current : i8 = @intFromEnum( self );
    var   next    : i8 = current + delta;

    if( next < 0      ){ next = 0;         }
    if( next >= count ){ next = count - 1; }

    return @enumFromInt( next );
  }
};


// ================ GAMEDATA MATRICES ================

    const stlr_d = @import( "data/stellarData.zig" );
    const trde_d = @import( "data/travelData.zig"   );
    const ecnm_d = @import( "data/economyData.zig" );

pub const STLR_DATA         = &stlr_d.stellarData;
pub const ECON_ORBIT_DATA   = &trde_d.econOrbitalData;


    const powr_d = @import( "data/powerData.zig"          );
    const vesl_d = @import( "data/vesselData.zig"         );
    const rsrc_d = @import( "data/resourceData.zig"       );
    const popl_d = @import( "data/populationData.zig"     );
    const nfrs_d = @import( "data/infrastructureData.zig" );
    const ndst_d = @import( "data/industryData.zig"       );

pub const POWR_DATA = &powr_d.powerData;
pub const VESL_DATA = &vesl_d.vesselData;
pub const RSRC_DATA = &rsrc_d.resourceData;
pub const POPL_DATA = &popl_d.populationData;
pub const NFRS_DATA = &nfrs_d.infrastructureData;
pub const NDST_DATA = &ndst_d.industryData;


    const sshn_d = @import( "data/sunshineData.zig" );

pub const SUNSHINE = &sshn_d.solShine;


pub fn loadStaticDataMatrices() void
{
  stlr_d.loadStellarData();

  powr_d.loadPowerSrcData();
  vesl_d.loadVesselData();
  rsrc_d.loadResourceData();
  popl_d.loadPopulationData();
  nfrs_d.loadInfrastructureData();
  ndst_d.loadIndustryData();

  if( !debugCheckDataInit() )
  {
    utl.qlog( .ERROR, @src(), "One or more dataMatrices were left uninitialized" );
  }

  _ = SUNSHINE.initFromData();
}


pub fn debugCheckDataInit() bool
{
  if( !stlr_d.stellarData.isInit ){ return false; }

  if( !powr_d.powerMetricData.isInit ){ return false; }
  if( !vesl_d.vesMetricData.isInit   ){ return false; }

  if( !rsrc_d.resMetricData.isInit     ){ return false; }
  if( !popl_d.popResMetricTable.isInit ){ return false; }
  if( !nfrs_d.infResMetricTable.isInit ){ return false; }
  if( !ndst_d.indResMetricTable.isInit ){ return false; }

  if( !popl_d.popMetricData.isInit ){ return false; }
  if( !nfrs_d.infMetricData.isInit ){ return false; }
  if( !ndst_d.indMetricData.isInit ){ return false; }

  return true;
}
