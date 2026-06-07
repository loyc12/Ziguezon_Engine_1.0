const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../entity.zig" );

const EntityId = entity.EntityId;


/// Cardinality policy is read in row direction: source entity -> target entity.
/// `ONE_TO_MANY` means one source can point at many targets, but each target can only have one source for this relation type.
/// `MANY_TO_ONE` means many sources can point at one target, but each source can only have one target for this relation type.
pub const RelationCardinalityPolicy = enum
{
  MANY_TO_MANY,
  ONE_TO_MANY,
  MANY_TO_ONE,
  ONE_TO_ONE,
};

// Use a config struct when relations need multiple independent policies.
// pub const RelationConfig = struct
// {
//   cardinalityPolicy : RelationCardinalityPolicy = .MANY_TO_MANY,
// };

pub const RelationKey = struct
{
  sourceId : EntityId = 0,
  targetId : EntityId = 0,

  pub inline fn init( sourceId : EntityId, targetId : EntityId ) RelationKey
  {
    return .{ .sourceId = sourceId, .targetId = targetId };
  }

  pub inline fn eql( self : RelationKey, other : RelationKey ) bool
  {
    return self.sourceId == other.sourceId and self.targetId == other.targetId;
  }
};

pub const RelationCleanupResult = struct
{
  removedCount : usize = 0,
  missingCount : usize = 0,
  failedCount  : usize = 0,

  pub inline fn isSuccess( self : RelationCleanupResult ) bool
  {
    return self.failedCount == 0;
  }
};

pub const LinkedTo = struct {};


pub fn getRelationCardinalityPolicy( comptime RelType : type ) RelationCardinalityPolicy
{
  if( @hasDecl( RelType, "cardinalityPolicy" ))
  {
    const  policy : RelationCardinalityPolicy = RelType.cardinalityPolicy;
    return policy;
  }

  return .MANY_TO_MANY;
}

pub inline fn isDatalessRelation( comptime RelType : type ) bool
{
  return @sizeOf( RelType ) == 0;
}


// ================================ RELATION STORE FUNCTIONS ================================

pub fn RelationStoreFactory( comptime RelType : type ) type
{
  return struct
  {
    const TypeName    = @typeName( RelType );
    const RelStore    = @This();
    const PayloadType = if( isDatalessRelation( RelType )) void else RelType;

    const IteratorMode = enum
    {
      SOURCE,
      TARGET,
    };

    pub const Entry = struct
    {
      key       : RelationKey,
      value_ptr : ?*RelType = null,
    };

    pub const Iterator = struct
    {
      store   : *RelStore,
      links   : []const EntityId = &[_]EntityId{},
      fixedId : EntityId        = 0,
      mode    : IteratorMode    = .SOURCE,
      index   : usize           = 0,

      pub fn next( self : *Iterator ) ?Entry
      {
        while( self.index < self.links.len )
        {
          const linkId = self.links[ self.index ];
          self.index += 1;

          const key = switch( self.mode )
          {
            .SOURCE => RelationKey.init( self.fixedId, linkId       ),
            .TARGET => RelationKey.init( linkId,       self.fixedId ),
          };

          if( !self.store.data.contains( key )){ continue; }

          if( isDatalessRelation( RelType ))
          {
            return .{ .key = key };
          }
          else
          {
            return .{ .key = key, .value_ptr = self.store.data.getPtr( key ) };
          }
        }

        return null;
      }
    };


    alloc       : std.mem.Allocator                                     = undefined,
    data        : std.AutoHashMap( RelationKey, PayloadType )           = undefined,
    sourceIndex : std.AutoHashMap( EntityId, std.ArrayList( EntityId )) = undefined,
    targetIndex : std.AutoHashMap( EntityId, std.ArrayList( EntityId )) = undefined,

    isInit : bool = false,


    // ================================ LIFECYCLE FUNCTIONS ================================

    pub fn init( self : *RelStore, alloc : std.mem.Allocator ) void
    {
      utl.log( .INFO, 0, @src(), "Initializing RelationStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        utl.log( .WARN, 0, @src(), "RelationStore for type {s} is already initialized : returning", .{ TypeName });
        return;
      }

      self.alloc       = alloc;
      self.data        = .init( alloc );
      self.sourceIndex = .init( alloc );
      self.targetIndex = .init( alloc );
      self.isInit      = true;
    }

    pub fn deinit( self : *RelStore ) void
    {
      utl.log( .INFO, 0, @src(), "Deinitializing RelationStore for type {s}", .{ TypeName });

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "RelationStore for type {s} is uninitialized : returning", .{ TypeName });
        return;
      }

      deinitIndex( self, &self.targetIndex );
      deinitIndex( self, &self.sourceIndex );
      self.data.deinit();
      self.isInit = false;
    }


    // ================================ ROW FUNCTIONS ================================

    pub fn add( self : *RelStore, sourceId : EntityId, targetId : EntityId, value : RelType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot add relation row for type {s} : uninitialized", .{ TypeName });
        return false;
      }
      if( sourceId == 0 or targetId == 0 )
      {
        utl.log( .DEBUG, 0, @src(), "Cannot add relation row for type {s} : source and target ids must be non-zero", .{ TypeName });
        return false;
      }

      const key = RelationKey.init( sourceId, targetId );
      if( self.data.contains( key ))
      {
        utl.log( .WARN, 0, @src(), "Cannot add relation row for type {s} : source {d} target {d} already exists", .{ TypeName, sourceId, targetId });
        return false;
      }
      if( !self.canAddCardinality( sourceId, targetId )){ return false; }

      const result = self.data.getOrPut( key ) catch { return false; };
      result.value_ptr.* = if( isDatalessRelation( RelType )) {} else value;

      if( !appendIndex( self, &self.sourceIndex, sourceId, targetId ))
      {
        _ = self.data.remove( key );
        return false;
      }
      if( !appendIndex( self, &self.targetIndex, targetId, sourceId ))
      {
        _ = removeIndex( self, &self.sourceIndex, sourceId, targetId );
        _ = self.data.remove( key );
        return false;
      }

      return true;
    }

    pub fn remove( self : *RelStore, sourceId : EntityId, targetId : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot remove relation row for type {s} : uninitialized", .{ TypeName });
        return false;
      }

      return self.removeKey( RelationKey.init( sourceId, targetId ));
    }

    pub fn has( self : *RelStore, sourceId : EntityId, targetId : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot inspect RelationStore for type {s} : uninitialized", .{ TypeName });
        return false;
      }

      return self.data.contains( RelationKey.init( sourceId, targetId ));
    }

    pub fn get( self : *RelStore, sourceId : EntityId, targetId : EntityId ) ?*RelType
    {
      if( isDatalessRelation( RelType ))
      {
        @compileError( "Relation type " ++ TypeName ++ " has zero size. Use hasRelation / has on dataless relation facts instead of getRelation / get." );
      }

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot get relation row for type {s} : uninitialized", .{ TypeName });
        return null;
      }

      return self.data.getPtr( RelationKey.init( sourceId, targetId ));
    }

    pub fn removeEntity( self : *RelStore, entityId : EntityId ) RelationCleanupResult
    {
      var result : RelationCleanupResult = .{};

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot remove Entity {d} from RelationStore for type {s} : uninitialized", .{ entityId, TypeName });
        result.failedCount = 1;
        return result;
      }

      var keys : std.ArrayList( RelationKey ) = .empty;
      defer keys.deinit( self.alloc );

      if( self.sourceIndex.getPtr( entityId ))| targets |
      {
        for( targets.items )| targetId |
        {
          keys.append( self.alloc, RelationKey.init( entityId, targetId )) catch
          {
            result.failedCount = 1;
            return result;
          };
        }
      }
      if( self.targetIndex.getPtr( entityId ))| sources |
      {
        for( sources.items )| sourceId |
        {
          if( sourceId == entityId ){ continue; }

          keys.append( self.alloc, RelationKey.init( sourceId, entityId )) catch
          {
            result.failedCount = 1;
            return result;
          };
        }
      }

      if( keys.items.len == 0 )
      {
        result.missingCount = 1;
        return result;
      }

      for( keys.items )| key |
      {
        if( self.removeKey( key )){ result.removedCount += 1; }
        else{ result.failedCount += 1; }
      }

      return result;
    }

    pub fn sourceIterator( self : *RelStore, sourceId : EntityId ) Iterator
    {
      if( self.sourceIndex.getPtr( sourceId ))| links |
      {
        return .{ .store = self, .links = links.items, .fixedId = sourceId, .mode = .SOURCE };
      }

      return .{ .store = self, .fixedId = sourceId, .mode = .SOURCE };
    }

    pub fn targetIterator( self : *RelStore, targetId : EntityId ) Iterator
    {
      if( self.targetIndex.getPtr( targetId ))| links |
      {
        return .{ .store = self, .links = links.items, .fixedId = targetId, .mode = .TARGET };
      }

      return .{ .store = self, .fixedId = targetId, .mode = .TARGET };
    }


    // ================================ INTERNAL FUNCTIONS ================================

    fn removeKey( self : *RelStore, key : RelationKey ) bool
    {
      if( !self.data.contains( key ))
      {
        utl.log( .DEBUG, 0, @src(), "Cannot remove relation row for type {s} : source {d} target {d} not found", .{ TypeName, key.sourceId, key.targetId });
        return false;
      }

      const sourceRemoved = removeIndex( self, &self.sourceIndex, key.sourceId, key.targetId );
      const targetRemoved = removeIndex( self, &self.targetIndex, key.targetId, key.sourceId );
      const dataRemoved   = self.data.remove( key );

      if( !sourceRemoved or !targetRemoved or !dataRemoved )
      {
        utl.log( .ERROR, 0, @src(), "RelationStore index mismatch while removing type {s} source {d} target {d}", .{ TypeName, key.sourceId, key.targetId });
        return false;
      }

      return true;
    }

    fn deinitIndex( self : *RelStore, index : *std.AutoHashMap( EntityId, std.ArrayList( EntityId ))) void
    {
      var iter = index.valueIterator();
      while( iter.next() )| links |{ links.deinit( self.alloc ); }

      index.deinit();
    }

    fn appendIndex( self : *RelStore, index : *std.AutoHashMap( EntityId, std.ArrayList( EntityId )), id : EntityId, linkId : EntityId ) bool
    {
      if( index.getPtr( id ))| links |
      {
        links.append( self.alloc, linkId ) catch { return false; };
        return true;
      }

      var links : std.ArrayList( EntityId ) = .empty;
      links.append( self.alloc, linkId ) catch { return false; };
      index.put( id, links ) catch
      {
        links.deinit( self.alloc );
        return false;
      };

      return true;
    }

    fn removeIndex( self : *RelStore, index : *std.AutoHashMap( EntityId, std.ArrayList( EntityId )), id : EntityId, linkId : EntityId ) bool
    {
      const links = index.getPtr( id ) orelse return false;

      for( links.items, 0.. )| item, idx |
      {
        if( item != linkId ){ continue; }

        const lastIndex = links.items.len - 1;
        if( idx != lastIndex ){ links.items[ idx ] = links.items[ lastIndex ]; }
        _ = links.pop();

        if( links.items.len == 0 )
        {
          links.deinit( self.alloc );
          _ = index.remove( id );
        }

        return true;
      }

      return false;
    }

    fn canAddCardinality( self : *RelStore, sourceId : EntityId, targetId : EntityId ) bool
    {
      const cardinality = getRelationCardinalityPolicy( RelType );

      switch( cardinality )
      {
        .MANY_TO_MANY              => return true,
        .MANY_TO_ONE, .ONE_TO_ONE, => if( self.sourceIndex.getPtr( sourceId ))| links |
        {
          if( links.items.len > 0 )
          {
            utl.log( .WARN, 0, @src(), "Cannot add relation row for type {s} : source {d} already has a target", .{ TypeName, sourceId });
            return false;
          }
        },
        .ONE_TO_MANY => {}, // pass
      }

      switch( cardinality )
      {
        .MANY_TO_MANY, .MANY_TO_ONE, => return true,
        .ONE_TO_MANY,  .ONE_TO_ONE,  => if( self.targetIndex.getPtr( targetId ))| links |
        {
          if( links.items.len > 0 )
          {
            utl.log( .WARN, 0, @src(), "Cannot add relation row for type {s} : target {d} already has a source", .{ TypeName, targetId });
            return false;
          }
        },
      }

      return true;
    }
  };
}


// ================================ TESTS ================================

test "RelationKey preserves source target equality"
{
  const keyA = RelationKey.init( 1, 2 );
  const keyB = RelationKey.init( 1, 2 );
  const keyC = RelationKey.init( 2, 1 );

  try std.testing.expect(  keyA.eql( keyB ));
  try std.testing.expect( !keyA.eql( keyC ));
}

test "RelationStore add get has remove"
{
  const TestRel = struct
  {
    weight : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect(  store.add( 1, 2, .{ .weight = 42 }));
  try std.testing.expect( !store.add( 1, 2, .{ .weight = 99 }));
  try std.testing.expect(  store.has( 1, 2 ));
  try std.testing.expect(  store.get( 1, 2 ).?.weight == 42 );
  try std.testing.expect(  store.remove( 1, 2 ));
  try std.testing.expect( !store.has( 1, 2 ));
  try std.testing.expect(  store.get( 1, 2 ) == null );
  try std.testing.expect( !store.remove( 1, 2 ));
}

test "RelationStore supports dataless keyed existence"
{
  var store : RelationStoreFactory( LinkedTo ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect(  store.add( 1, 2, .{} ));
  try std.testing.expect(  store.has( 1, 2 ));
  try std.testing.expect( !store.has( 2, 1 ));
  try std.testing.expect(  store.remove( 1, 2 ));
  try std.testing.expect( !store.has( 1, 2 ));
}

test "RelationStore source and target iterators use indexes"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect( store.add( 1, 3, .{ .value = 20 }));
  try std.testing.expect( store.add( 4, 2, .{ .value = 30 }));

  var sourceCount : usize = 0;
  var sourceSum   : u32   = 0;
  var srcIter = store.sourceIterator( 1 );
  while( srcIter.next() )| entry |
  {
    sourceCount += 1;
    sourceSum   += entry.value_ptr.?.value;
    try std.testing.expect( entry.key.sourceId == 1 );
  }

  var targetCount : usize = 0;
  var targetSum   : u32   = 0;
  var tgtIter = store.targetIterator( 2 );
  while( tgtIter.next() )| entry |
  {
    targetCount += 1;
    targetSum   += entry.value_ptr.?.value;
    try std.testing.expect( entry.key.targetId == 2 );
  }

  try std.testing.expect( sourceCount == 2 );
  try std.testing.expect( sourceSum   == 30 );
  try std.testing.expect( targetCount == 2 );
  try std.testing.expect( targetSum   == 40 );
}

test "RelationStore remove repairs all indexes"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect( store.add( 1, 3, .{ .value = 20 }));
  try std.testing.expect( store.add( 4, 2, .{ .value = 30 }));
  try std.testing.expect( store.remove( 1, 2 ));

  try std.testing.expect( !store.has( 1, 2 ));

  var sourceCount : usize = 0;
  var srcIter = store.sourceIterator( 1 );
  while( srcIter.next() )| entry |
  {
    sourceCount += 1;
    try std.testing.expect( entry.key.targetId == 3 );
  }

  var targetCount : usize = 0;
  var tgtIter = store.targetIterator( 2 );
  while( tgtIter.next() )| entry |
  {
    targetCount += 1;
    try std.testing.expect( entry.key.sourceId == 4 );
  }

  try std.testing.expect( sourceCount == 1 );
  try std.testing.expect( targetCount == 1 );
}

test "RelationStore removeEntity removes source and target rows"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect( store.add( 2, 3, .{ .value = 20 }));
  try std.testing.expect( store.add( 4, 2, .{ .value = 30 }));
  try std.testing.expect( store.add( 4, 5, .{ .value = 40 }));

  const cleanup = store.removeEntity( 2 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 3 );

  try std.testing.expect( !store.has( 1, 2 ));
  try std.testing.expect( !store.has( 2, 3 ));
  try std.testing.expect( !store.has( 4, 2 ));
  try std.testing.expect(  store.has( 4, 5 ));

  const missing = store.removeEntity( 99 );
  try std.testing.expect( missing.isSuccess() );
  try std.testing.expect( missing.removedCount == 0 );
  try std.testing.expect( missing.missingCount == 1 );
}

test "RelationStore supports many to one cardinality"
{
  const TestRel = struct
  {
    pub const cardinalityPolicy : RelationCardinalityPolicy = .MANY_TO_ONE;

    value : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect(  store.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect( !store.add( 1, 3, .{ .value = 20 }));
  try std.testing.expect(  store.add( 2, 3, .{ .value = 30 }));
}

test "RelationStore supports one to many cardinality"
{
  const TestRel = struct
  {
    pub const cardinalityPolicy : RelationCardinalityPolicy = .ONE_TO_MANY;

    value : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect(  store.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect(  store.add( 1, 3, .{ .value = 20 }));
  try std.testing.expect( !store.add( 4, 2, .{ .value = 30 }));
}

test "RelationStore supports one to one cardinality"
{
  const TestRel = struct
  {
    pub const cardinalityPolicy : RelationCardinalityPolicy = .ONE_TO_ONE;

    value : u32 = 0,
  };

  var store : RelationStoreFactory( TestRel ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect(  store.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect( !store.add( 1, 3, .{ .value = 20 }));
  try std.testing.expect( !store.add( 4, 2, .{ .value = 30 }));
  try std.testing.expect(  store.add( 4, 5, .{ .value = 40 }));
}
