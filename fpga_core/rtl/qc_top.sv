
module qc_top #(
    parameter N_QUBITS = 4
)(
    input  logic clk,
    input  logic start,
    input  logic [1:0] prog_id,
    output logic done,
    output logic [31:0] cycle_count
);
    scheduler #(.N_QUBITS(N_QUBITS)) u_sched (
        .clk(clk),
        .start(start),
        .prog_id(prog_id),
        .done(done),
        .cycle_count(cycle_count)
    );
endmodule
