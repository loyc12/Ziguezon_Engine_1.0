const std = @import( "std" );
const def = @import( "defs" );

const ray       = def.ray;
const RayCol    = def.RayCol;
const newRayCol = def.newRayCol;

// ================================ COLOUR STRUCT ================================

pub const Colour = struct
{
  r : u8 = 255,
  g : u8 = 255,
  b : u8 = 255,
  a : u8 = 255,


  // ================ GENERATION ================

  pub inline fn new( r : u8, g : u8, b : u8, a : u8 ) Colour { return Colour{ .r = r, .g = g, .b = b, .a = a }; }

  pub inline fn newGray( v : u8,             a : u8 ) Colour { return Colour{ .r = v, .g = v, .b = v, .a = a }; }

  pub const transpa  = Colour{ .r = 0, .g = 0, .b = 0, .a = 0 }; // Transparent ? Clear

  pub const black    = Colour{ .r = 0,   .g = 0,   .b = 0   }; // True Black
  pub const nBlack   = Colour{ .r = 32,  .g = 32,  .b = 32  }; // Near Black

  pub const sGray    = Colour{ .r = 64,  .g = 64,  .b = 64  }; // Somber Gray
  pub const dGray    = Colour{ .r = 96,  .g = 96,  .b = 96  }; // Dark   Gray
  pub const mGray    = Colour{ .r = 128, .g = 128, .b = 128 }; // Medium Gray
  pub const lGray    = Colour{ .r = 160, .g = 160, .b = 160 }; // Light  Gray
  pub const pGray    = Colour{ .r = 192, .g = 192, .b = 192 }; // Pale   Gray

  pub const nWhite   = Colour{ .r = 224, .g = 224, .b = 224 }; // Near White
  pub const white    = Colour{ .r = 255, .g = 255, .b = 255 }; // True White


  pub const sRed     = Colour{ .r = 32,  .g = 0,   .b = 0   }; // Somber Red
  pub const dRed     = Colour{ .r = 64,  .g = 0,   .b = 0   }; // Dark   Red
  pub const mRed     = Colour{ .r = 128, .g = 0,   .b = 0   }; // Medium Red
  pub const lRed     = Colour{ .r = 192, .g = 0,   .b = 0   }; // Light  Red
  pub const red      = Colour{ .r = 255, .g = 0,   .b = 0   }; // True   Red
  pub const pRed     = Colour{ .r = 255, .g = 128, .b = 128 }; // Pale   Red

  pub const sVermil  = Colour{ .r = 32,  .g = 8,   .b = 0   }; // Somber Vermillion ( Sunset )
  pub const dVermil  = Colour{ .r = 64,  .g = 16,  .b = 0   }; // Dark   Vermillion ( Sunset )
  pub const mVermil  = Colour{ .r = 128, .g = 32,  .b = 0   }; // Medium Vermillion ( Sunset )
  pub const lVermil  = Colour{ .r = 192, .g = 48,  .b = 0   }; // Light  Vermillion ( Sunset )
  pub const vermil   = Colour{ .r = 255, .g = 64,  .b = 0   }; // True   Vermillion ( Sunset )
  pub const pVermil  = Colour{ .r = 255, .g = 160, .b = 128 }; // Pale   Vermillion ( Sunset )

  pub const sOrange  = Colour{ .r = 32,  .g = 16,  .b = 0   }; // Somber Orange
  pub const dOrange  = Colour{ .r = 64,  .g = 32,  .b = 0   }; // Dark   Orange
  pub const mOrange  = Colour{ .r = 128, .g = 64,  .b = 0   }; // Medium Orange
  pub const lOrange  = Colour{ .r = 192, .g = 96,  .b = 0   }; // Light  Orange
  pub const orange   = Colour{ .r = 255, .g = 128, .b = 0   }; // True   Orange
  pub const pOrange  = Colour{ .r = 255, .g = 192, .b = 128 }; // Pale   Orange

  pub const sGold    = Colour{ .r = 32,  .g = 24,  .b = 0   }; // Somber Gold
  pub const dGold    = Colour{ .r = 64,  .g = 48,  .b = 0   }; // Dark   Gold
  pub const mGold    = Colour{ .r = 128, .g = 96,  .b = 0   }; // Medium Gold
  pub const lGold    = Colour{ .r = 192, .g = 144, .b = 0   }; // Light  Gold
  pub const gold     = Colour{ .r = 255, .g = 192, .b = 0   }; // True   Gold
  pub const pGold    = Colour{ .r = 255, .g = 224, .b = 128 }; // Pale   Gold

  pub const sYellow  = Colour{ .r = 32,  .g = 32,  .b = 0   }; // Somber Yellow
  pub const dYellow  = Colour{ .r = 64,  .g = 64,  .b = 0   }; // Dark   Yellow
  pub const mYellow  = Colour{ .r = 128, .g = 128, .b = 0   }; // Medium Yellow
  pub const lYellow  = Colour{ .r = 192, .g = 192, .b = 0   }; // Light  Yellow
  pub const yellow   = Colour{ .r = 255, .g = 255, .b = 0   }; // True   Yellow
  pub const pYellow  = Colour{ .r = 255, .g = 255, .b = 128 }; // Pale   Yellow

  pub const sCharte  = Colour{ .r = 24,  .g = 32,  .b = 0   }; // Somber Chartreuse
  pub const dCharte  = Colour{ .r = 48,  .g = 64,  .b = 0   }; // Dark   Chartreuse
  pub const mCharte  = Colour{ .r = 96,  .g = 128, .b = 0   }; // Medium Chartreuse
  pub const lCharte  = Colour{ .r = 144, .g = 192, .b = 0   }; // Light  Chartreuse
  pub const charte   = Colour{ .r = 192, .g = 255, .b = 0   }; // True   Chartreuse
  pub const pCharte  = Colour{ .r = 224, .g = 255, .b = 128 }; // Pale   Chartreuse

  pub const sLime    = Colour{ .r = 16,  .g = 32,  .b = 0   }; // Somber Lime
  pub const dLime    = Colour{ .r = 32,  .g = 64,  .b = 0   }; // Dark   Lime
  pub const mLime    = Colour{ .r = 64,  .g = 128, .b = 0   }; // Medium Lime
  pub const lLime    = Colour{ .r = 96,  .g = 192, .b = 0   }; // Light  Lime
  pub const lime     = Colour{ .r = 128, .g = 255, .b = 0   }; // True   Lime
  pub const pLime    = Colour{ .r = 192, .g = 255, .b = 128 }; // Pale   Lime

  // Too close to green visually here

  pub const sGreen   = Colour{ .r = 0,   .g = 32,  .b = 0   }; // Somber Green
  pub const dGreen   = Colour{ .r = 0,   .g = 64,  .b = 0   }; // Dark   Green
  pub const mGreen   = Colour{ .r = 0,   .g = 128, .b = 0   }; // Medium Green
  pub const lGreen   = Colour{ .r = 0,   .g = 192, .b = 0   }; // Light  Green
  pub const green    = Colour{ .r = 0,   .g = 255, .b = 0   }; // True   Green
  pub const pGreen   = Colour{ .r = 128, .g = 255, .b = 128 }; // Pale   Green

  // Too close to green visually here

  pub const sTurquo  = Colour{ .r = 0,   .g = 32,  .b = 16  }; // Somber Turquoise
  pub const dTurquo  = Colour{ .r = 0,   .g = 64,  .b = 32  }; // Dark   Turquoise
  pub const mTurquo  = Colour{ .r = 0,   .g = 128, .b = 64  }; // Medium Turquoise
  pub const lTurquo  = Colour{ .r = 0,   .g = 192, .b = 96  }; // Light  Turquoise
  pub const turquo   = Colour{ .r = 0,   .g = 255, .b = 128 }; // True   Turquoise
  pub const pTurquo  = Colour{ .r = 128, .g = 255, .b = 192 }; // Pale   Turquoise

  pub const sTeal    = Colour{ .r = 0,   .g = 32,  .b = 24  }; // Somber Teal
  pub const dTeal    = Colour{ .r = 0,   .g = 64,  .b = 48  }; // Dark   Teal
  pub const mTeal    = Colour{ .r = 0,   .g = 128, .b = 96  }; // Medium Teal
  pub const lTeal    = Colour{ .r = 0,   .g = 192, .b = 144 }; // Light  Teal
  pub const teal     = Colour{ .r = 0,   .g = 255, .b = 192 }; // True   Teal
  pub const pTeal    = Colour{ .r = 128, .g = 255, .b = 224 }; // Pale   Teal

  pub const sCyan    = Colour{ .r = 0,   .g = 32,  .b = 32  }; // Somber Cyan
  pub const dCyan    = Colour{ .r = 0,   .g = 64,  .b = 64  }; // Dark   Cyan
  pub const mCyan    = Colour{ .r = 0,   .g = 128, .b = 128 }; // Medium Cyan
  pub const lCyan    = Colour{ .r = 0,   .g = 192, .b = 192 }; // Light  Cyan
  pub const cyan     = Colour{ .r = 0,   .g = 255, .b = 255 }; // True   Cyan
  pub const pCyan    = Colour{ .r = 128, .g = 255, .b = 255 }; // Pale   Cyan

  pub const sCerul   = Colour{ .r = 0,   .g = 24,  .b = 32  }; // Somber Cerulean ( Ciel )
  pub const dCerul   = Colour{ .r = 0,   .g = 48,  .b = 64  }; // Dark   Cerulean ( Ciel )
  pub const mCerul   = Colour{ .r = 0,   .g = 96,  .b = 128 }; // Medium Cerulean ( Ciel )
  pub const lCerul   = Colour{ .r = 0,   .g = 144, .b = 192 }; // Light  Cerulean ( Ciel )
  pub const cerul    = Colour{ .r = 0,   .g = 192, .b = 255 }; // True   Cerulean ( Ciel )
  pub const pCerul   = Colour{ .r = 128, .g = 224, .b = 255 }; // Pale   Cerulean ( Ciel )

  pub const sAzure   = Colour{ .r = 0,   .g = 16,  .b = 32  }; // Somber Azure
  pub const dAzure   = Colour{ .r = 0,   .g = 32,  .b = 64  }; // Dark   Azure
  pub const mAzure   = Colour{ .r = 0,   .g = 64,  .b = 128 }; // Medium Azure
  pub const lAzure   = Colour{ .r = 0,   .g = 96,  .b = 192 }; // Light  Azure
  pub const azure    = Colour{ .r = 0,   .g = 128, .b = 255 }; // True   Azure
  pub const pAzure   = Colour{ .r = 128, .g = 192, .b = 255 }; // Pale   Azure

  pub const sOcean   = Colour{ .r = 0,   .g = 8,   .b = 32  }; // Somber Ocean ( Egyptian Blue )
  pub const dOcean   = Colour{ .r = 0,   .g = 16,  .b = 64  }; // Dark   Ocean ( Egyptian Blue )
  pub const mOcean   = Colour{ .r = 0,   .g = 32,  .b = 128 }; // Medium Ocean ( Egyptian Blue )
  pub const lOcean   = Colour{ .r = 0,   .g = 48,  .b = 192 }; // Light  Ocean ( Egyptian Blue )
  pub const ocean    = Colour{ .r = 0,   .g = 64,  .b = 255 }; // True   Ocean ( Egyptian Blue )
  pub const pOcean   = Colour{ .r = 128, .g = 160, .b = 255 }; // Pale   Ocean ( Egyptian Blue )

  pub const sBlue    = Colour{ .r = 0,   .g = 0,   .b = 32  }; // Somber Blue  ( Cobalt Blue )
  pub const dBlue    = Colour{ .r = 0,   .g = 0,   .b = 64  }; // Dark   Blue  ( Cobalt Blue )
  pub const mBlue    = Colour{ .r = 0,   .g = 0,   .b = 128 }; // Medium Blue  ( Cobalt Blue )
  pub const lBlue    = Colour{ .r = 0,   .g = 0,   .b = 192 }; // Light  Blue  ( Cobalt Blue )
  pub const blue     = Colour{ .r = 0,   .g = 0,   .b = 255 }; // True   Blue  ( Cobalt Blue )
  pub const pBlue    = Colour{ .r = 128, .g = 128, .b = 255 }; // Pale   Blue  ( Cobalt Blue )

  pub const sIndigo  = Colour{ .r = 8,   .g = 0,   .b = 32  }; // Somber Indigo
  pub const dIndigo  = Colour{ .r = 16,  .g = 0,   .b = 64  }; // Dark   Indigo
  pub const mIndigo  = Colour{ .r = 32,  .g = 0,   .b = 128 }; // Medium Indigo
  pub const lIndigo  = Colour{ .r = 48,  .g = 0,   .b = 192 }; // Light  Indigo
  pub const indigo   = Colour{ .r = 64,  .g = 0,   .b = 255 }; // True   Indigo
  pub const pIndigo  = Colour{ .r = 160, .g = 128, .b = 255 }; // Pale   Indigo

  pub const sViolet  = Colour{ .r = 16,  .g = 0,   .b = 32  }; // Somber Violet
  pub const dViolet  = Colour{ .r = 32,  .g = 0,   .b = 64  }; // Dark   Violet
  pub const mViolet  = Colour{ .r = 64,  .g = 0,   .b = 128 }; // Medium Violet
  pub const lViolet  = Colour{ .r = 96,  .g = 0,   .b = 192 }; // Light  Violet
  pub const violet   = Colour{ .r = 128, .g = 0,   .b = 255 }; // True   Violet
  pub const pViolet  = Colour{ .r = 192, .g = 128, .b = 255 }; // Pale   Violet

  pub const sPurple  = Colour{ .r = 24,  .g = 0,   .b = 32  }; // Somber Purple
  pub const dPurple  = Colour{ .r = 48,  .g = 0,   .b = 64  }; // Dark   Purple
  pub const mPurple  = Colour{ .r = 96,  .g = 0,   .b = 128 }; // Medium Purple
  pub const lPurple  = Colour{ .r = 144, .g = 0,   .b = 192 }; // Light  Purple
  pub const purple   = Colour{ .r = 192, .g = 0,   .b = 255 }; // True   Purple
  pub const pPurple  = Colour{ .r = 224, .g = 128, .b = 255 }; // Pale   Purple

  pub const sMagenta = Colour{ .r = 32,  .g = 0,   .b = 32  }; // Somber Magenta
  pub const dMagenta = Colour{ .r = 64,  .g = 0,   .b = 64  }; // Dark   Magenta
  pub const mMagenta = Colour{ .r = 128, .g = 0,   .b = 128 }; // Medium Magenta
  pub const lMagenta = Colour{ .r = 192, .g = 0,   .b = 192 }; // Light  Magenta
  pub const magenta  = Colour{ .r = 255, .g = 0,   .b = 255 }; // True   Magenta
  pub const pMagenta = Colour{ .r = 255, .g = 128, .b = 255 }; // Pale   Magenta

  pub const sFuchsia = Colour{ .r = 32,  .g = 0,   .b = 24  }; // Somber Fuchsia
  pub const dFuchsia = Colour{ .r = 64,  .g = 0,   .b = 48  }; // Dark   Fuchsia
  pub const mFuchsia = Colour{ .r = 128, .g = 0,   .b = 96  }; // Medium Fuchsia
  pub const lFuchsia = Colour{ .r = 192, .g = 0,   .b = 144 }; // Light  Fuchsia
  pub const fuchsia  = Colour{ .r = 255, .g = 0,   .b = 192 }; // True   Fuchsia
  pub const pFuchsia = Colour{ .r = 255, .g = 128, .b = 224 }; // Pale   Fuchsia

  pub const sRose    = Colour{ .r = 32,  .g = 0,   .b = 16  }; // Somber Rose ( Pinkish )
  pub const dRose    = Colour{ .r = 64,  .g = 0,   .b = 32  }; // Dark   Rose ( Pinkish )
  pub const mRose    = Colour{ .r = 128, .g = 0,   .b = 64  }; // Medium Rose ( Pinkish )
  pub const lRose    = Colour{ .r = 192, .g = 0,   .b = 96  }; // Light  Rose ( Pinkish )
  pub const rose     = Colour{ .r = 255, .g = 0,   .b = 128 }; // True   Rose ( Pinkish )
  pub const pRose    = Colour{ .r = 255, .g = 128, .b = 192 }; // Pale   Rose ( Pinkish )

  pub const sCrimson = Colour{ .r = 32,  .g = 0,   .b = 8   }; // Somber Crimson
  pub const dCrimson = Colour{ .r = 64,  .g = 0,   .b = 16  }; // Dark   Crimson
  pub const mCrimson = Colour{ .r = 128, .g = 0,   .b = 32  }; // Medium Crimson
  pub const lCrimson = Colour{ .r = 192, .g = 0,   .b = 48  }; // Light  Crimson
  pub const crimson  = Colour{ .r = 255, .g = 0,   .b = 64  }; // True   Crimson
  pub const pCrimson = Colour{ .r = 255, .g = 128, .b = 160 }; // Pale   Crimson

  pub const pink   = pMagenta;

  pub const dBrown = dOrange;
  pub const brown  = mOrange;
  pub const lBrown = lOrange;


  // ================ CONVERSIONS ================

  pub inline fn toRayCol( self : *const Colour ) RayCol { return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a }; }

  pub inline fn setR( self : *const Colour, r : u8 ) Colour { return .{ .r = r, .g = self.g, .b = self.b, .a = self.a }; }
  pub inline fn setG( self : *const Colour, g : u8 ) Colour { return .{ .r = self.r, .g = g, .b = self.b, .a = self.a }; }
  pub inline fn setB( self : *const Colour, b : u8 ) Colour { return .{ .r = self.r, .g = self.g, .b = b, .a = self.a }; }
  pub inline fn setA( self : *const Colour, a : u8 ) Colour { return .{ .r = self.r, .g = self.g, .b = self.b, .a = a }; }



  // ================ COMPARISONS ================

  pub inline fn isWhite( self : *const Colour ) bool { return self.r >= 0 and self.g >= 0 and self.b >= 0; }
  pub inline fn isBlack( self : *const Colour ) bool { return self.r == 0 and self.g == 0 and self.b == 0; }
  pub inline fn isGray(  self : *const Colour ) bool { return self.r == self.g and self.g == self.b; }

  pub inline fn isRed(   self : *const Colour ) bool { return self.r > self.g and self.r > self.b; }
  pub inline fn isGreen( self : *const Colour ) bool { return self.g > self.r and self.r > self.b; }
  pub inline fn isBlue(  self : *const Colour ) bool { return self.b > self.g and self.b > self.g; }


  pub inline fn isSolid( self : *const Colour ) bool { return self.a == 255; }
  pub inline fn isTrans( self : *const Colour ) bool { return self.a != 0 and self.a != 255; }
  pub inline fn isVisib( self : *const Colour ) bool { return self.a >  0; }

  pub inline fn isEq(    self : *const Colour, other : Colour ) bool { return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a; }
  pub inline fn isDiff(  self : *const Colour, other : Colour ) bool { return self.r != other.r or  self.g != other.g or  self.b != other.b or  self.a != other.a; }

};