const std = @import( "std" );
const def = @import( "defs" );


pub const EntityId = u64;

pub const Entity = struct
{
  id    : EntityId = 0,
//mask : def.BitField64 = 0, // TODO : use me
};

pub const IdRegistry = struct
{

  maxId : EntityId = 0, // NOTE : Id 0 is never attributed

  //var freedIds : std.ArrayList( EntityId ) = undefined;

  inline fn getMaxId( self : *IdRegistry ) EntityId
  {
    return self.maxId;
  }

  inline fn getNewId( self : *IdRegistry ) EntityId
  {
    self.maxId += 1;
    return self.maxId;
  }

  pub inline fn getNewEntity( self : *IdRegistry ) Entity
  {
    return .{ .id = self.getNewId() };
  }
};