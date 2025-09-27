
package fixed_point_pkg;
  typedef logic signed [15:0] q15_t;
  /* verilator lint_off UNUSED */
  localparam q15_t ZERO      = 16'sh0000;
  localparam q15_t ONE       = 16'sh7FFF;   // ~0.99997
  localparam q15_t INV_SQRT2 = 16'sh5A82;   // 0.70710678
  /* verilator lint_on UNUSED */

  // Multiply q15 by q15 -> q15
  function automatic q15_t mul_q15(q15_t a, q15_t b);
    logic signed [31:0] m; m = a * b;
    return q15_t'(m >>> 15);
  endfunction
endpackage
