const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const TData = gdf.TravelData;

const BodyEconPair = gdf.BodyEconPair;
const EconLoc      = gdf.EconLoc;
const Angle        = def.Angle;
const EntityId     = def.EntityId;

const MAX_NESTING_DEPTH = 4; // Assumes depth will never exceede this


// ================================ CONFIGURATION ================================

const BODY_COUNT : usize = gdf.G_CONSTS.bodyCount;
const CACHE_LEN  : usize = BODY_COUNT + 1; // Entity id 0 is invalid, but kept as a sentinel slot.
const MAX_DEPTH  : usize = @min( CACHE_LEN, MAX_NESTING_DEPTH );

const LOW_ORBIT_RADIUS_FACTOR       : f64 = 1.10;
const ATMOSPHERIC_LAUNCH_DV_FACTOR  : f64 = 0.21;
const ATMOSPHERIC_LANDING_DV_FACTOR : f64 = 0.25;
const MIN_LANDING_DV_FACTOR         : f64 = 0.10;
const MIN_SURFACE_TRANSFER_DAYS     : f64 = 0.03;
const ATMOSPHERIC_LAUNCH_DAYS       : f64 = 0.10;
const ATMOSPHERIC_LANDING_DAYS      : f64 = 0.07;

const ECCENTRICITY_WEIGHT : f64 = 0.20;
const ORIENTATION_WEIGHT  : f64 = 0.10;
const PHASE_WEIGHT        : f64 = 0.15;
const RETROGRADE_WEIGHT   : f64 = 0.50;

const CO_ORBITAL_RADIUS_TOLERANCE : f64 = 0.01;
const CO_ORBITAL_PHASE_DV_FACTOR  : f64 = 0.05;
const CO_ORBITAL_DRIFT_RADIUS_OFFSET : f64 = 0.25;


// ================================ TRANSFER CACHE ================================

pub const TransferNode = struct
{
  parentId : EntityId = 0,

  mass   : f64 = 0.0,
  radius : f64 = 0.0,
  atmo   : f64 = 0.0,

  semiMajor    : f64 = 0.0,
  eccentricity : f64 = 0.0,

  orientation  : Angle = .{},
  angularPos   : Angle = .{},
  angularVel   : f64 = 0.0,

  gravParam      : f64 = 0.0,
  orbitalEnergy  : f64 = 0.0,
  boundaryRadius : f64 = 0.0,
  boundaryEnergy : f64 = 0.0,

  valid : bool = false,
};

const RepState = struct
{
  semiMajor    : f64 = 0.0,
  eccentricity : f64 = 0.0,

  orientation  : Angle = .{},
  angularPos   : Angle = .{},
  angularVel   : f64 = 0.0,

  radius : f64 = 0.0,
  energy : f64 = 0.0,
  valid  : bool = false,
};

const HohmannResult = struct
{
  travel : TData = .{},

  departDeltaV : f64 = 0.0,
  arriveDeltaV : f64 = 0.0,
};

var transferNodes : [ CACHE_LEN ]TransferNode = std.mem.zeroes([ CACHE_LEN ]TransferNode );


// ================================ UTILITY ================================

inline fn isValidBodyId( id : EntityId ) bool { return( id > 0 and id < CACHE_LEN ); }

fn doDirMatch( a : f64, b : f64 ) bool
{
  if( def.isFltZr( a ) or def.isFltZr( b )){ return true; }
  return( ( a < 0.0 ) == ( b < 0.0 ));
}

fn minutesToDays( minutes : f64 ) f64
{
  return minutes / ( 60.0 * 24.0 );
}

fn combineTravel( a : TData, b : TData ) TData
{
  return .{
    .deltaE = a.deltaE + b.deltaE,
    .deltaV = a.deltaV + b.deltaV,
    .deltaT = a.deltaT + b.deltaT,
  };
}

fn isCoOrbitalRadius( a : f64, b : f64 ) bool
{
  const mean = ( a + b ) * 0.5;
  if( mean < def.EPS ){ return false; }

  return( @abs( a - b ) / mean <= CO_ORBITAL_RADIUS_TOLERANCE );
}

fn coOrbitalDriftDurationDays( radius : f64, phase : f64, mu : f64 ) f64
{
  if( radius < def.EPS or phase < def.EPS or mu < def.EPS ){ return 0.0; }

  const baseAngularVel  = @sqrt( mu / ( radius * radius * radius ));
  const driftRadius     = radius * ( 1.0 + CO_ORBITAL_DRIFT_RADIUS_OFFSET );
  const driftAngularVel = @sqrt( mu / ( driftRadius * driftRadius * driftRadius ));
  const relAngularVel   = @abs( baseAngularVel - driftAngularVel );

  if( relAngularVel < def.EPS ){ return 0.0; }

  return minutesToDays( phase / relAngularVel );
}

fn locIsParentFrameCoOrbital( loc : EconLoc ) bool
{
  return switch( loc )
  {
    .L3, .L4, .L5 => true,
    else          => false,
  };
}

fn locAngularOffset( loc : EconLoc ) Angle
{
  return switch( loc )
  {
    .L3 => .newRad(  def.PI ),
    .L4 => .newRad(  def.PI / 3.0 ),
    .L5 => .newRad( -def.PI / 3.0 ),
    else => .{},
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
  return orbitalEnergyAtRadius( node.gravParam, radius );
}

fn orbitalEnergyAtRadius( gravParam : f64, radius : f64 ) f64
{
  if( gravParam < def.EPS or radius < def.EPS ){ return 0.0; }
  return -gravParam / ( 2.0 * radius );
}

fn bodyRestEnergyAtRadius( node : *const TransferNode, radius : f64 ) f64
{
  if( node.gravParam < def.EPS or radius < def.EPS ){ return 0.0; }
  return -node.gravParam / radius;
}

fn lowOrbitRadius( node : *const TransferNode ) f64
{
  return @max( node.radius * LOW_ORBIT_RADIUS_FACTOR, node.radius + 1.0 ); // At least 1 km above surface
}

fn localPlacementEnergy( node : *const TransferNode, loc : EconLoc ) f64
{
  return switch( loc )
  {
    .GROUND => bodyRestEnergyAtRadius( node, node.radius ),
    .ORBIT  => bodyEnergyAtRadius( node, lowOrbitRadius( node )),

    .L1, .L2      => node.boundaryEnergy,
    .L3, .L4, .L5 => node.orbitalEnergy,
  };
}

inline fn localPlacementEnergyDelta( node : *const TransferNode, fromLoc : EconLoc, toLoc : EconLoc ) f64
{
  return localPlacementEnergy( node, toLoc ) - localPlacementEnergy( node, fromLoc );
}

fn localPlacementRadius( node : *const TransferNode, loc : EconLoc ) f64
{
  return switch( loc )
  {
    .GROUND, .ORBIT => lowOrbitRadius( node ),
    .L1, .L2        => node.boundaryRadius,
    .L3, .L4, .L5   => node.semiMajor,
  };
}

fn circularDeltaVKmS( node : *const TransferNode, radius : f64 ) f64
{
  if( node.gravParam < def.EPS or radius < def.EPS ){ return 0.0; }
  return @sqrt( node.gravParam / radius ) / 60.0;
}

fn escapeDeltaVKmS( node : *const TransferNode, radius : f64 ) f64
{
  if( node.gravParam < def.EPS or radius < def.EPS ){ return 0.0; }
  return @sqrt(( 2.0 * node.gravParam ) / radius ) / 60.0;
}

fn atmosphereAt( bodyId : EntityId, loc : EconLoc ) f64
{
  if( loc != .GROUND ){ return 0.0; }

  const node = getNode( bodyId ) orelse return 0.0;
  const atmo = @max( node.atmo, 0.0 );

  // Earth-normalized, saturating pressure response.
  return def.softCap( atmo ) * 2.0;
}

fn surfaceTransferDays( atmoEffect : f64, launching : bool ) f64
{
  const atmoDays = if( launching ) ATMOSPHERIC_LAUNCH_DAYS else ATMOSPHERIC_LANDING_DAYS;
  return MIN_SURFACE_TRANSFER_DAYS + ( atmoDays * atmoEffect );
}

fn hohmannTransfer( radiusA : f64, radiusB : f64, mu : f64 ) HohmannResult
{
  if( radiusA < def.EPS or radiusB < def.EPS or mu < def.EPS ){ return .{}; }

  const transferA = ( radiusA + radiusB ) * 0.5;

  const velA  = @sqrt( mu / radiusA );
  const velB  = @sqrt( mu / radiusB );
  const velT1 = @sqrt( mu * (( 2.0 / radiusA ) - ( 1.0 / transferA )));
  const velT2 = @sqrt( mu * (( 2.0 / radiusB ) - ( 1.0 / transferA )));

  const departDeltaV = @abs( velT1 - velA ) / 60.0;
  const arriveDeltaV = @abs( velB - velT2 ) / 60.0;
  const durationMin = def.PI * @sqrt(( transferA * transferA * transferA ) / mu );

  return .{
    .travel = .{
      .deltaE = @abs( orbitalEnergyAtRadius( mu, radiusB ) - orbitalEnergyAtRadius( mu, radiusA )),
      .deltaV = departDeltaV + arriveDeltaV,
      .deltaT = minutesToDays( durationMin ),
    },
    .departDeltaV = departDeltaV,
    .arriveDeltaV = arriveDeltaV,
  };
}

fn departureDeltaVFromParking( bodyId : EntityId, vInf : f64 ) f64
{
  const node = getNode( bodyId ) orelse return vInf;
  const radius = lowOrbitRadius( node );
  const escape = escapeDeltaVKmS( node, radius );
  const circular = circularDeltaVKmS( node, radius );

  return @max( @sqrt(( vInf * vInf ) + ( escape * escape )) - circular, 0.0 );
}

fn captureDeltaVToParking( bodyId : EntityId, vInf : f64 ) f64
{
  return departureDeltaVFromParking( bodyId, vInf );
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
    .atmo      = gbl.STLR_DATA.get( body.?.name, .ATMO ),
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

  node.boundaryRadius = orbit.?.getHillRadius();
  node.boundaryEnergy = bodyEnergyAtRadius( &node, node.boundaryRadius );

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

fn groundToOrbitTransfer( bodyId : EntityId, node : *const TransferNode ) TData
{
  const radius = lowOrbitRadius( node );
  const atmo = atmosphereAt( bodyId, .GROUND );

  const baseEnergy = @abs( localPlacementEnergyDelta( node, .GROUND, .ORBIT ));
  const deltaV = circularDeltaVKmS( node, radius ) * ( 1.0 + ( ATMOSPHERIC_LAUNCH_DV_FACTOR * atmo ));

  return .{
    .deltaE = baseEnergy,
    .deltaV = deltaV,
    .deltaT = surfaceTransferDays( atmo, true ),
  };
}

fn orbitToGroundTransfer( bodyId : EntityId, node : *const TransferNode ) TData
{
  const atmo = atmosphereAt( bodyId, .GROUND );
  const baseEnergy = @abs( localPlacementEnergyDelta( node, .ORBIT, .GROUND ));
  const landingFactor = @max( def.lerp( 1.0, ATMOSPHERIC_LANDING_DV_FACTOR, atmo ), MIN_LANDING_DV_FACTOR );
  const deltaV = circularDeltaVKmS( node, lowOrbitRadius( node )) * landingFactor;

  return .{
    .deltaE = baseEnergy,
    .deltaV = deltaV,
    .deltaT = surfaceTransferDays( atmo, false ),
  };
}

fn localTransferEstimate( bodyId : EntityId, fromLoc : EconLoc, toLoc : EconLoc ) TData
{
  const node = getNode( bodyId ) orelse return .{};

  if( fromLoc == toLoc ){ return .{}; }

  if( fromLoc == .GROUND and toLoc == .ORBIT ){ return groundToOrbitTransfer( bodyId, node ); }
  if( fromLoc == .ORBIT  and toLoc == .GROUND ){ return orbitToGroundTransfer( bodyId, node ); }

  if( fromLoc == .ORBIT and ( toLoc   == .L1 or toLoc   == .L2 )){ return orbitBoundaryEstimate( bodyId ); }
  if( toLoc   == .ORBIT and ( fromLoc == .L1 or fromLoc == .L2 )){ return orbitBoundaryEstimate( bodyId ); }

  if( fromLoc == .GROUND )
  {
    return combineTravel(
      groundToOrbitTransfer( bodyId, node ),
      localTransferEstimate( bodyId, .ORBIT, toLoc ),
    );
  }

  if( toLoc == .GROUND )
  {
    return combineTravel(
      localTransferEstimate( bodyId, fromLoc, .ORBIT ),
      orbitToGroundTransfer( bodyId, node ),
    );
  }

  return .{ .deltaE = @abs( localPlacementEnergyDelta( node, fromLoc, toLoc )) };
}

fn orbitBoundaryEstimate( bodyId : EntityId ) TData
{
  const node = getNode( bodyId ) orelse return .{};

  const startRadius = localPlacementRadius( node, .ORBIT );
  var boundary      = hohmannTransfer( startRadius, node.boundaryRadius, node.gravParam ).travel;
  boundary.deltaV   = departureDeltaVFromParking( bodyId, 0.0 );

  return boundary;
}

fn routeWellCostToLca( bodyId : EntityId, loc : EconLoc, lcaId : EntityId, descending : bool ) TData
{
  if( !isValidBodyId( lcaId )){ return .{}; }

  var total : TData = .{};
  var current = bodyId;

  if( locIsParentFrameCoOrbital( loc ))
  {
    current = routeStartBody( bodyId, loc );
  }
  else if( current == lcaId )
  {
    const node = getNode( bodyId ) orelse return .{};

    if( loc == .GROUND ){ return if( descending ) orbitToGroundTransfer( bodyId, node ) else groundToOrbitTransfer( bodyId, node ); }
    return .{};
  }
  else
  {
    if( loc == .GROUND )
    {
      const node = getNode( current ) orelse return .{};
      total = combineTravel( total, if( descending ) orbitToGroundTransfer( current, node ) else groundToOrbitTransfer( current, node ));
    }
  }

  while( isValidBodyId( current ) and current != lcaId )
  {
    const node = getNode( current ) orelse break;
    const parentId = node.parentId;

    if( parentId == 0 or parentId == lcaId ){ break; }

    _ = getNode( parentId ) orelse break;
    total.deltaE += @abs( node.orbitalEnergy - node.boundaryEnergy );

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
    .angularPos   = node.angularPos.add( locAngularOffset( loc )),
    .angularVel   = node.angularVel,
    .radius       = node.semiMajor,
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
    .radius       = node.semiMajor,
    .energy       = node.orbitalEnergy,
    .valid        = true,
  };
}

fn frameLocalRepState( bodyId : EntityId, loc : EconLoc ) RepState
{
  const node = getNode( bodyId ) orelse return .{};
  const frameLoc = if( loc == .GROUND ) .ORBIT else loc;

  return .{
    .semiMajor    = localPlacementRadius( node, frameLoc ),
    .eccentricity = 0.0,
    .orientation  = node.orientation,
    .angularPos   = node.angularPos,
    .angularVel   = node.angularVel,
    .radius       = localPlacementRadius( node, frameLoc ),
    .energy       = localPlacementEnergy( node, frameLoc ),
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

  if( bodyId == frameId ){ return frameLocalRepState( bodyId, loc ); }

  const node = getNode( bodyId ) orelse return .{};
  if( node.parentId == frameId ){ return nodeRepState( bodyId ); }

  const child = childUnderAncestor( bodyId, frameId );
  if( child != 0 ){ return nodeRepState( child ); }

  return .{};
}

fn commonFramePenalty( fromBodyId : EntityId, fromLoc : EconLoc, toBodyId : EntityId, toLoc : EconLoc, frameId : EntityId ) TData
{
  const a = representativeInFrame( fromBodyId, fromLoc, frameId );
  const b = representativeInFrame( toBodyId,   toLoc,   frameId );

  if( !a.valid or !b.valid ){ return .{}; }

  const scale = @max( @abs( a.energy ), @abs( b.energy ), 1.0 );

  const energyCost = @abs( a.energy - b.energy );
  const eccCost    = @abs( a.eccentricity - b.eccentricity ) * scale * ECCENTRICITY_WEIGHT;

  const orientCost = @abs( b.orientation.sub( a.orientation ).toRad() ) / def.PI * scale * ORIENTATION_WEIGHT;
  const phase      = @abs( b.angularPos.sub( a.angularPos ).toRad() );

  const retroCost  = if( doDirMatch( a.angularVel, b.angularVel )) 0.0 else scale * RETROGRADE_WEIGHT;

  const phaseCost     = phase / def.PI * scale * PHASE_WEIGHT;
  const penaltyEnergy = eccCost + orientCost + phaseCost + retroCost;

  const frame = getNode( frameId ) orelse return .{};
  if( isCoOrbitalRadius( a.radius, b.radius ))
  {
    const phaseFrac = phase / def.PI;
    const circular = @sqrt( frame.gravParam / @max( a.radius, def.EPS )) / 60.0;
    const coOrbitalDeltaV = circular * CO_ORBITAL_PHASE_DV_FACTOR * phaseFrac;

    var transfer : TData = .{
      .deltaE = energyCost + penaltyEnergy,
      .deltaV = coOrbitalDeltaV,
    };

    const relAngVel = @abs( b.angularVel - a.angularVel );
    transfer.deltaT = if( relAngVel > def.EPS )
      minutesToDays( phase / relAngVel )
    else
      coOrbitalDriftDurationDays( a.radius, phase, frame.gravParam );

    return transfer;
  }

  const h = hohmannTransfer( a.radius, b.radius, frame.gravParam );
  var transfer = h.travel;

  transfer.deltaE = energyCost + penaltyEnergy;
  transfer.deltaV = 0.0;

  if( fromBodyId != frameId and !locIsParentFrameCoOrbital( fromLoc ))
  {
    transfer.deltaV += departureDeltaVFromParking( fromBodyId, h.departDeltaV );
  }
  else
  {
    transfer.deltaV += h.departDeltaV;
  }

  if( toBodyId != frameId and !locIsParentFrameCoOrbital( toLoc ))
  {
    transfer.deltaV += captureDeltaVToParking( toBodyId, h.arriveDeltaV );
  }
  else
  {
    transfer.deltaV += h.arriveDeltaV;
  }

  if( transfer.deltaT <= def.EPS )
  {
    const relAngVel = @abs( b.angularVel - a.angularVel );
    const durationMin = if( relAngVel > def.EPS ) phase / relAngVel else 0.0;
    transfer.deltaT = minutesToDays( durationMin );
  }

  return transfer;
}


// ================================ PUBLIC API ================================

pub fn estimateTransfer( fromBodyId : EntityId, fromLoc : EconLoc, toBodyId : EntityId, toLoc : EconLoc ) TData
{
  if(( fromBodyId == gdf.G_CONSTS.starId and fromLoc == .GROUND ) or ( toBodyId == gdf.G_CONSTS.starId and toLoc == .GROUND ))
  {
    return .{};
  }

  if( fromBodyId == toBodyId and !locIsParentFrameCoOrbital( fromLoc ) and !locIsParentFrameCoOrbital( toLoc ))
  {
    return localTransferEstimate( fromBodyId, fromLoc, toLoc );
  }

  const lcaId = findLowestCommonOrbitalParent( fromBodyId, fromLoc, toBodyId, toLoc );
  if( lcaId == 0 ){ return .{}; }

  const ascent  = routeWellCostToLca( fromBodyId, fromLoc, lcaId, false );
  const descent = routeWellCostToLca( toBodyId,   toLoc,   lcaId, true  );
  const common  = commonFramePenalty( fromBodyId, fromLoc, toBodyId, toLoc, lcaId );

  return combineTravel( combineTravel( ascent, common ), descent );
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
