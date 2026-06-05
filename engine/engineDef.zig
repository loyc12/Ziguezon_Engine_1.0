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
pub const eventMgr   = @import( "world/events/eventManager.zig" );
pub const tilemapMgr = @import( "world/tilemap/tilemapManager.zig" );
pub const worldMgr   = @import( "world/worldManager.zig" );

pub const World       = worldMgr.World;
pub const TickContext = worldMgr.TickContext;


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


const component = @import( "world/components/component.zig" );

pub const ComponentStoreFactory = component.ComponentStoreFactory;


pub const baseComp = @import( "world/components/baseComponents.zig" );

pub const TransComp  = baseComp.TransComp;
pub const ShapeComp  = baseComp.ShapeComp;
pub const HitboxComp = baseComp.HitboxComp;
pub const SpriteComp = baseComp.SpriteComp;


// ================ EVENT ================

pub const eventCore = @import( "world/events/event.zig" );

pub const Event = eventCore.Event;

pub const EventType          = eventCore.EventType;
pub const EventPhase         = eventCore.EventPhase;
pub const EventData          = eventCore.EventData;
pub const EventFunc          = eventCore.EventFunc;

pub const EventListener      = eventCore.EventListener;
pub const EventListenerArray = eventCore.EventListenerArray;
pub const EventQueue         = eventCore.EventQueue;
