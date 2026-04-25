const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );


const ResType = gdf.ResType;
const PopType = gdf.PopType;
const InfType = gdf.InfType;
const IndType = gdf.IndType;


// ================================ GOVERNMENT POLICY DATA ================================

pub const GovGeneralPolicyRates = def.GenDataGrid( f64, EconAgentEnum, GovActionEnum );

pub const GovPerResPolicyRates  = def.GenDataGrid( f64, ResType, GovActionEnum );
pub const GovPerPopPolicyRates  = def.GenDataGrid( f64, PopType, GovActionEnum );
pub const GovPerInfPolicyRates  = def.GenDataGrid( f64, InfType, GovActionEnum );
pub const GovPerIndPolicyRates  = def.GenDataGrid( f64, IndType, GovActionEnum );

pub const EconAgentEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  // NOTE : Only for non-deaggregated agents

  MNT, // Maintenance
  BLD, // Construction
  COM, // Import / Exports
};

pub const GovActionEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  TAXATION,  // Proportion of :
  //            POP / INF / IND       => profit taxed
  //            RES / MNT / BLD / COM => value taxed

  SUBSIDIES, // Proportion of :
  //            POP / INF / IND / MNT / BLD => raw expenses reimbursed
  //            RES / COM                   => value refinanced ( net tax )
};


// ================================ GOVERNMENT MONETARY DATA ================================
// NOTE : used in Economy to store local quantities and metrics

pub const GovMonetaryData = def.GenDataLine( f64, GovMonetaryEnum );

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

