module gate_h(
    input  logic signed [15:0] ar, ai, br, bi,
    output logic signed [15:0] out0r, out0i,
    output logic signed [15:0] out1r, out1i
);
    import fixed_point_pkg::*;
    logic signed [16:0] sr0, si0, sr1, si1;

    always_comb begin
        sr0 = (ar + br);
        si0 = (ai + bi);
        sr1 = (ar - br);
        si1 = (ai - bi);

        out0r = (sr0 * INV_SQRT2) >>> 15;
        out0i = (si0 * INV_SQRT2) >>> 15;
        out1r = (sr1 * INV_SQRT2) >>> 15;
        out1i = (si1 * INV_SQRT2) >>> 15;
    end
endmodule
