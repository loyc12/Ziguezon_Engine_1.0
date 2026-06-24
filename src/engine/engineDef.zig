const std = @import( "std" );
const utl = @import( "utils" );

// ================================ GAME ADAPTER ================================

// ================ ENGINE CONFIGS ================

const  cnfg_i = @import( "gameAdapter/configs.zig" );
pub var G_CNFGS : cnfg_i.EngineConfigs = .{};

pub inline fn loadConfigs( module : anytype ) void { G_CNFGS.loadConfigs( module ); }


// ================ GAME HOOKS ================

const  hook_i = @import( "gameAdapter/hooks.zig" );
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
pub const worldMgr   = @import( "world/worldManager.zig" );
pub const uiMgr      = @import( "ui/uiManager.zig" );

pub const World          = worldMgr.World;
pub const WorldManager   = worldMgr.WorldManager;
pub const TickInfo       = worldMgr.TickInfo;
pub const UiManager      = uiMgr.UiManager;
pub const UiPanelHandle  = uiMgr.UiPanelHandle;
pub const UiPanelConfig  = uiMgr.UiPanelConfig;
pub const UiManagerEvent = uiMgr.UiManagerEvent;


// ================ RENDER ================

pub const wCam    = @import( "render/worldCamera.zig" );
pub const wDraw   = @import( "render/drawerWorld.zig" );
pub const wSprite = @import( "render/spriteWorld.zig" );

pub const WorldCam = wCam.WorldCam;


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

const query = @import( "world/queries/query.zig" );

pub const WorldQuery = query.WorldQuery;

const arch = @import( "world/archetypes/archetype.zig"       );
const amgr = @import( "world/archetypes/archetypeManager.zig" );
const actx = @import( "world/archetypes/spawnContext.zig"     );
pub const baseArch = @import( "world/archetypes/baseArchetypes.zig" );

pub const Archetype                = worldMgr.Archetype;
pub const ArchetypeManager         = worldMgr.ArchetypeManager;
pub const ArchetypeSpawnContext    = worldMgr.ArchetypeSpawnContext;
pub const ArchetypeSpawnResult     = arch.ArchetypeSpawnResult;
pub const ArchetypeReportedId      = arch.ArchetypeReportedId;
pub const PersistentLinkArchetype  = baseArch.PersistentLinkArchetype;


const rel  = @import( "world/relations/relation.zig" );

pub const RelationStoreFactory = rel.RelationStoreFactory;
pub const RelationKey          = rel.RelationKey;
pub const RelationLimitPolicy  = rel.RelationLimitPolicy;
pub const LinkedTo             = rel.LinkedTo;

const trt  = @import( "world/traits/trait.zig" );
const tmgr = @import( "world/traits/traitManager.zig" );

pub const TraitSetFactory = trt.TraitSetFactory;
pub const TraitManager    = tmgr.TraitManager;
pub const Persistent      = trt.Persistent;

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
pub const TraitApplied     = evt.TraitApplied;
pub const TraitRemoved     = evt.TraitRemoved;

const cmd  = @import( "world/commands/command.zig" );
const cque = @import( "world/commands/commandQueue.zig" );
const cmgr = @import( "world/commands/commandManager.zig" );

pub const CommandMeta         = cmd.CommandMeta;
pub const CommandRecord       = cmd.CommandRecord;
pub const CommandQueueFactory = cque.CommandQueueFactory;
pub const CommandManager      = cmgr.CommandManager;

const rule = @import( "world/rules/rule.zig" );
const rmgr = @import( "world/rules/ruleManager.zig" );

pub const Rule        = rule.Rule;
pub const RuleContext = rule.RuleContext;
pub const RuleFn      = rule.RuleFn;
pub const RuleManager = rmgr.RuleManager;


pub const baseComp = @import( "world/components/baseComps.zig" );

pub const TransComp  = baseComp.TransComp;
pub const ShapeComp  = baseComp.ShapeComp;
pub const HitboxComp = baseComp.HitboxComp;
pub const SpriteComp = baseComp.SpriteComp;

test "engine world declarations"
{
  utl.G_EPOCH = utl.getNow();

  std.testing.refAllDecls( worldMgr );
  std.testing.refAllDecls( query    );
  std.testing.refAllDecls( arch     );
  std.testing.refAllDecls( amgr     );
  std.testing.refAllDecls( actx     );
  std.testing.refAllDecls( baseArch );
  std.testing.refAllDecls( trt      );
  std.testing.refAllDecls( tmgr     );
  std.testing.refAllDecls( evt      );
  std.testing.refAllDecls( eque     );
  std.testing.refAllDecls( emgr     );
  std.testing.refAllDecls( elog     );
  std.testing.refAllDecls( cmd      );
  std.testing.refAllDecls( cque     );
  std.testing.refAllDecls( cmgr     );
  std.testing.refAllDecls( rule     );
  std.testing.refAllDecls( rmgr     );
  std.testing.refAllDecls( uiMgr    );
}
