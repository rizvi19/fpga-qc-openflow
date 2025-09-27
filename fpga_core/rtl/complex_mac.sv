
module complex_mac(
    input  logic signed [15:0] ar, ai, br, bi,
    output logic signed [15:0] pr, pi
);
    logic signed [31:0] m1, m2, m3, m4;
    always_comb begin
        m1 = ar * br;
        m2 = ai * bi;
        m3 = ar * bi;
        m4 = ai * br;
        pr = (m1 - m2) >>> 15;
        pi = (m3 + m4) >>> 15;
    end
endmodule
