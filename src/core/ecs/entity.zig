const std = @import( "std" );
const def = @import( "defs" );


pub const EntityId = u64;

pub const Entity = struct
{
  id    : EntityId = 0,
//mask : def.BitField64 = 0, // TODO : use me
};

pub const EntityIdRegistry = struct
{

  maxId : EntityId = 0, // NOTE : Id 0 is never attributed

//var freedIds : std.ArrayList( EntityId ) = undefined;

  pub inline fn reinit( self : *EntityIdRegistry ) void
  {
    self.maxId = 0;
  }

  inline fn getMaxId( self : *EntityIdRegistry ) EntityId
  {
    return self.maxId;
  }

  inline fn getNewId( self : *EntityIdRegistry ) EntityId
  {
    self.maxId += 1;
    return self.maxId;
  }

  pub inline fn getNewEntity( self : *EntityIdRegistry ) Entity
  {
    return .{ .id = self.getNewId() };
  }
};