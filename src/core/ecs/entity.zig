const std = @import( "std" );
const def = @import( "defs" );


pub const EntityId = u64;

pub var nextEntityId : EntityId = 1;

pub fn getNewEntityId() EntityId
{
  nextEntityId += 1;
  return( nextEntityId - 1 );
}