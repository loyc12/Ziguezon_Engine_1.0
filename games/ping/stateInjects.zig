const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub const TransStore    = eng.TransComp.StoreType();
pub const ShapeStore    = eng.ShapeComp.StoreType();
pub const HitboxStore   = eng.HitboxComp.StoreType();
pub const MobileStore   = eng.ComponentStoreFactory( MobileComp );
pub const ParticleStore = eng.ComponentStoreFactory( ParticleComp );

var transStore    : TransStore    = .{};
var shapeStore    : ShapeStore    = .{};
var hitboxStore   : HitboxStore   = .{};
var mobileStore   : MobileStore   = .{};
var particleStore : ParticleStore = .{};

pub const MobileComp   = struct{};
pub const ParticleComp = struct{};

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

var entityIds     : std.ArrayList( eng.EntityId ) = .empty;
var particleIds   : std.ArrayList( eng.EntityId ) = .empty;

pub var P1_ID              : eng.EntityId = 0;
pub var P2_ID              : eng.EntityId = 0;
pub var SHADOW_RANGE_START : eng.EntityId = 0;
pub var SHADOW_RANGE_END   : eng.EntityId = 0;
pub var BALL_ID            : eng.EntityId = 0;

pub inline fn getTransStore()    *TransStore    { return &transStore;    }
pub inline fn getShapeStore()    *ShapeStore    { return &shapeStore;    }
pub inline fn getHitboxStore()   *HitboxStore   { return &hitboxStore;   }
pub inline fn getMobileStore()   *MobileStore   { return &mobileStore;   }
pub inline fn getParticleStore() *ParticleStore { return &particleStore; }

fn registerStore( ng : *eng.Engine, name : []const u8, storePtr : *anyopaque ) void
{
  if( !ng.componentRegistry.register( name, storePtr ))
  {
    utl.log( .ERROR, 0, @src(), "Failed to register {s}", .{ name });
  }
}

pub fn syncHitbox( id : eng.EntityId ) void
{
  const trans = transStore.get( id ) orelse return;
  const shape = shapeStore.get( id ) orelse return;
  const hitbox = hitboxStore.get( id ) orelse return;

  hitbox.hitbox = shape.getAABB( trans.pos );
}

pub fn syncAllHitboxes() void
{
  var iter = hitboxStore.iterator();
  while( iter.next() )| entry |
  {
    syncHitbox( entry.key_ptr.* );
  }
}

pub fn updateMobileEntities( sdt : f32 ) void
{
  var iter = mobileStore.iterator();
  while( iter.next() )| entry |
  {
    const id = entry.key_ptr.*;
    const trans = transStore.get( id ) orelse continue;

    trans.updatePos( sdt );
    syncHitbox( id );
  }
}

pub fn createEntity( ng : *eng.Engine, params : EntityParams ) ?eng.EntityId
{
  const id = ng.entityIdRegistry.getNewEntity().id;

  if( !transStore.add( id, .{
    .pos = params.pos,
    .vel = params.vel,
    .acc = params.acc,
  })){ return null; }

  if( !shapeStore.add( id, .{
    .scale  = params.scale,
    .shape  = params.shape,
    .colour = params.colour,
  }))
  {
    destroyEntity( id );
    return null;
  }

  if( !hitboxStore.add( id, .{} ))
  {
    destroyEntity( id );
    return null;
  }
  syncHitbox( id );

  if( params.mobile and !mobileStore.add( id, .{} ))
  {
    destroyEntity( id );
    return null;
  }

  entityIds.append( utl.getDefaultAlloc(), id ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to register Entity {d}: {}", .{ id, err });
    destroyEntity( id );
    return null;
  };

  if( params.particle )
  {
    if( !particleStore.add( id, .{} ))
    {
      destroyEntity( id );
      return null;
    }
    particleIds.append( utl.getDefaultAlloc(), id ) catch | err |
    {
      utl.log( .ERROR, 0, @src(), "Failed to register particle Entity {d}: {}", .{ id, err });
      _ = particleStore.remove( id );
      return null;
    };
  }

  return id;
}

pub fn destroyEntity( id : eng.EntityId ) void
{
  for( entityIds.items, 0 .. )| entityId, index |
  {
    if( entityId == id )
    {
      _ = entityIds.swapRemove( index );
      break;
    }
  }

  _ = particleStore.remove( id );
  _ = mobileStore.remove( id );
  _ = hitboxStore.remove( id );
  _ = shapeStore.remove( id );
  _ = transStore.remove( id );
}

pub fn removeParticleAt( index : usize ) void
{
  const id = particleIds.items[ index ];
  destroyEntity( id );
  _ = particleIds.swapRemove( index );
}

pub inline fn getParticleCount() usize { return particleIds.items.len; }
pub inline fn getParticleId( index : usize ) eng.EntityId { return particleIds.items[ index ]; }

pub fn renderEntities() void
{
  for( entityIds.items )| id |
  {
    const trans = transStore.get( id ) orelse continue;
    const shape = shapeStore.get( id ) orelse continue;
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
  const alloc = utl.getDefaultAlloc();

  transStore.init(    alloc );
  shapeStore.init(    alloc );
  hitboxStore.init(   alloc );
  mobileStore.init(   alloc );
  particleStore.init( alloc );

  entityIds   = .empty;
  particleIds = .empty;

  registerStore( ng, "pingTransStore",    &transStore    );
  registerStore( ng, "pingShapeStore",    &shapeStore    );
  registerStore( ng, "pingHitboxStore",   &hitboxStore   );
  registerStore( ng, "pingMobileStore",   &mobileStore   );
  registerStore( ng, "pingParticleStore", &particleStore );

  if( createEntity( ng, // player 1
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.blue,
    .pos    = .{ .x = -512, .y = 512 },
    .mobile = true,
  })
  )| p1 |{ P1_ID = p1; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 1 entity" ); }

  if( createEntity( ng, // player 2
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.red,
    .pos    = .{ .x = 512, .y = 512 },
    .mobile = true,
  })
  )| p2 |{ P2_ID = p2; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 2 entity" ); }

  _ = createEntity( ng, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.dGray,
    .pos    = .{ .x = 0, .y = 0 },
  });

  _ = createEntity( ng, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 1024, .y = 0 },
  });

  _ = createEntity( ng, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = -1024, .y = 0 },
  });

  _ = createEntity( ng, // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 1024, .y = 8 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 0, .y = -512 },
  });

  if( createEntity( ng, // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 6, .y = 6 },
    .colour = utl.Colour.pMagenta,
    .pos    = .{},
  })
  )| shad1 |{ SHADOW_RANGE_START = shad1; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow 1 entity" ); }

  {
    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 8, .y = 8 },
      .colour = utl.Colour.red,
      .pos    = .{},
    });

    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 10, .y = 10 },
      .colour = utl.Colour.orange,
      .pos    = .{},
    });

    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 12, .y = 12 },
      .colour = utl.Colour.yellow,
      .pos    = .{},
    });

    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 14, .y = 14 },
      .colour = utl.Colour.green,
      .pos    = .{},
    });

    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 16, .y = 16 },
      .colour = utl.Colour.cyan,
      .pos    = .{},
    });

    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 18, .y = 18 },
      .colour = utl.Colour.blue,
      .pos    = .{},
    });

    _ = createEntity( ng, // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 20, .y = 20 },
      .colour = utl.Colour.violet,
      .pos    = .{},
    });
  }

  if( createEntity( ng, // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = utl.Colour.magenta,
    .pos    = .{},
  })
  )| shad2 |{ SHADOW_RANGE_END = shad2; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow * entity" ); }

  if( createEntity( ng, // ball
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
  _ = ng;

  entityIds.deinit( utl.getDefaultAlloc() );
  particleIds.deinit( utl.getDefaultAlloc() );
  particleStore.deinit();
  mobileStore.deinit();
  hitboxStore.deinit();
  shapeStore.deinit();
  transStore.deinit();
}
