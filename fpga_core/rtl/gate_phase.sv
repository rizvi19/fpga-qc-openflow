module gate_phase(
    input  logic signed [15:0] inr, ini,
    input  logic signed [15:0] cos_theta,
    input  logic signed [15:0] sin_theta,
    output logic signed [15:0] outr, outi
);
    // Multiply by exp(i*theta) = cos + i sin
    logic signed [31:0] m1, m2, m3, m4;

    always_comb begin
        m1 = inr * cos_theta;
        m2 = ini * sin_theta;
        m3 = inr * sin_theta;
        m4 = ini * cos_theta;

        outr = (m1 - m2) >>> 15;
        outi = (m3 + m4) >>> 15;
    end
endmodule
