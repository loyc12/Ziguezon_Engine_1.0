const std = @import( "std" );
const def = @import( "defs" );

const EntityId  = def.EntityId;

pub const EventType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  CLICK_WORLD,
  CLICK_UI,

  KEYPRESS_WORLD,
  KEYPRESS_UI,

  CONTACT, // zone related trigger ( ex : collisions )
  PHYSICS, // non-zone related trigger ( ex : gravity pulse )

  ANIMATION,
  MUSIC,
  AUDIO,

  CUSTOM = 255,
};

pub const EventPhase = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  STEP, // Default

  START,
  FINISH,

  PAUSE,
  PLAY, // AKA restart
};

//pub const EventTiming = enum( u8 )
//{
//  pub const count = @typeInfo( @This() ).@"enum".fields.len;
//
//  INSTANT,
//  DELAYED,
//  PERISHABLE, // useful ?
//};

pub const EventData = union
{
  coord2 : def.Coords2, // 2 x i32
  coord3 : def.Coords3, // 3 x i32

  vec2 : def.Vec2, // 2 x f32
  vecA : def.VecA, // 3 x f32
  vec3 : def.Vec3, // 3 x f32

  col : def.Colour, // 4 x u8

  bit1 : u8,
  bit2 : u16,
  bit4 : u32,

  byte1 : u64,
  byte2 : u128,
  byte4 : u256, // 8 x u8

  custom : *anyopaque // u128 ?
};

pub const Event = struct
{
  eType    : EventType,
  ePhase   : EventPhase,
//eTiming  : EventTiming,
  data     : EventData,

  callerId : ?EntityId,
  targetId : ?EntityId,

  genTime  : ?def.TimeVal, // When was this generated             ( real time )
//endTime  : ?def.TimeVal, // When does this event end / perish   ( real time )
};


pub const EventFunc  = *const fn( event : Event ) void;


pub const EventListener = struct // Tied to an eventType in the eventManager. One instance per listening entity
{
  listenerId : EntityId,
  filteredId : ?EntityId, // If set, filters out all all event from other entities NOTE : be careful about duplicate listening

  callback   : EventFunc, // What to do with caught events
};

pub const EventListenerArray = std.AutoHashMap( EventType, std.ArrayList( EventListener ));

pub const EventQueue = std.ArrayList( Event );
