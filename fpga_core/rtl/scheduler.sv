module scheduler(
    input  logic clk,
    input  logic start,
    output logic done
);
    always_ff @(posedge clk) begin
        if (start) done <= 1'b1;
        else done <= 1'b0;
    end
endmodule
