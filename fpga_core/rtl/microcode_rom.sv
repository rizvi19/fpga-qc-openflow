module microcode_rom #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] data
);
    always_comb begin
        case(addr)
            // Example: opcode=H, target=0
            0: data = 32'h0100_0000; 
            default: data = 32'h0000_0000;
        endcase
    end
endmodule
