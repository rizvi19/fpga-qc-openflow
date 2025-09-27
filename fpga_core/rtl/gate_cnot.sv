
module gate_cnot(
    input  logic ctrl_bit, // 1 to swap target pair, else passthrough
    input  logic signed [15:0] ar, ai, br, bi,
    output logic signed [15:0] out0r, out0i, out1r, out1i
);
    always_comb begin
        if (ctrl_bit) begin // swap
            out0r = br; out0i = bi;
            out1r = ar; out1i = ai;
        end else begin
            out0r = ar; out0i = ai;
            out1r = br; out1i = bi;
        end
    end
endmodule
