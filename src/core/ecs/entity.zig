const std = @import( "std" );
const def = @import( "defs" );


pub const EntityId = u64;

var maxId : EntityId = 0; // NOTE : Id 0 is never attributed

//var freedIds : std.ArrayList( EntityId ) = undefined;

inline fn getMaxId() EntityId
{
  return maxId;
}

inline fn getNewId() EntityId
{
  maxId += 1;
  return maxId;
}


pub const Entity = struct
{
  id    : EntityId,
//mask : def.BitField64 = 0, // TODO : use me
};

pub inline fn getNewEntity() Entity
{
  return .{ .id = getNewId() };
}