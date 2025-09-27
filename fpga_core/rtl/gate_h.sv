
module gate_h(
    input  logic signed [15:0] ar, ai, br, bi,
    output logic signed [15:0] out0r, out0i,
    output logic signed [15:0] out1r, out1i
);
    // (a+b)/sqrt(2), (a-b)/sqrt(2)
    logic signed [16:0] sr0, si0, sr1, si1;
    logic signed [31:0] m0r, m0i, m1r, m1i;
    localparam signed [15:0] INV_SQRT2 = 16'sh5A82;

    always_comb begin
        sr0 = ar + br;  si0 = ai + bi;
        sr1 = ar - br;  si1 = ai - bi;

        m0r = sr0 * INV_SQRT2; m0i = si0 * INV_SQRT2;
        m1r = sr1 * INV_SQRT2; m1i = si1 * INV_SQRT2;

        out0r = fixed_point_pkg::q15_t'($signed(m0r) >>> 15); out0i = fixed_point_pkg::q15_t'($signed(m0i) >>> 15);
        out1r = fixed_point_pkg::q15_t'($signed(m1r) >>> 15); out1i = fixed_point_pkg::q15_t'($signed(m1i) >>> 15);
    end
endmodule
