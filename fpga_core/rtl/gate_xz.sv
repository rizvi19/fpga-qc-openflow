module gate_xz(
    input  logic apply_x,
    input  logic apply_z,
    input  logic signed [15:0] in0r, in0i, in1r, in1i,
    output logic signed [15:0] out0r, out0i, out1r, out1i
);
    always_comb begin
        out0r = in0r; out0i = in0i;
        out1r = in1r; out1i = in1i;

        if (apply_x) begin
            out0r = in1r; out0i = in1i;
            out1r = in0r; out1i = in0i;
        end
        if (apply_z) begin
            out1r = -out1r;
            out1i = -out1i;
        end
    end
endmodule
