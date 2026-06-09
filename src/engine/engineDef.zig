const std = @import( "std" );
const utl = @import( "utils" );

// ================================ GAME INTERFACES ================================

// ================ ENGINE SETTINGS ================

const  cnfg_i = @import( "interface/configs.zig" );
pub var G_CNFGS : cnfg_i.EngineConfigs = .{};

pub inline fn loadConfigs( module : anytype ) void { G_CNFGS.loadConfigs( module ); }


// ================ GAME HOOKS ================

const  hook_i = @import( "interface/hooks.zig" );
pub var G_HOOKS : hook_i.GameHooks = .{};

pub const HookCntx = hook_i.HookCntx;
pub const HookFunc = hook_i.HookFunc;

pub inline fn loadHooks( module : anytype ) void                       { G_HOOKS.loadHooks( module  ); }
pub inline fn tryHook( tag : hook_i.HookTag, cntx : HookCntx ) void    { G_HOOKS.tryHook( tag, cntx ); }



// ================================ ENGINE SYSTEMS ================================

pub const engineCore = @import( "core/engine.zig" );
pub const Engine     = engineCore.Engine;

pub var G_ENG : Engine = .{};

// ================ MANAGERS ================

pub const resMgr     = @import( "resources/resourceManager.zig" );
pub const tilemapMgr = @import( "world/tilemap/tilemapManager.zig" );
pub const worldMgr   = @import( "world/worldManager.zig" );

pub const World       = worldMgr.World;
pub const TickInfo    = worldMgr.TickInfo;


// ================ RENDER ================

pub const wCam    = @import( "render/worldCamera.zig" );
pub const wDraw   = @import( "render/drawerWorld.zig" );
pub const wSprite = @import( "render/spriteWorld.zig" );

pub const WorldCam = wCam.WorldCam;


// ================ TILEMAP ================

pub const tilemap = @import( "world/tilemap/tilemap.zig" );

pub const Tile      = tilemap.Tile;
pub const TileType  = tilemap.TileType;
pub const TileFlags = tilemap.TileFlags;

pub const Tilemap      = tilemap.Tilemap;
pub const TilemapShape = tilemap.TilemapShape;
pub const TilemapFlags = tilemap.TilemapFlags;
pub const FloodRule    = tilemap.FloodRule;


// ================ ECS ================

const entity = @import( "world/entity.zig" );

pub const Entity   = entity.Entity;
pub const EntityId = entity.EntityId;


const comp = @import( "world/components/component.zig" );

pub const CompStoreFactory = comp.CompStoreFactory;
pub const CompStorePolicy  = comp.CompStorePolicy;


const view = @import( "world/views/view.zig" );

pub const CompView         = view.CompView;
pub const ComponentView    = view.CompView;


const rel  = @import( "world/relations/relation.zig" );

pub const RelationStoreFactory = rel.RelationStoreFactory;
pub const RelationKey          = rel.RelationKey;
pub const RelationLimitPolicy  = rel.RelationLimitPolicy;
pub const LinkedTo             = rel.LinkedTo;

const evt  = @import( "world/events/event.zig" );
const eque = @import( "world/events/eventQueue.zig" );
const emgr = @import( "world/events/eventManager.zig" );
const elog = @import( "world/events/eventLog.zig" );

pub const EventMeta         = evt.EventMeta;
pub const EventRecord       = evt.EventRecord;
pub const EventQueueFactory = eque.EventQueueFactory;
pub const EventLogFactory   = elog.EventLogFactory;
pub const EventManager      = emgr.EventManager;

pub const EntityCreated    = evt.EntityCreated;
pub const EntityDestroyed  = evt.EntityDestroyed;
pub const ComponentAdded   = evt.ComponentAdded;
pub const ComponentRemoved = evt.ComponentRemoved;
pub const RelationAdded    = evt.RelationAdded;
pub const RelationRemoved  = evt.RelationRemoved;


pub const baseComp = @import( "world/components/baseComps.zig" );

pub const TransComp  = baseComp.TransComp;
pub const ShapeComp  = baseComp.ShapeComp;
pub const HitboxComp = baseComp.HitboxComp;
pub const SpriteComp = baseComp.SpriteComp;

test "engine world declarations"
{
  utl.G_EPOCH = utl.getNow();

  std.testing.refAllDecls( worldMgr );
  std.testing.refAllDecls( evt );
  std.testing.refAllDecls( eque );
  std.testing.refAllDecls( emgr );
  std.testing.refAllDecls( elog );
}
