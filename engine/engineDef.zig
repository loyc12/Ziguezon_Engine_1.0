const std = @import( "std"   );
const utl = @import( "utils" );


pub var G_RNG : utl.rng_u.Randomiser = .{};
pub var G_NG  : Engine = .{}; // Global game engine instance
pub var G_CAM : utl.Cam2D = .{}; // Global camera2D instance

// TODO : split engineDef from utilsDef further once engine globals have clear ownership.


// ================================ GLOBAL INITIALIZATION / DEINITIALIZATION ================================

pub fn getAlloc() std.mem.Allocator { return std.heap.page_allocator; }

pub var GLOBAL_EPOCH : utl.TimeVal = .{};


pub fn initAllUtils( allocator : std.mem.Allocator ) void
{
  //GLOBAL_EPOCH = getNow();

  std.debug.print( "allocator.ptr    = {}\n", .{ allocator.ptr } );
  std.debug.print( "allocater.vtable = {}\n", .{ allocator.vtable } );

  utl.log_u.initFile();

  utl.rng_u.initGlobalRNG();
  G_RNG = utl.rng_u.G_RNG;
}

pub fn deinitAllUtils() void
{
  utl.log_u.deinitFile();

  G_RNG = undefined;
}



// ================================ INTERFACER HANDLERS ================================

// ================ ENGINE SETTINGS ================
// NOTE : Do not forget to call eng.Settings( SpecificGameInterface ) in your main function

const  ngs_h = @import( "interface/configs.zig" );
pub var G_ST : ngs_h.EngineSettings = .{}; // NOTE : Global engineSettings struct instance

pub inline fn loadSettings( module : anytype ) void { G_ST.loadSettings( module ); }


// ================ GAME HOOKS ================
// NOTE : Do not forget to call eng.loadHooks( SpecificGameInterface ) in your main function

const  ghk_h = @import( "interface/hooks.zig" );
pub var G_HK : ghk_h.GameHooks = .{}; // NOTE : Global gameHooks struct instance

pub const HookCntx = ghk_h.HookCntx;
pub const HookFunc = ghk_h.HookFunc;

pub inline fn loadHooks( module : anytype ) void                      { G_HK.loadHooks( module  ); }
pub inline fn tryHook( tag : ghk_h.e_hook_tag, cntx : HookCntx ) void { G_HK.tryHook( tag, cntx ); }



// ================================ ENGINE SYSTEMS ================================

pub const ng            = @import( "core/engine.zig" );
pub const Engine        = ng.Engine;


// ================ MANAGERS ================

pub const res_m = @import( "resources/resourceManager.zig" );
pub const bdy_m = @import( "legacy/body/bodyManager.zig" );
pub const tlm_m = @import( "world/tilemap/tilemapManager.zig" );
pub const vnt_m = @import( "world/events/eventManager.zig" );


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

pub const vnt        = @import( "world/events/event.zig" );

pub const Event      = vnt.Event;

pub const EventType  = vnt.EventType;
pub const EventPhase = vnt.EventPhase;
pub const EventData  = vnt.EventData;
pub const EventFunc  = vnt.EventFunc;

pub const EventListener      = vnt.EventListener;
pub const EventListenerArray = vnt.EventListenerArray;
pub const EventQueue         = vnt.EventQueue;
