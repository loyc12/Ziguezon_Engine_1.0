// This file simply enumerates some shortcuts for various text attributes and colours that can be used in terminal output.

const START = "\x1b[";   // Start code
const END   = "m";  // End code

// TEXT ATTRIBUTES
pub const RESET  = START ++ "0"  ++ END; // Reset all attributes to default
pub const BOLD   = START ++ "1"  ++ END; // Bold text
pub const FAINT  = START ++ "2"  ++ END; // Dimmed text
pub const F_OFF  = START ++ "22" ++ END; // Turn off faint/bold

pub const ULINE  = START ++ "4"  ++ END; // Underlined text
pub const U_OFF  = START ++ "24" ++ END; // Turn off underline

pub const PULSE  = START ++ "5"  ++ END; // Blinking text
pub const P_OFF  = START ++ "25" ++ END; // Turn off blinking

pub const INVER  = START ++ "7"  ++ END; // swap foreground and background colors
pub const I_OFF  = START ++ "27" ++ END; // Turn off inverse colors

pub const STRIK  = START ++ "9"  ++ END; // Strikethrough text
pub const S_OFF  = START ++ "29" ++ END; // Turn off strikethrough

// FOREGROUND COLOURS
pub const BLACK  = START ++ "30" ++ END;
pub const GRAY   = START ++ "90" ++ END; // shorthand for bright black
pub const WHITE  = START ++ "37" ++ END;
pub const MAGEN  = START ++ "35" ++ END;
pub const RED    = START ++ "31" ++ END;
pub const YELLOW = START ++ "33" ++ END;
pub const GREEN  = START ++ "32" ++ END;
pub const CYAN   = START ++ "36" ++ END;
pub const BLUE   = START ++ "34" ++ END;

// BACKGROUND COLOURS
pub const B_BLACK  = START ++ "40" ++ END;
pub const B_WHITE  = START ++ "47" ++ END;
pub const B_MAGEN  = START ++ "45" ++ END;
pub const B_RED    = START ++ "41" ++ END;
pub const B_YELLOW = START ++ "43" ++ END;
pub const B_GREEN  = START ++ "42" ++ END;
pub const B_CYAN   = START ++ "46" ++ END;
pub const B_BLUE   = START ++ "44" ++ END;

// FOREGROUND COLOURS ( BRIGHT VARIANTS )
pub const BLACK_V  = START ++ "90" ++ END;
pub const WHITE_V  = START ++ "97" ++ END;
pub const MAGEN_V  = START ++ "95" ++ END;
pub const RED_V    = START ++ "91" ++ END;
pub const YELLOW_V = START ++ "93" ++ END;
pub const GREEN_V  = START ++ "92" ++ END;
pub const CYAN_V   = START ++ "96" ++ END;
pub const BLUE_V   = START ++ "94" ++ END;

// BACKGROUND COLOURS BRIGHT ( BRIGHT VARIANTS )
pub const B_BLACK_V  = START ++ "100" ++ END;
pub const B_WHITE_V  = START ++ "107" ++ END;
pub const B_MAGEN_V  = START ++ "105" ++ END;
pub const B_RED_V    = START ++ "101" ++ END;
pub const B_YELLOW_V = START ++ "103" ++ END;
pub const B_GREEN_V  = START ++ "102" ++ END;
pub const B_CYAN_V   = START ++ "106" ++ END;
pub const B_BLUE_V   = START ++ "104" ++ END;



