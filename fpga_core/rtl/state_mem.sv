
module state_mem #(
    parameter N_QUBITS = 4,
    parameter WIDTH = 16
)(
    input  logic clk,
    // Port A (read/write)
    input  logic we_a,
    input  logic [$clog2(1<<N_QUBITS)-1:0] addr_a,
    input  logic signed [WIDTH-1:0] din_a_r, din_a_i,
    output logic signed [WIDTH-1:0] dout_a_r, dout_a_i,
    // Port B (read/write)
    input  logic we_b,
    input  logic [$clog2(1<<N_QUBITS)-1:0] addr_b,
    input  logic signed [WIDTH-1:0] din_b_r, din_b_i,
    output logic signed [WIDTH-1:0] dout_b_r, dout_b_i
);
    localparam DEPTH = (1<<N_QUBITS);
    logic signed [WIDTH-1:0] mem_r[DEPTH] /* verilator public */;
    logic signed [WIDTH-1:0] mem_i[DEPTH] /* verilator public */;

    // Init to |0...0>
    integer ii;
    initial begin
        for (ii = 0; ii < DEPTH; ii++) begin
            mem_r[ii] = '0;
            mem_i[ii] = '0;
        end
        mem_r[0] = 16'sh7FFF;
        mem_i[0] = 16'sh0000;
    end

    // Write-first behavior
    always_ff @(posedge clk) begin
        if (we_a) begin
            mem_r[addr_a] <= din_a_r;
            mem_i[addr_a] <= din_a_i;
        end
        if (we_b) begin
            mem_r[addr_b] <= din_b_r;
            mem_i[addr_b] <= din_b_i;
        end
    end

    assign dout_a_r = mem_r[addr_a];
    assign dout_a_i = mem_i[addr_a];
    assign dout_b_r = mem_r[addr_b];
    assign dout_b_i = mem_i[addr_b];
endmodule
