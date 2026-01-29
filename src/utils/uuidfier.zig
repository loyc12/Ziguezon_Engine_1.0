const std = @import( "std" );
const def = @import( "defs" );

const TokenType = u32; // Type for the token ( aka value ) of all UUIDs

var G_MAX_TOKEN : TokenType = 0;


// TODO : add a way to "destroy" a uuid, putting it in a reuse queue

pub const Uuid = struct
{
  token : TokenType,


  pub fn getMaxToken() TokenType
  {
    return G_MAX_TOKEN;
  }

  pub fn getNew() Uuid
  {
    G_MAX_TOKEN += 1;
    return Uuid.generate( G_MAX_TOKEN );
  }

  fn generate( token : TokenType ) Uuid
  {
    var retToken = token;
    if( token > G_MAX_TOKEN )
    {
      G_MAX_TOKEN += 1;
      retToken = G_MAX_TOKEN;
      def.log( .WARN, 0, @src(), "trying to use {d}, which is smaller than G_MAX_TOKEN ( {d} ), using {d} instead", .{ token, G_MAX_TOKEN, retToken });
    }

    // TODO : tie into a hypothetical UuidManager here, if it is ever needed
    // this manager should be able to do these things :
    // - list all currently used Ids
    // - have flags associated to each Id ( perhaps even directly in this Uuid struct )
    // - mark an Id as "destroyed" ( aka no longer in use )
    // - be able to reuse the destroyed id if we want to
    // - show what type of object an Id is tied to
    // - give a pointer to any IDed object

    return .{ .token = retToken };
  }

};