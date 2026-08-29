const utl = @import( "utils" );

/// Tetrom's dark-pastel palette. Keeping display colours here makes contrast
/// tuning independent from the render and board-state implementations.
pub const BACKGROUND = utl.Colour.new( 0x15, 0x1A, 0x21, 0xFF ); // #151A21
pub const PLAYFIELD  = utl.Colour.new( 0x30, 0x3A, 0x46, 0xFF ); // #303A46
pub const WHITE      = utl.Colour.new( 0xFF, 0xFF, 0xFF, 0xFF ); // #FFFFFF
pub const GAME_OVER_VEIL = BACKGROUND.setA( 192 );

pub const INTERNAL_ANCHOR_DARKEN : u8 = 32;
pub const EMPTY_ANCHOR_LIGHTEN   : u8 = 16;

pub const RED        = utl.Colour.new( 0xF0, 0x71, 0x78, 0xFF ); // #F07178
pub const ORANGE     = utl.Colour.new( 0xF6, 0xA8, 0x6E, 0xFF ); // #F6A86E
pub const YELLOW     = utl.Colour.new( 0xE9, 0xCF, 0x68, 0xFF ); // #E9CF68
pub const LIME       = utl.Colour.new( 0xB5, 0xD0, 0x6D, 0xFF ); // #B5D06D
pub const GREEN      = utl.Colour.new( 0x6F, 0xC3, 0xA2, 0xFF ); // #6FC3A2
pub const CYAN       = utl.Colour.new( 0x70, 0xCD, 0xE3, 0xFF ); // #70CDE3
pub const BLUE       = utl.Colour.new( 0x7E, 0x9E, 0xEB, 0xFF ); // #7E9EEB
pub const PURPLE     = utl.Colour.new( 0xA9, 0x8B, 0xEA, 0xFF ); // #A98BEA
pub const MAGENTA    = utl.Colour.new( 0xD9, 0x8D, 0xE8, 0xFF ); // #D98DE8
pub const ROSE       = utl.Colour.new( 0xE9, 0x91, 0xAB, 0xFF ); // #E991AB
pub const CORAL      = utl.Colour.new( 0xE8, 0x83, 0x69, 0xFF ); // #E88369
pub const TEAL       = utl.Colour.new( 0x58, 0xB4, 0xAD, 0xFF ); // #58B4AD
pub const BRONZE     = utl.Colour.new( 0xC4, 0x87, 0x4E, 0xFF ); // #C4874E
pub const SILVER     = utl.Colour.new( 0xB8, 0xC2, 0xCD, 0xFF ); // #B8C2CD
pub const BROWN      = utl.Colour.new( 0x9A, 0x70, 0x5D, 0xFF ); // #9A705D

pub const TEXT       = utl.Colour.new( 0xF1, 0xF5, 0xF9, 0xFF ); // #F1F5F9
pub const TEXT_MUTED = utl.Colour.new( 0xBA, 0xC7, 0xD5, 0xFF ); // #BAC7D5
pub const CONTROLS   = utl.Colour.new( 0xF3, 0xD9, 0x8B, 0xFF ); // #F3D98B
pub const SCORE      = utl.Colour.new( 0x8F, 0xDC, 0xB5, 0xFF ); // #8FDCB5
