const std = @import( "std" );
const def = @import( "defs" );

pub const ScriptCntx = *def.Engine; // Script Context ( Engine ptr )
pub const ScriptData = *anyopaque;  // Script Data    ( Struct ptr )

// Script functions mandatory format
pub const ScriptFunc = *const fn( cntx : ScriptCntx, data : ScriptData ) void;


// ================================ SCRIPTER STRUCT ================================

pub const Scripter = struct
{
  data   : ?ScriptData = null,
  onInit : ?ScriptFunc = null,
  onTick : ?ScriptFunc = null,
  onRndr : ?ScriptFunc = null,
  onExit : ?ScriptFunc = null,

  pub inline fn hasScript( self : *const Scripter ) bool
  {
    if( self.onTick != null
    or  self.onRndr != null
    or  self.onInit != null
    or  self.onExit != null ){ return true; }

    return false;
  }

  pub inline fn hasData( self : *const Scripter ) bool          { return( self.data != null ); }
  pub inline fn getData( self : *const Scripter ) ScriptData    { return( self.data         ); }
  pub inline fn setData( self : *Scripter, newData : ?ScriptData ) void { self.data = newData; }

  pub inline fn canInit( self : *const Scripter ) bool { return( self.onInit != null ); }
  pub inline fn canTick( self : *const Scripter ) bool { return( self.onTick != null ); }
  pub inline fn canRndr( self : *const Scripter ) bool { return( self.onRndr != null ); }
  pub inline fn canExit( self : *const Scripter ) bool { return( self.onExit != null ); }

  pub inline fn setInit( self : *const Scripter, f : ?ScriptFunc ) void{ self.onInit = f; }
  pub inline fn setTick( self : *const Scripter, f : ?ScriptFunc ) void{ self.onTick = f; }
  pub inline fn setRndr( self : *const Scripter, f : ?ScriptFunc ) void{ self.onRndr = f; }
  pub inline fn setExit( self : *const Scripter, f : ?ScriptFunc ) void{ self.onExit = f; }


  pub fn init( self : *Scripter, cntx : ScriptCntx ) bool
  {
    if( self.data )| data |
    {
      if( self.onInit )| f |
      {
        f( cntx, data );
        return true;
      }
    }
    return false;
  }

  pub fn tick( self : *Scripter, cntx : ScriptCntx, sdt : f32 ) bool
  {
    if( self.data )| data |
    {
      if( self.onTick )| f |
      {
        _ = sdt; // TODO : allow usage of std ?

        f( cntx, data );
        return true;
      }
    }
    return false;
  }

  pub fn rndr( self : *Scripter, cntx : ScriptCntx ) bool
  {
    if( self.data )| data |
    {
      if( self.onRndr )| f |
      {
        f( cntx, data );
        return true;
      }
    }
    return false;
  }

  pub fn exit( self : *Scripter, cntx : ScriptCntx ) bool
  {
    if( self.data )| data |
    {
      if( self.onExit )| f |
      {
        f( cntx, data );
        return true;
      }
    }
    return false;
  }
};