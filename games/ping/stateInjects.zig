const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub const MobileComp = struct
{
  pub const storeType : eng.CompStorePolicy = .SPARSE;
};

pub const ParticleComp = struct
{
  pub const storeType : eng.CompStorePolicy = .SPARSE;
};

pub const TransStore    = eng.CompStoreFactory( eng.TransComp  );
pub const ShapeStore    = eng.CompStoreFactory( eng.ShapeComp  );
pub const HitboxStore   = eng.CompStoreFactory( eng.HitboxComp );
pub const MobileStore   = eng.CompStoreFactory( MobileComp     );
pub const ParticleStore = eng.CompStoreFactory( ParticleComp   );

pub const PingStores = struct
{
  trans    : *TransStore,
  shape    : *ShapeStore,
  hitbox   : *HitboxStore,
  mobile   : *MobileStore,
  particle : *ParticleStore,
};

pub const EntityParams = struct
{
  pos    : utl.VecA    = .{},
  vel    : utl.VecA    = .{},
  acc    : utl.VecA    = .{},
  scale  : utl.Vec2    = .{ .x = 1, .y = 1 },
  shape  : utl.Shape2D = .RECT,
  colour : utl.Colour  = .white,

  mobile   : bool = false,
  particle : bool = false,
};

var entityIds   : std.ArrayList( eng.EntityId ) = .empty;
var particleIds : std.ArrayList( eng.EntityId ) = .empty;

pub var P1_ID              : eng.EntityId = 0;
pub var P2_ID              : eng.EntityId = 0;
pub var SHADOW_RANGE_START : eng.EntityId = 0;
pub var SHADOW_RANGE_END   : eng.EntityId = 0;
pub var BALL_ID            : eng.EntityId = 0;

pub fn registerPingComps( ng : *eng.Engine ) bool
{
  if( !ng.world.registerComp( eng.TransComp ))
  {
    utl.qlog( .ERROR, 0, @src(), "Failed to register TransComp" );
    return false;
  }
  if( !ng.world.registerComp( eng.ShapeComp ))
  {
    _ = ng.world.unregisterComp( eng.TransComp );
    utl.qlog( .ERROR, 0, @src(), "Failed to register ShapeComp" );
    return false;
  }
  if( !ng.world.registerComp( eng.HitboxComp ))
  {
    _ = ng.world.unregisterComp( eng.ShapeComp );
    _ = ng.world.unregisterComp( eng.TransComp );
    utl.qlog( .ERROR, 0, @src(), "Failed to register HitboxComp" );
    return false;
  }
  if( !ng.world.registerComp( MobileComp ))
  {
    _ = ng.world.unregisterComp( eng.HitboxComp );
    _ = ng.world.unregisterComp( eng.ShapeComp  );
    _ = ng.world.unregisterComp( eng.TransComp  );
    utl.qlog( .ERROR, 0, @src(), "Failed to register MobileComp" );
    return false;
  }
  if( !ng.world.registerComp( ParticleComp ))
  {
    _ = ng.world.unregisterComp( MobileComp     );
    _ = ng.world.unregisterComp( eng.HitboxComp );
    _ = ng.world.unregisterComp( eng.ShapeComp  );
    _ = ng.world.unregisterComp( eng.TransComp  );
    utl.qlog( .ERROR, 0, @src(), "Failed to register ParticleComp" );
    return false;
  }

  return true;
}

pub fn unregisterPingComps( ng : *eng.Engine ) void
{
  _ = ng.world.unregisterComp( ParticleComp   );
  _ = ng.world.unregisterComp( MobileComp     );
  _ = ng.world.unregisterComp( eng.HitboxComp );
  _ = ng.world.unregisterComp( eng.ShapeComp  );
  _ = ng.world.unregisterComp( eng.TransComp  );
}

pub fn getStores( ng : *eng.Engine ) ?PingStores
{
  const trans = ng.world.getCompStore( eng.TransComp ) orelse
  {
    utl.qlog( .WARN, 0, @src(), "Ping TransComp store is not registered" );
    return null;
  };
  const shape = ng.world.getCompStore( eng.ShapeComp ) orelse
  {
    utl.qlog( .WARN, 0, @src(), "Ping ShapeComp store is not registered" );
    return null;
  };
  const hitbox = ng.world.getCompStore( eng.HitboxComp ) orelse
  {
    utl.qlog( .WARN, 0, @src(), "Ping HitboxComp store is not registered" );
    return null;
  };
  const mobile = ng.world.getCompStore( MobileComp ) orelse
  {
    utl.qlog( .WARN, 0, @src(), "Ping MobileComp store is not registered" );
    return null;
  };
  const particle = ng.world.getCompStore( ParticleComp ) orelse
  {
    utl.qlog( .WARN, 0, @src(), "Ping ParticleComp store is not registered" );
    return null;
  };

  return .{
    .trans    = trans,
    .shape    = shape,
    .hitbox   = hitbox,
    .mobile   = mobile,
    .particle = particle,
  };
}

pub fn syncHitbox( stores : PingStores, id : eng.EntityId ) void
{
  const trans  = stores.trans.get( id ) orelse return;
  const shape  = stores.shape.get( id ) orelse return;
  const hitbox = stores.hitbox.get( id ) orelse return;

  hitbox.hitbox = shape.getAABB( trans.pos );
}

pub fn syncAllHitboxes( stores : PingStores ) void
{
  var iter = stores.hitbox.iterator();
  while( iter.next() )| entry |
  {
    syncHitbox( stores, entry.key_ptr.* );
  }
}

pub fn updateMobileEntities( stores : PingStores, sdt : f32 ) void
{
  var iter = stores.mobile.iterator();
  while( iter.next() )| entry |
  {
    const id = entry.key_ptr.*;
    const trans = stores.trans.get( id ) orelse continue;

    trans.updatePos( sdt );
    syncHitbox( stores, id );
  }
}

pub fn createEntity( ng : *eng.Engine, stores : PingStores, params : EntityParams ) ?eng.EntityId
{
  const id = ng.world.createEntity().id;

  if( !ng.world.addComp( eng.TransComp, id,
  .{
    .pos = params.pos,
    .vel = params.vel,
    .acc = params.acc,
  })){ return null; }

  if( !ng.world.addComp( eng.ShapeComp, id,
  .{
    .scale  = params.scale,
    .shape  = params.shape,
    .colour = params.colour,
  }))
  {
    removePingEntity( stores, id );
    return null;
  }

  if( !ng.world.addComp( eng.HitboxComp, id, .{} ))
  {
    removePingEntity( stores, id );
    return null;
  }
  syncHitbox( stores, id );

  if( params.mobile and !ng.world.addComp( MobileComp, id, .{} ))
  {
    removePingEntity( stores, id );
    return null;
  }

  entityIds.append( utl.getDefaultAlloc(), id ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to register Entity {d}: {}", .{ id, err });
    removePingEntity( stores, id );
    return null;
  };

  if( params.particle )
  {
    if( !ng.world.addComp( ParticleComp, id, .{} ))
    {
      removePingEntity( stores, id );
      return null;
    }
    particleIds.append( utl.getDefaultAlloc(), id ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to register particle Entity {d}: {}", .{ id, err });
      removePingEntity( stores, id );
      return null;
    };
  }

  return id;
}

pub fn removePingEntity( stores : PingStores, id : eng.EntityId ) void
{
  for( entityIds.items, 0 .. )| entityId, index |
  {
    if( entityId == id )
    {
      _ = entityIds.swapRemove( index );
      break;
    }
  }

  _ = stores.particle.remove( id );
  _ = stores.mobile.remove(   id );
  _ = stores.hitbox.remove(   id );
  _ = stores.shape.remove(    id );
  _ = stores.trans.remove(    id );
}

pub fn removeParticleAt( stores : PingStores, index : usize ) void
{
  const id = particleIds.items[ index ];
  removePingEntity( stores, id );
  _ = particleIds.swapRemove( index );
}

pub inline fn getParticleCount() usize { return particleIds.items.len; }
pub inline fn getParticleId( index : usize ) eng.EntityId { return particleIds.items[ index ]; }

pub fn renderEntities( stores : PingStores ) void
{
  for( entityIds.items )| id |
  {
    const trans = stores.trans.get( id ) orelse continue;
    const shape = stores.shape.get( id ) orelse continue;
    shape.render( trans.pos );
  }
}

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameStart( ng : *eng.Engine ) void
{
  ng.resourceManager.addAudioFromFile( "hit_1", "assets/sounds/Boop_1.wav" ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to load audio 'hit_1': {}\n", .{ err } );
  };
  ng.resourceManager.addAudioFromFile( "hit_2", "assets/sounds/Boop_2.wav" ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to load audio 'hit_2': {}\n", .{ err } );
  };
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  if( !registerPingComps( ng )){ return; }

  entityIds   = .empty;
  particleIds = .empty;

  const stores = getStores( ng ) orelse
  {
    unregisterPingComps( ng );
    return;
  };

  if( createEntity( ng, stores, // player 1
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.blue,
    .pos    = .{ .x = -512, .y = 512 },
    .mobile = true,
  })
  )| p1 |{ P1_ID = p1; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 1 entity" ); }

  if( createEntity( ng, stores, // player 2
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.red,
    .pos    = .{ .x = 512, .y = 512 },
    .mobile = true,
  })
  )| p2 |{ P2_ID = p2; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 2 entity" ); }

  _ = createEntity( ng, stores, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.dGray,
    .pos    = .{ .x = 0, .y = 0 },
  });

  _ = createEntity( ng, stores, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 1024, .y = 0 },
  });

  _ = createEntity( ng, stores, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = -1024, .y = 0 },
  });

  _ = createEntity( ng, stores, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 1024, .y = 8 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 0, .y = -512 },
  });

  if( createEntity( ng, stores, // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 6, .y = 6 },
    .colour = utl.Colour.pMagenta,
    .pos    = .{},
  })
  )| shad1 |{ SHADOW_RANGE_START = shad1; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow 1 entity" ); }

  {
    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 8, .y = 8 },
      .colour = utl.Colour.red,
      .pos    = .{},
    });

    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 10, .y = 10 },
      .colour = utl.Colour.orange,
      .pos    = .{},
    });

    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 12, .y = 12 },
      .colour = utl.Colour.yellow,
      .pos    = .{},
    });

    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 14, .y = 14 },
      .colour = utl.Colour.green,
      .pos    = .{},
    });

    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 16, .y = 16 },
      .colour = utl.Colour.cyan,
      .pos    = .{},
    });

    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 18, .y = 18 },
      .colour = utl.Colour.blue,
      .pos    = .{},
    });

    _ = createEntity( ng, stores, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 20, .y = 20 },
      .colour = utl.Colour.violet,
      .pos    = .{},
    });
  }

  if( createEntity( ng, stores, // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = utl.Colour.magenta,
    .pos    = .{},
  })
  )| shad2 |{ SHADOW_RANGE_END = shad2; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow * entity" ); }

  if( createEntity( ng, stores, // ball
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 24, .y = 24 },
    .colour = utl.Colour.white,
    .pos    = .{},
    .mobile = true,
  })
  )| ball |{ BALL_ID = ball; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball entity" ); }
}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  entityIds.deinit(   utl.getDefaultAlloc() );
  particleIds.deinit( utl.getDefaultAlloc() );

  unregisterPingComps( ng );
}
