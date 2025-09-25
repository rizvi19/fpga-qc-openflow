package fixed_point_pkg;
  // Q1.15 signed fixed point
  typedef logic signed [15:0] q15_t;

  // Constants
  localparam q15_t ONE       = 16'sh7FFF;   // ~0.9999
  localparam q15_t ZERO      = 16'sh0000;
  localparam q15_t INV_SQRT2 = 16'sh5A82;   // 0.7071
  localparam q15_t PI_BY_2   = 16'sh1922;   // ~1.5708 rad scaled
endpackage
