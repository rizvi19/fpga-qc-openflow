module state_mem #(
    parameter N_QUBITS = 4,
    parameter WIDTH = 16
)(
    input  logic clk,
    input  logic we,
    input  logic [$clog2(1<<N_QUBITS)-1:0] addr_a,
    input  logic [$clog2(1<<N_QUBITS)-1:0] addr_b,
    input  logic signed [WIDTH-1:0] din_a_r, din_a_i,
    output logic signed [WIDTH-1:0] dout_a_r, dout_a_i,
    output logic signed [WIDTH-1:0] dout_b_r, dout_b_i
);
    localparam DEPTH = (1<<N_QUBITS);
    logic signed [WIDTH-1:0] mem_r[DEPTH];
    logic signed [WIDTH-1:0] mem_i[DEPTH];

    always_ff @(posedge clk) begin
        if (we) begin
            mem_r[addr_a] <= din_a_r;
            mem_i[addr_a] <= din_a_i;
        end
    end

    assign dout_a_r = mem_r[addr_a];
    assign dout_a_i = mem_i[addr_a];
    assign dout_b_r = mem_r[addr_b];
    assign dout_b_i = mem_i[addr_b];
endmodule
