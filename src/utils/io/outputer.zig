//! Small output primitives used by utils code that needs fixed-buffer records
//! or simple create/truncate file sinks.

const std = @import( "std" );


// ================================ FIXED STREAMS ================================

/// Returns a fixed-size stream type that appends a truncation marker on overflow.
pub fn GetFixedStream( comptime buffLen : usize, comptime truncMsg : [] const u8 ) type
{
  return struct
  {
    const Self = @This();

    buff       : [ buffLen ]u8 = undefined,
    idx        : usize         = 0,
    overflowed : bool          = false,


    pub fn init() Self { return .{}; }

    pub fn bytes( self : *const Self ) [] const u8 { return self.buff[ 0..self.idx ]; }

    pub fn append( self : *Self, text : [] const u8 ) void
    {
      if( self.overflowed ){ return; }

      const available = self.buff.len - self.idx;
      if( text.len <= available )
      {
        std.mem.copyForwards( u8, self.buff[ self.idx..self.idx + text.len ], text );
        self.idx += text.len;
        return;
      }

      if( available > 0 )
      {
        std.mem.copyForwards( u8, self.buff[ self.idx.. ], text[ 0..available ] );
        self.idx = self.buff.len;
      }
      self.markOverflow();
    }

    pub fn appendFormat( self : *Self, comptime fmt : [] const u8, args : anytype ) void
    {
      if( self.overflowed ){ return; }

      const written = std.fmt.bufPrint( self.buff[ self.idx.. ], fmt, args ) catch
      {
        self.markOverflow();
        return;
      };
      self.idx += written.len;
    }

    fn markOverflow( self : *Self ) void
    {
      if( self.overflowed ){ return; }

      self.overflowed = true;

      const keepLen = if( self.buff.len > truncMsg.len ) self.buff.len - truncMsg.len else 0;
      self.idx = @min( self.idx, keepLen );

      if( truncMsg.len <= self.buff.len - self.idx )
      {
        std.mem.copyForwards( u8, self.buff[ self.idx..self.idx + truncMsg.len ], truncMsg );
        self.idx += truncMsg.len;
      }
    }
  };
}


// ================================ FILE SINKS ================================

/// Formats `base.ext` plus a tag as `base_TAG.ext`.
pub fn formatTaggedFileName( buff : []u8, baseName : [] const u8, tag : [] const u8 ) ![] const u8
{
  const extStart = std.mem.lastIndexOfScalar( u8, baseName, '.' ) orelse baseName.len;

  return std.fmt.bufPrint(
    buff,
    "{s}_{s}{s}",
    .{ baseName[ 0..extStart ], tag, baseName[ extStart.. ] }
  ) catch return error.OutputFileNameTooLong;
}

/// Owns a single plain file handle whose path is stored in a caller-sized buffer.
/// NOTE : Assumes current working directory and create/truncate semantics : not a full file I/O abstraction.
pub fn GetNamedFileSink( comptime nameLen : usize ) type
{
  return struct
  {
    const Self = @This();

    file     : std.fs.File   = undefined,
    nameBuff : [ nameLen ]u8 = undefined,
    name     : [] const u8   = "",
    isOpen   : bool          = false,


    pub fn createTruncated( self : *Self, name : [] const u8 ) !void
    {
      if( name.len > self.nameBuff.len ){ return error.OutputFileNameTooLong; }

      std.mem.copyForwards( u8, self.nameBuff[ 0..name.len ], name );
      self.name = self.nameBuff[ 0..name.len ];

      self.file   = try std.fs.cwd().createFile( self.name, .{ .truncate = true });
      self.isOpen = true;
    }

    pub fn createTagged( self : *Self, baseName : [] const u8, tag : [] const u8 ) !void
    {
      self.name = try formatTaggedFileName( &self.nameBuff, baseName, tag );

      self.file   = try std.fs.cwd().createFile( self.name, .{ .truncate = true });
      self.isOpen = true;
    }

    pub fn close( self : *Self ) void
    {
      if( !self.isOpen ){ return; }

      self.file.close();
      self.isOpen = false;
    }

    pub fn writeAll( self : *Self, bytes : [] const u8 ) !void
    {
      if( !self.isOpen ){ return; }

      try self.file.writeAll( bytes );
    }
  };
}
