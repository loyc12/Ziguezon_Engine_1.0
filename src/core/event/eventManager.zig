const std = @import( "std" );
const def = @import( "defs" );

const EntityId = def.EntityId;
const Event    = def.Event;

const EventType  = def.EventType;
const EventPhase = def.EventPhase;
const EventData  = def.EventData;
const EventFunc  = def.EventFunc;

const EventListener      = def.EventListener;
const EventListenerArray = def.EventListenerArray;
pub const EventQueue     = def.EventQueue;


// ================================ EVENT MANAGER ================================

pub const EventManager = struct
{
  alloc     : std.mem.Allocator  = undefined,
  listeners : EventListenerArray = undefined,
  queue     : EventQueue         = undefined,

  isInit : bool = false,


  pub fn init( self : *EventManager, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Initializing event manager..." );

    if( self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "EventManager is already initialized : returning" );
      return;
    }

    self.alloc     = alloc;
    self.listeners = .init( alloc );

    self.queue = EventQueue.initCapacity( self.alloc, 65 ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to initialize event queue : {}", .{ err } );
      return;
    };

    self.isInit = true;

    def.qlog( .INFO, 0, @src(), "& EventManager initialized !" );
  }

  pub fn deinit( self : *EventManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Deinitializing event manager..." );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "EventManager is uninitialized : returning" );
      return;
    }

    var it = self.listeners.valueIterator();
    while( it.next() )| listenerList |
    {
      listenerList.deinit( self.alloc );
    }

    self.queue.deinit( self.alloc );
    self.listeners.deinit();
    self.isInit = false;

    def.qlog( .INFO, 0, @src(), "& EventManager denitialized !" );
  }

  pub fn subscribe( self : *EventManager, eventType : EventType, callerId : EntityId, callback : EventFunc ) !void
  {
      if( !self.isInit )
      {
        def.log( .WARN, 0, @src(), "Cannot subscribe to EventManager : uninitialized");
        return;
      }

      var listeners = try self.listeners.getOrPut( eventType );
      if( !listeners.found_existing )
      {
        listeners.value_ptr.* = std.ArrayList( EventListener ).init( self.alloc );
      }

      try listeners.value_ptr.append(.{ .listenerId = callerId, .callback = callback });

      def.log( .TRACE, 0, @src(), "Entity {d} subscribed to event type {d}", .{ callerId, @intFromEnum( eventType )});
  }

  pub fn unsubscribe( self: *EventManager, eventType : EventType, callerId : EntityId ) bool
  {
    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Cannot unsubscribe from EventManager : uninitialized");
      return false;
    }

    if( self.listeners.getPtr( eventType ))| listenerList |
    {
      for ( listenerList.items, 0.. )| listener, idx |
      {
        if( listener.listenerId == callerId )
        {
          _ = listenerList.orderedRemove( idx );

          def.log( .TRACE, 0, @src(), "Entity {d} unsubscribed from event type {d}", .{ callerId, @intFromEnum( eventType )});
          return true;
        }
      }
    }

    def.log( .DEBUG, 0, @src(), "Cannot unsubscribe Entity {d} : not found in listeners", .{ callerId });
    return false;
  }

  // ================ PUSH / POP ================

  pub fn pushEvent( self: *EventManager, event : Event ) !void
  {
    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Cannot push to EventManager : uninitialized" );
      return;
    }

    try self.queue.append( event );

    def.log( .TRACE, 0, @src(), "Event pushed to queue (queue size: {d})", .{ self.queue.items.len });
  }

  pub fn popEvent( self : *EventManager ) ?Event
  {
    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Cannot pop from EventManager : uninitialized" );
      return null;
    }

    if( self.queue.items.len == 0 ){ return null; }

    return self.queue.orderedRemove( 0 );
  }

  // ================ DISPATCH ================

  pub fn handleAllEvents( self: *EventManager ) void
  {
    _ = self.handleSomeEvents( 0 );
  }

  // Returns the amount of handled events
  pub fn handleSomeEvents( self: *EventManager, maxCount : u32 ) u32
  {
    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Cannot handle events in EventManager : uninitialized" );
      return;
    }

    var count : u32 = 0;
    while( self.popEvent() )| event | // Ends when event == null, or maxCount is reached and not 0
    {
      if( count >= maxCount and maxCount > 0 ){ return count; }

      self.dispatchEvent( event );
      count += 1;
    }
    return count;
  }

  fn dispatchEvent( self : *EventManager, event : Event ) void
  {
    if( self.listeners.get( event.eType ))| listenerList |
    {
      for ( listenerList.items )| listener |
      {
        // Prevents sending undesired events if listerner is focusing on a specific Id
        if( listener.filteredId == null or listener.filteredId == event.callerId )
        {
          listener.callback( event );
        }
      }
      return;
    }

    def.log(.DEBUG, 0, @src(), "No listeners for event type {d}", .{ @intFromEnum( event.eType )});

  }

  // ================ QUEUE UTILS ================

  pub fn clearQueue( self: *EventManager ) void
  {
    if( !self.isInit )
    {
      def.log( .WARN, 0, @src(), "Cannot clear EventManager : uninitialized" );
      return;
    }

    self.queue.clearRetainingCapacity();
  }

  pub fn getQueueSize( self: *const EventManager ) usize
  {
    return self.queue.items.len;
  }
};