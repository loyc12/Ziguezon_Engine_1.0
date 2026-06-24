const std = @import( "std" );


/// Metadata attached when a command is queued.
/// Command payloads stay plain requested-change facts; execution ownership lives
/// in the game or engine phase that later drains the queue.
pub const CommandMeta = struct
{
  /// Monotonic order across all commands submitted through one manager.
  sequence      : u64   = 0,
  /// Order within the current World tick; reset by `World.tick`.
  tickOrder     : u64   = 0,
  /// Engine base tick active when the command was requested, if known.
  baseTickIndex : ?u128 = null,
};

/// Typed command record stored in transient command queues.
/// `CommandType` is a user-defined plain Zig struct, not an executable callback.
/// Execution functions are registered with the command queue/manager and receive
/// records of this shape when the command phase drains queued requests.
pub fn CommandRecord( comptime CommandType : type ) type
{
  assertCommandPayloadType( CommandType );

  return struct
  {
    meta  : CommandMeta = .{},
    value : CommandType,
  };
}

/// Rejects command shapes that are not plain requested-change facts.
/// Dataless structs are valid for simple signal-style commands.
pub fn assertCommandPayloadType( comptime CommandType : type ) void
{
  switch( @typeInfo( CommandType ))
  {
    .@"struct" => {},
    else       => @compileError( "Command type " ++ @typeName( CommandType ) ++ " must be a plain struct payload. Command execution belongs outside the payload declaration." ),
  }
}


// ================================ TESTS ================================

test "CommandRecord stores metadata and plain command payload"
{
  const MoveCommand = struct
  {
    entityId : u32 = 0,
    dx       : i32 = 0,
  };

  const record = CommandRecord( MoveCommand )
  {
    .meta  = .{ .sequence = 7, .tickOrder = 2, .baseTickIndex = 11 },
    .value = .{ .entityId = 42, .dx = -1 },
  };

  try std.testing.expect( record.meta.sequence        == 7  );
  try std.testing.expect( record.meta.tickOrder       == 2  );
  try std.testing.expect( record.meta.baseTickIndex.? == 11 );
  try std.testing.expect( record.value.entityId       == 42 );
  try std.testing.expect( record.value.dx             == -1 );
}

test "Command concepts allow dataless request facts"
{
  const FlushCommand = struct {};
  const record = CommandRecord( FlushCommand )
  {
    .meta  = .{ .sequence = 1 },
    .value = .{},
  };

  try std.testing.expect( record.meta.sequence == 1 );
}
