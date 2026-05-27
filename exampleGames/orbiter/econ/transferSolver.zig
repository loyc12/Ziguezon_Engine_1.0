const std = @import( "std" );
const def = @import( "defs" );

const PI  = def.PI;
const TAU = def.TAU;
const EPS = def.EPS;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const TData = gdf.TravelData;

const BodyEconPair = gdf.BodyEconPair;
const EconLoc      = gdf.EconLoc;
const EntityId     = def.EntityId;

const MAX_NESTING_DEPTH = 4; // Assumes depth will never exceede this


// ================================ CONFIGURATION ================================

const BODY_COUNT : usize = gdf.G_CONSTS.bodyCount;
const CACHE_LEN  : usize = BODY_COUNT + 1; // Entity id 0 is invalid, but kept as a sentinel slot.
const MAX_DEPTH  : usize = @min( CACHE_LEN, MAX_NESTING_DEPTH );

const LOW_ORBIT_RADIUS_FACTOR    : f64 = 1.10;
const ATMOSPHERIC_LANDING_FACTOR : f64 = 0.60; // How much of the landing cost is deducted in atmosphere
const ATMOSPHERIC_LAUNCH_FACTOR  : f64 = 1.00; // How much of the launching cost is surcharged in atmosphere

const ECCENTRICITY_WEIGHT : f64 = 0.20;
const ORIENTATION_WEIGHT  : f64 = 0.10;
const PHASE_WEIGHT        : f64 = 0.15;
const RETROGRADE_WEIGHT   : f64 = 0.50;


// ================================ TRANSFER CACHE ================================

pub const TransferNode = struct
{
  parentId : EntityId = 0,

  mass   : f64 = 0.0,
  radius : f64 = 0.0,

  semiMajor    : f64 = 0.0,
  eccentricity : f64 = 0.0,
  orientation  : f64 = 0.0,

  angularPos : f64 = 0.0,
  angularVel : f64 = 0.0,

  gravParam      : f64 = 0.0,
  orbitalEnergy  : f64 = 0.0,
  boundaryEnergy : f64 = 0.0,

  valid : bool = false,
};

const RepState = struct
{
  semiMajor    : f64 = 0.0,
  eccentricity : f64 = 0.0,
  orientation  : f64 = 0.0,
  angularPos   : f64 = 0.0,
  angularVel   : f64 = 0.0,

  energy : f64 = 0.0,
  valid  : bool = false,
};

const CostEstimate = struct
{
  energyCost  : f64 = 0.0, // Specific energy proxy, in km² / min².
  durationDay : f64 = 0.0,
};

var transferNodes : [ CACHE_LEN ]TransferNode = std.mem.zeroes([ CACHE_LEN ]TransferNode );


// ================================ UTILITY ================================

fn isValidBodyId( id : EntityId ) bool
{
  return( id > 0 and id < CACHE_LEN );
}

fn normalizeAngle( angle : f64 ) f64
{
  var a = @mod( angle + PI, TAU );
  if( a < 0.0 ){ a += TAU; }
  return a - PI;
}

fn sameAngularDir( a : f64, b : f64 ) bool
{
  if( @abs( a ) < EPS or @abs( b ) < EPS ){ return true; }
  return( ( a < 0.0 ) == ( b < 0.0 ));
}

fn energyCostToDeltaVKmS( energyCost : f64 ) f64
{
  if( energyCost <= EPS ){ return 0.0; }

  // Energy terms are based on μ / r using the engine's km and minute units.
  // sqrt( 2E ) gives km / min, then / 60 gives km / s.
  return @sqrt( 2.0 * energyCost ) / 60.0;
}

fn minutesToDays( minutes : f64 ) f64
{
  return minutes / ( 60.0 * 24.0 );
}

fn locIsParentFrameCoOrbital( loc : EconLoc ) bool
{
  return switch( loc )
  {
    .L3, .L4, .L5 => true,
    else          => false,
  };
}

fn locAngularOffset( loc : EconLoc ) f64
{
  return switch( loc )
  {
    .L3 => PI,
    .L4 => PI / 3.0,
    .L5 => -PI / 3.0,
    else => 0.0,
  };
}

fn getNode( id : EntityId ) ?*const TransferNode
{
  if( !isValidBodyId( id )){ return null; }

  const node = &transferNodes[ @intCast( id )];
  if( !node.valid ){ return null; }

  return node;
}

fn bodyEnergyAtRadius( node : *const TransferNode, radius : f64 ) f64
{
  if( node.gravParam < EPS or radius < EPS ){ return 0.0; }
  return -node.gravParam / ( 2.0 * radius );
}

fn lowOrbitRadius( node : *const TransferNode ) f64
{
  return @max( node.radius * LOW_ORBIT_RADIUS_FACTOR, node.radius + 1.0 ); // At least 1 km above surface
}

fn localPlacementEnergy( node : *const TransferNode, loc : EconLoc ) f64
{
  return switch( loc )
  {
    .GROUND => bodyEnergyAtRadius( node, node.radius ),
    .ORBIT  => bodyEnergyAtRadius( node, lowOrbitRadius( node )),

    .L1, .L2      => node.boundaryEnergy,
    .L3, .L4, .L5 => node.orbitalEnergy,
  };
}

inline fn localPlacementEnergyDelta( node : *const TransferNode, fromLoc : EconLoc, toLoc : EconLoc ) f64
{
  return localPlacementEnergy( node, toLoc ) - localPlacementEnergy( node, fromLoc );
}

inline fn isTerraGround( bodyId : EntityId, loc : EconLoc ) bool
{
  return( loc == .GROUND and bodyId == gdf.idFromName( .TERRA )); // TODO : generalise to hasAtmo instead
}


// ================================ CACHE REFRESH ================================

fn refreshTransferNode( bodyId : EntityId ) void
{
  if( !isValidBodyId( bodyId )){ return; }

  const body = gbl.G_DATA.stores.body.get( bodyId );
  if( body == null )
  {
    transferNodes[ @intCast( bodyId )] = .{};
    return;
  }

  var node : TransferNode = .{
    .mass      = body.?.mass,
    .radius    = body.?.radius,
    .gravParam = gdf.G_CONSTS.gravFactor * body.?.mass,
    .valid     = true,
  };

  if( bodyId == gdf.G_CONSTS.starId )
  {
    transferNodes[ @intCast( bodyId )] = node;
    return;
  }

  const orbit = gbl.G_DATA.stores.orbit.get( bodyId );
  if( orbit == null )
  {
    node.valid = false;
    transferNodes[ @intCast( bodyId )] = node;
    return;
  }

  node.parentId = gbl.ORBITANCE.getOrbitedId( bodyId );

  node.semiMajor      = orbit.?.getSemiMajor();
  node.eccentricity   = orbit.?.getEccentricity();
  node.orientation    = orbit.?.orientation;
  node.angularPos     = orbit.?.angularPos;
  node.angularVel     = orbit.?.angularVel;
  node.orbitalEnergy  = orbit.?.getOrbitalEnergy();

  node.boundaryEnergy = bodyEnergyAtRadius( &node, orbit.?.getHillRadius() );

  transferNodes[ @intCast( bodyId )] = node;
}

pub fn refreshAllTransferNodes() void
{
  for( 1..CACHE_LEN )| idx |
  {
    refreshTransferNode( @intCast( idx ));
  }
}

pub fn refreshDynamicTransferNodes() void
{
  for( 1..CACHE_LEN )| idx |
  {
    const bodyId : EntityId = @intCast( idx );
    const node = &transferNodes[ idx ];

    if( !node.valid or bodyId == gdf.G_CONSTS.starId ){ continue; }

    if( gbl.G_DATA.stores.orbit.get( bodyId ))| orbit |
    {
      node.angularPos = orbit.angularPos;
      node.angularVel = orbit.angularVel;
    }
  }
}


// ================================ ANCESTOR CHAINS ================================

const AncestorChain = struct
{
  ids : [ MAX_DEPTH ]EntityId = std.mem.zeroes([ MAX_DEPTH ]EntityId ),
  len : usize = 0,

  pub fn add( self : *AncestorChain, id : EntityId ) void
  {
    if( self.len >= MAX_DEPTH ){ return; }

    self.ids[ self.len ] = id;
    self.len += 1;
  }

  pub fn contains( self : *const AncestorChain, id : EntityId ) bool
  {
    for( 0..self.len )| idx |
    {
      if( self.ids[ idx ] == id ){ return true; }
    }

    return false;
  }
};

fn routeStartBody( bodyId : EntityId, loc : EconLoc ) EntityId
{
  if( locIsParentFrameCoOrbital( loc ))
  {
    if( getNode( bodyId ))| node |{ return node.parentId; }
  }

  return bodyId;
}

pub fn buildAncestorChain( bodyId : EntityId ) AncestorChain
{
  var chain : AncestorChain = .{};
  var id = bodyId;

  while( isValidBodyId( id ))
  {
    chain.add( id );

    const node = getNode( id ) orelse break;
    if( node.parentId == 0 ){ break; }

    id = node.parentId;
  }

  return chain;
}

pub fn findLowestCommonOrbitalParent( fromBodyId : EntityId, fromLoc : EconLoc, toBodyId : EntityId, toLoc : EconLoc ) EntityId
{
  const aStart = routeStartBody( fromBodyId, fromLoc );
  const bStart = routeStartBody( toBodyId,   toLoc   );

  const aChain = buildAncestorChain( aStart );
  const bChain = buildAncestorChain( bStart );

  for( 0..aChain.len )| idx |
  {
    const id = aChain.ids[ idx ];
    if( bChain.contains( id )){ return id; }
  }

  return 0;
}

fn childUnderAncestor( bodyId : EntityId, ancestorId : EntityId ) EntityId
{
  var current = bodyId;
  var prev : EntityId = 0;

  while( isValidBodyId( current ))
  {
    if( current == ancestorId ){ return prev; }

    prev = current;

    const node = getNode( current ) orelse return 0;
    current = node.parentId;
  }

  return 0;
}


// ================================ WELL COSTS ================================

fn localTransferCost( bodyId : EntityId, fromLoc : EconLoc, toLoc : EconLoc ) f64
{
  const node = getNode( bodyId ) orelse return 0.0;

  var cost = @abs( localPlacementEnergyDelta( node, fromLoc, toLoc ));

  if( bodyId == gdf.idFromName( .TERRA ) and ( fromLoc == .GROUND or toLoc == .GROUND ))
  {
  //const atmoCost = @abs( localPlacementEnergyDelta( node, .GROUND, .ORBIT ));

    if( toLoc == .GROUND )
    {
      cost -= 0.0; //atmoCost * ATMOSPHERIC_LANDING_FACTOR;
    }
    else
    {
      cost += 0.0; //atmoCost * ATMOSPHERIC_LAUNCH_FACTOR;
    }
  }

  return cost;
}

fn localBoundaryCost( bodyId : EntityId, loc : EconLoc, descending : bool ) f64
{
  const node = getNode( bodyId ) orelse return 0.0;

  var cost = @abs( localPlacementEnergy( node, loc ) - node.boundaryEnergy );

  if( bodyId == gdf.idFromName( .TERRA ) and ( loc == .GROUND ))
  {
  //const atmoCost = @abs( localPlacementEnergyDelta( node, .GROUND, .ORBIT ));

    if( descending )
    {
      cost -= 0.0; // atmoCost * ATMOSPHERIC_LANDING_FACTOR;
    }
    else
    {
      cost += 0.0; //atmoCost * ATMOSPHERIC_LAUNCH_FACTOR;
    }
  }

  return cost;
}

fn routeWellCostToLca( bodyId : EntityId, loc : EconLoc, lcaId : EntityId, descending : bool ) f64
{
  if( !isValidBodyId( lcaId )){ return 0.0; }

  var total : f64 = 0.0;
  var current = bodyId;

  if( locIsParentFrameCoOrbital( loc ))
  {
    current = routeStartBody( bodyId, loc );
  }
  else if( current == lcaId )
  {
    return 0.0;
  }
  else
  {
    total += localBoundaryCost( current, loc, descending );
  }

  while( isValidBodyId( current ) and current != lcaId )
  {
    const node = getNode( current ) orelse break;
    const parentId = node.parentId;

    if( parentId == 0 or parentId == lcaId ){ break; }

    const parent = getNode( parentId ) orelse break;
    total += @abs( node.orbitalEnergy - parent.boundaryEnergy );

    current = parentId;
  }

  return total;
}


// ================================ FRAME PENALTIES ================================

fn coOrbitalRepState( bodyId : EntityId, loc : EconLoc ) RepState
{
  const node = getNode( bodyId ) orelse return .{};

  return .{
    .semiMajor    = node.semiMajor,
    .eccentricity = node.eccentricity,
    .orientation  = node.orientation,
    .angularPos   = normalizeAngle( node.angularPos + locAngularOffset( loc )),
    .angularVel   = node.angularVel,
    .energy       = node.orbitalEnergy,
    .valid        = true,
  };
}

fn nodeRepState( bodyId : EntityId ) RepState
{
  const node = getNode( bodyId ) orelse return .{};

  return .{
    .semiMajor    = node.semiMajor,
    .eccentricity = node.eccentricity,
    .orientation  = node.orientation,
    .angularPos   = node.angularPos,
    .angularVel   = node.angularVel,
    .energy       = node.orbitalEnergy,
    .valid        = true,
  };
}

fn representativeInFrame( bodyId : EntityId, loc : EconLoc, frameId : EntityId ) RepState
{
  if( !isValidBodyId( bodyId ) or !isValidBodyId( frameId )){ return .{}; }

  if( locIsParentFrameCoOrbital( loc ))
  {
    const node = getNode( bodyId ) orelse return .{};
    if( node.parentId == frameId ){ return coOrbitalRepState( bodyId, loc ); }

    const start = routeStartBody( bodyId, loc );
    if( start == frameId ){ return .{ .valid = true }; }

    const child = childUnderAncestor( start, frameId );
    if( child != 0 ){ return nodeRepState( child ); }

    return .{};
  }

  if( bodyId == frameId ){ return .{ .valid = true }; }

  const node = getNode( bodyId ) orelse return .{};
  if( node.parentId == frameId ){ return nodeRepState( bodyId ); }

  const child = childUnderAncestor( bodyId, frameId );
  if( child != 0 ){ return nodeRepState( child ); }

  return .{};
}

fn commonFramePenalty( fromBodyId : EntityId, fromLoc : EconLoc, toBodyId : EntityId, toLoc : EconLoc, frameId : EntityId ) CostEstimate
{
  const a = representativeInFrame( fromBodyId, fromLoc, frameId );
  const b = representativeInFrame( toBodyId,   toLoc,   frameId );

  if( !a.valid or !b.valid ){ return .{}; }

  const scale = @max( @abs( a.energy ), @abs( b.energy ), 1.0 );

  const energyCost = @abs( a.energy - b.energy );
  const eccCost    = @abs( a.eccentricity - b.eccentricity ) * scale * ECCENTRICITY_WEIGHT;
  const orientCost = @abs( normalizeAngle( b.orientation - a.orientation )) / PI * scale * ORIENTATION_WEIGHT;
  const phase      = @abs( normalizeAngle( b.angularPos - a.angularPos ));
  const phaseCost  = phase / PI * scale * PHASE_WEIGHT;
  const retroCost  = if( sameAngularDir( a.angularVel, b.angularVel )) 0.0 else scale * RETROGRADE_WEIGHT;

  const relAngVel = @abs( b.angularVel - a.angularVel );
  const durationMin = if( relAngVel > EPS ) phase / relAngVel else 0.0;

  return .{
    .energyCost  = energyCost + eccCost + orientCost + phaseCost + retroCost,
    .durationDay = minutesToDays( durationMin ),
  };
}


// ================================ PUBLIC API ================================

pub fn estimateTransfer( fromBodyId : EntityId, fromLoc : EconLoc, toBodyId : EntityId, toLoc : EconLoc ) TData
{
  if( fromBodyId == toBodyId and !locIsParentFrameCoOrbital( fromLoc ) and !locIsParentFrameCoOrbital( toLoc ))
  {
    const energyCost = localTransferCost( fromBodyId, fromLoc, toLoc );

    return .{
      .deltaV   = energyCostToDeltaVKmS( energyCost ),
      .duration = 0.0,
    };
  }

  const lcaId = findLowestCommonOrbitalParent( fromBodyId, fromLoc, toBodyId, toLoc );
  if( lcaId == 0 ){ return .{}; }

  const ascent  = routeWellCostToLca( fromBodyId, fromLoc, lcaId, false );
  const descent = routeWellCostToLca( toBodyId,   toLoc,   lcaId, true  );
  const common  = commonFramePenalty( fromBodyId, fromLoc, toBodyId, toLoc, lcaId );
  const energyCost = ascent + descent + common.energyCost;

  return .{
    .deltaV   = energyCostToDeltaVKmS( energyCost ),
    .duration = common.durationDay,
  };
}

pub fn estimateTransferPair( from : BodyEconPair, to : BodyEconPair ) TData
{
  const fromSplit = gdf.fromBodyEconPair( from );
  const toSplit   = gdf.fromBodyEconPair( to   );

  return estimateTransfer(
    gdf.idFromName( fromSplit.a ), fromSplit.b,
    gdf.idFromName( toSplit.a   ), toSplit.b,
  );
}

pub fn isTransferNodeValid( bodyId : EntityId ) bool
{
  return getNode( bodyId ) != null;
}
