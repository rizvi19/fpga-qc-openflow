
// Maps angle_id -> cos(theta), sin(theta) in q15.
// Supported IDs:
// 1: pi
// 2: pi/2
// 3: pi/4
// 4: pi/8
module phase_lut(
    input  logic [7:0] angle_id,
    output logic signed [15:0] cos_t,
    output logic signed [15:0] sin_t
);
    always_comb begin
        unique case (angle_id)
            8'd1: begin // pi
                cos_t = 16'sh8000; // -1.0
                sin_t = 16'sh0000;
            end
            8'd2: begin // pi/2
                cos_t = 16'sh0000;
                sin_t = 16'sh7FFF; // +1.0
            end
            8'd3: begin // pi/4
                cos_t = 16'sh5A82; // ~0.7071
                sin_t = 16'sh5A82;
            end
            8'd4: begin // pi/8
                cos_t = 16'sh7641; // cos(pi/8) ~0.9239
                sin_t = 16'sh30FB; // sin(pi/8) ~0.3827
            end
            default: begin
                cos_t = 16'sh7FFF; // 1.0
                sin_t = 16'sh0000; // 0.0
            end
        endcase
    end
endmodule
