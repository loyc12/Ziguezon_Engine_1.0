const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub const BodyView = eng.CompView( .{ eng.TransComp, eng.ShapeComp, eng.HitboxComp });

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
var mobileIds   : std.ArrayList( eng.EntityId ) = .empty;
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
  return true;
}

pub fn unregisterPingComps( ng : *eng.Engine ) void
{
  _ = ng.world.unregisterComp( eng.HitboxComp );
  _ = ng.world.unregisterComp( eng.ShapeComp  );
  _ = ng.world.unregisterComp( eng.TransComp  );
}

pub inline fn getBodyView( ng : *eng.Engine ) ?BodyView
{
  return ng.world.getCompView( .{ eng.TransComp, eng.ShapeComp, eng.HitboxComp });
}

pub fn syncHitbox( view : anytype, id : eng.EntityId ) void
{
  const trans  = view.get( eng.TransComp,  id ) orelse return;
  const shape  = view.get( eng.ShapeComp,  id ) orelse return;
  const hitbox = view.get( eng.HitboxComp, id ) orelse return;

  hitbox.hitbox = shape.getAABB( trans.pos );
}

pub fn syncAllHitboxes( view : anytype ) void
{
  var iter = view.iterator( eng.HitboxComp );
  while( iter.next() )| entry |
  {
    syncHitbox( view, entry.key_ptr.* );
  }
}

pub fn updateMobileEntities( view : *BodyView, sdt : f32 ) void
{
  for( mobileIds.items )| id |
  {
    const trans = view.get( eng.TransComp, id ) orelse continue;

    trans.updatePos( sdt );
    syncHitbox( view, id );
  }
}

pub fn createEntity( ng : *eng.Engine, view : anytype, params : EntityParams ) ?eng.EntityId
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
    removePingEntity( ng, id );
    return null;
  }

  if( !ng.world.addComp( eng.HitboxComp, id, .{} ))
  {
    removePingEntity( ng, id );
    return null;
  }
  syncHitbox( view, id );

  if( params.mobile )
  {
    mobileIds.append( utl.getDefaultAlloc(), id ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to register mobile Entity {d}: {}", .{ id, err });
      removePingEntity( ng, id );
      return null;
    };
  }

  entityIds.append( utl.getDefaultAlloc(), id ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to register Entity {d}: {}", .{ id, err });
    removePingEntity( ng, id );
    return null;
  };

  if( params.particle )
  {
    particleIds.append( utl.getDefaultAlloc(), id ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to register particle Entity {d}: {}", .{ id, err });
      removePingEntity( ng, id );
      return null;
    };
  }

  return id;
}

fn removeIdFromList( list : *std.ArrayList( eng.EntityId ), id : eng.EntityId ) void
{
  for( list.items, 0 .. )| entityId, index |
  {
    if( entityId == id )
    {
      _ = list.swapRemove( index );
      break;
    }
  }
}

pub fn removePingEntity( ng : *eng.Engine, id : eng.EntityId ) void
{
  removeIdFromList( &entityIds,   id );
  removeIdFromList( &mobileIds,   id );
  removeIdFromList( &particleIds, id );

  _ = ng.world.removeComp( eng.HitboxComp, id );
  _ = ng.world.removeComp( eng.ShapeComp,  id );
  _ = ng.world.removeComp( eng.TransComp,  id );
}

pub fn removeParticleAt( ng : *eng.Engine, index : usize ) void
{
  const id = particleIds.items[ index ];
  removePingEntity( ng, id );
}

pub inline fn getParticleCount() usize { return particleIds.items.len; }
pub inline fn getParticleId( index : usize ) eng.EntityId { return particleIds.items[ index ]; }

pub fn renderEntities( view : *BodyView ) void
{
  for( entityIds.items )| id |
  {
    const trans = view.get( eng.TransComp, id ) orelse continue;
    const shape = view.get( eng.ShapeComp, id ) orelse continue;
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
  mobileIds   = .empty;
  particleIds = .empty;

  var bodyView = getBodyView( ng ) orelse
  {
    unregisterPingComps( ng );
    return;
  };

  if( createEntity( ng, &bodyView, // player 1
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.blue,
    .pos    = .{ .x = -512, .y = 512 },
    .mobile = true,
  })
  )| p1 |{ P1_ID = p1; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 1 entity" ); }

  if( createEntity( ng, &bodyView, // player 2
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.red,
    .pos    = .{ .x = 512, .y = 512 },
    .mobile = true,
  })
  )| p2 |{ P2_ID = p2; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 2 entity" ); }

  _ = createEntity( ng, &bodyView, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.dGray,
    .pos    = .{ .x = 0, .y = 0 },
  });

  _ = createEntity( ng, &bodyView, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 1024, .y = 0 },
  });

  _ = createEntity( ng, &bodyView, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = -1024, .y = 0 },
  });

  _ = createEntity( ng, &bodyView, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 1024, .y = 8 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 0, .y = -512 },
  });

  if( createEntity( ng, &bodyView, // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 6, .y = 6 },
    .colour = utl.Colour.pMagenta,
    .pos    = .{},
  })
  )| shad1 |{ SHADOW_RANGE_START = shad1; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow 1 entity" ); }

  {
    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 8, .y = 8 },
      .colour = utl.Colour.red,
      .pos    = .{},
    });

    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 10, .y = 10 },
      .colour = utl.Colour.orange,
      .pos    = .{},
    });

    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 12, .y = 12 },
      .colour = utl.Colour.yellow,
      .pos    = .{},
    });

    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 14, .y = 14 },
      .colour = utl.Colour.green,
      .pos    = .{},
    });

    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 16, .y = 16 },
      .colour = utl.Colour.cyan,
      .pos    = .{},
    });

    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 18, .y = 18 },
      .colour = utl.Colour.blue,
      .pos    = .{},
    });

    _ = createEntity( ng, &bodyView, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 20, .y = 20 },
      .colour = utl.Colour.violet,
      .pos    = .{},
    });
  }

  if( createEntity( ng, &bodyView, // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = utl.Colour.magenta,
    .pos    = .{},
  })
  )| shad2 |{ SHADOW_RANGE_END = shad2; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow * entity" ); }

  if( createEntity( ng, &bodyView, // ball
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
  mobileIds.deinit(   utl.getDefaultAlloc() );
  particleIds.deinit( utl.getDefaultAlloc() );

  unregisterPingComps( ng );
}
