const eng  = @import( "engine" );
const utl = @import( "utils" );
const core = utl.drw_c;

const Vec2 = utl.Vec2;


// ================================ WORLD RENDERING ================================

const WorldTransform = struct
{
  // Used in world render to cancel-out camera position
  pub inline fn toRay( worldPos : Vec2 ) utl.RayVec2
  {
    return eng.G_ENG.camera.worldToRender( worldPos ).toRayVec2();
  }
};

const Core = core.GetDrawer( WorldTransform );


// ================ WORLD SPECIFIC FUNCTIONS ================

// NOTE : N/A for now


// ================ CORE DRAWING FUNCTIONS ================

pub const BASE_LINE_WIDTH = Core.BASE_LINE_WIDTH;

pub const pixel           = Core.pixel;
pub const macroPixel      = Core.macroPixel;

pub const basicLine       = Core.basicLine;
pub const basicCircle     = Core.basicCircle;
pub const basicCirclePerim = Core.basicCirclePerim;

pub const basicElli       = Core.basicElli;
pub const basicElliPerim  = Core.basicElliPerim;

pub const basicRect       = Core.basicRect;
pub const basicRectPerim  = Core.basicRectPerim;

pub const basicTria       = Core.basicTria;
pub const basicTriaPerim  = Core.basicTriaPerim;

pub const basicQuad       = Core.basicQuad;
pub const basicQuadPerim  = Core.basicQuadPerim;

pub const basicPoly       = Core.basicPoly;
pub const basicPolyPerim  = Core.basicPolyPerim;

pub const tria            = Core.tria;
pub const diam            = Core.diam;
pub const pent            = Core.pent;
pub const hexa            = Core.hexa;
pub const octa            = Core.octa;
pub const elli            = Core.elli;

pub const rect            = Core.rect;
pub const rectPerim       = Core.rectPerim;

pub const poly            = Core.poly;
pub const polyPerim       = Core.polyPerim;

pub const star            = Core.star;
pub const starPerim       = Core.starPerim;

pub const texture         = Core.texture;
pub const textureCentered = Core.textureCentered;
pub const texturePro      = Core.texturePro;
