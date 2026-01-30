const std = @import( "std" );
const def = @import( "defs" );


pub const EntityId = u64;

pub var nextEntityId : EntityId = 1;


pub const Entity = struct
{
  id    : EntityId,
//mask : def.BitField64 = 0, // TODO : use me
};

pub inline fn getNewEntityId() EntityId
{
  nextEntityId += 1;
  return( nextEntityId - 1 );
}

pub inline fn getNewEntity() Entity
{
  return .{ .id = getNewEntityId() };
}