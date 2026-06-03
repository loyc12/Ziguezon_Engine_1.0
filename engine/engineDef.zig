const std = @import( "std"   );
const utl = @import( "utils" );


// ================================ GLOBAL VARS ================================

pub var G_RNG   : utl.Randomiser = .{};
pub var G_CAM   : utl.Cam2D      = .{};

// ================================ GAME INTERFACES ================================

// ================ ENGINE SETTINGS ================

const  cnfg_i = @import( "interface/configs.zig" );
pub var CNFGS : cnfg_i.EngineConfigs = .{};

pub inline fn loadConfigs( module : anytype ) void { CNFGS.loadConfigs( module ); }


// ================ GAME HOOKS ================

const  hook_i = @import( "interface/hooks.zig" );
pub var HOOKS : hook_i.GameHooks = .{};

pub const HookCntx = hook_i.HookCntx;
pub const HookFunc = hook_i.HookFunc;

pub inline fn loadHooks( module : anytype ) void                       { HOOKS.loadHooks( module  ); }
pub inline fn tryHook( tag : hook_i.e_hook_tag, cntx : HookCntx ) void { HOOKS.tryHook( tag, cntx ); }



// ================================ ENGINE SYSTEMS ================================

pub const eng_c  = @import( "core/engine.zig" );
pub const Engine = eng_c.Engine;

pub var G_ENG : Engine = .{};

// ================ MANAGERS ================

pub const res_m = @import( "resources/resourceManager.zig" );
pub const vnt_m = @import( "world/events/eventManager.zig" );
pub const tlm_m = @import( "world/tilemap/tilemapManager.zig" );
pub const bdy_m = @import( "legacy/body/bodyManager.zig" );


// ================ BODY ================

pub const bdy         = @import( "legacy/body/bodyCore.zig" );
pub const Body        = bdy.Body;

pub const e_bdy_flags = bdy.e_bdy_flags;


// ================ TILEMAP ================

pub const tlm          = @import( "world/tilemap/tilemap.zig" );

pub const Tile         = tlm.Tile;
pub const e_tile_type  = tlm.e_tile_type;

pub const Tilemap      = tlm.Tilemap;
pub const e_tlmp_shape = tlm.e_tlmp_shape;


// ================ SCRIPT ================

pub const spt        = @import( "legacy/script/scripter.zig" );

pub const Scripter   = spt.Scripter;
pub const ScriptData = spt.ScriptData;
pub const ScriptCntx = spt.ScriptCntx;
pub const ScriptFunc = spt.ScriptFunc;


// ================ ECS ================

pub const ntt              = @import( "world/entity.zig" );

pub const Entity           = ntt.Entity;
pub const EntityId         = ntt.EntityId;
pub const EntityIdRegistry = ntt.EntityIdRegistry;


pub const cmp                   = @import( "world/components/component.zig" );

pub const ComponentRegistry     = cmp.ComponentRegistry;
pub const componentStoreFactory = cmp.componentStoreFactory;


pub const cmp2 = @import( "world/components/baseComponents.zig" );

pub const TransComp  = cmp2.TransComp;
pub const ShapeComp  = cmp2.ShapeComp;
pub const SpriteComp = cmp2.SpriteComp;


// ================ EVENT ================

pub const vnt = @import( "world/events/event.zig" );

pub const Event = vnt.Event;

pub const EventType          = vnt.EventType;
pub const EventPhase         = vnt.EventPhase;
pub const EventData          = vnt.EventData;
pub const EventFunc          = vnt.EventFunc;

pub const EventListener      = vnt.EventListener;
pub const EventListenerArray = vnt.EventListenerArray;
pub const EventQueue         = vnt.EventQueue;
