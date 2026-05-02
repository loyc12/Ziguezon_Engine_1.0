const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );


const ResType = gdf.ResType;
const PopType = gdf.PopType;
const InfType = gdf.InfType;
const IndType = gdf.IndType;

// TODO : Review implementation FULLY before implementing - this is a draft, and likely has blindspots / overcomplexities

// ================================ GOVERNMENT POLICY DATA ================================

// Applies equaly to all Agent subtypess
pub const GovGeneralPolicyRates = def.GenDataGrid( f64, TaxGroupEnum, TaxTypeEnum );

// Applies on top of gene
pub const GovPerResPolicyRates  = def.GenDataGrid( f64, ResType, TaxTypeEnum );
pub const GovPerPopPolicyRates  = def.GenDataGrid( f64, PopType, TaxTypeEnum );
pub const GovPerInfPolicyRates  = def.GenDataGrid( f64, InfType, TaxTypeEnum );
pub const GovPerIndPolicyRates  = def.GenDataGrid( f64, IndType, TaxTypeEnum );


pub const TaxGroupEnum = enum( u8 )
{
  // Applies to X
  ALL, // Everyone equaly
  POP, // Population     ( on top of ALL rates )
  IND, // Infrastructure ( on top of ALL rates )
  INF, // Industry       ( on top of ALL rates )
  COM, // Commerce       ( on top of ALL rates )
};

pub const TaxTypeEnum = enum( u8 )
{
  // Proportion of X taxed / subsidised
  PROFIT, // Net profits
  PROD,   // Value of produced resources ( operations + deconstruction income )
  CONS,   // Value of consumed resources ( operations costs  )
  MAINT,  // Value of bought resources ( maintenance costs )
  BUILD,  // Value of bought resources ( building costs    )
};


// ================================ GOVERNMENT MONETARY DATA ================================
// NOTE : used in Economy to store local quantities and metrics

pub const GovMonetaryData = def.GenDataLine( f64, GovMonetaryEnum );


// TODO : turn into struct with sub-Matrices instead
pub const GovMonetaryEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  SAVINGS,   // Accumulated capital ( Tresury )
  NET_DELTA, // Revenues - Expenses ( negative = deficit )


  // ======== Borrowing ========

  TOT_DEBT,  // Government debt
  INT_DEBT,  // Debt interest rates


  // ======== Revenues ========

  TOT_REVENUE,


  // Taxation

  TAX_POP, // Population     ( Income )
  TAX_INF, // Infrastructure ( Income )
  TAX_IND, // Industry       ( Income )

  TAX_RES, // Resources      ( VAT    )
  TAX_BLD, // Construction   ( VAT    )
  TAX_LND, // Land use       ( Tarifs )
  TAX_COM, // Imports        ( Tarifs )

  TAX_TOT, // Sum


  // Discretionary income

//SOLD_RES,
//SOLD_TOT,


  // ======== Expenses ========

  TOT_EXPENSE,


  // Subsidies ( Expenses reimbursment )

  SUB_POP, // Population
  SUB_INF, // Infrastructure
  SUB_IND, // Industry

  SUB_RES, // Resource production
  SUB_MNT, // Private maintenance
  SUB_BLD, // Private construction

  SUB_TOT, // Sum


  // Grants ( Capital injection )

  GRT_POP, // Population
  GRT_INF, // Infrastructure
  GRT_IND, // Industry

  GRT_TOT, // Sum


  // Discretionary spendings

  SPEND_BLD, // Gov. construction projects
//SPEND_TOT, // Sum
};

