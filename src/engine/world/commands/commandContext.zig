const std = @import( "std" );

const entity  = @import( "../entity.zig" );
const compMgr = @import( "../components/compManager.zig" );
const relMgr  = @import( "../relations/relationManager.zig" );
const trtMgr  = @import( "../traits/traitManager.zig" );
const evtMgr  = @import( "../events/eventManager.zig" );

const EntityId        = entity.EntityId;
const CompManager     = compMgr.CompManager;
const RelationManager = relMgr.RelationManager;
const TraitManager    = trtMgr.TraitManager;
const EventManager    = evtMgr.EventManager;


/// Command-only view over World-owned managers for one explicit command drain.
/// Command callbacks own the durable mutation phase and may emit events for
/// successful simulation outcomes. This context intentionally excludes
/// `CommandManager`; commands-calling-commands are deferred until needed.
pub const CommandContext = struct
{
  activeEntities  : *const std.AutoHashMap( EntityId, void ),
  compManager     : *CompManager,
  relationManager : *RelationManager,
  traitManager    : *TraitManager,
  eventManager    : *EventManager,
};
