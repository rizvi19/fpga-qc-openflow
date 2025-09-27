module microcode_rom(
    input  logic [1:0]  prog_id,    // 0:QFT2, 1:QFT4, 2:GROVER2, 3:BELL2
    input  logic [7:0]  addr,
    output logic [31:0] data
);
    // Encoding: data[31:28]=opcode, data[27:24]=target qubit, data[23:20]=aux/control qubit,
    // data[19:12]=imm[15:8], data[11:4]=imm[7:0], data[3:0]=0
    // Opcodes: 0 NOP, 1 H, 2 X, 3 Z, 4 CNOT, 5 CPHASE, 6 SWAP, 15 END

    function automatic [31:0] pack_i16(input [3:0] op, input [3:0] qa, input [3:0] qb, input [15:0] imm16);
        return {op, qa, qb, imm16[15:8], imm16[7:0], 4'h0};
    endfunction

    function automatic [31:0] pack_pair8(input [3:0] op, input [3:0] qa, input [3:0] qb, input [7:0] p0, input [7:0] p1);
        return {op, qa, qb, p0, p1, 4'h0};
    endfunction

    always_comb begin
        data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0); // default END
        unique case (prog_id)
            2'd0: begin // QFT2
                unique case (addr)
                    8'd0: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);                    // H t=0
                    8'd1: data = pack_pair8(4'h5, 4'd0, 4'd1, 8'd0, 8'd2);              // CPHASE c=1->t=0, pi/2
                    8'd2: data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);                    // H t=1
                    8'd3: data = pack_i16(4'h6, 4'd0, 4'd1, 16'd0);                    // SWAP 0<->1 (bit-reversal)
                    8'd4: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);                    // END
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            2'd1: begin // QFT4
                unique case (addr)
                    8'd0:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);                   // H0
                    8'd1:  data = pack_pair8(4'h5, 4'd0, 4'd1, 8'd0, 8'd2);             // c1->t0 pi/2
                    8'd2:  data = pack_pair8(4'h5, 4'd0, 4'd2, 8'd0, 8'd3);             // c2->t0 pi/4
                    8'd3:  data = pack_pair8(4'h5, 4'd0, 4'd3, 8'd0, 8'd4);             // c3->t0 pi/8
                    8'd4:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);                   // H1
                    8'd5:  data = pack_pair8(4'h5, 4'd1, 4'd2, 8'd0, 8'd2);             // c2->t1 pi/2
                    8'd6:  data = pack_pair8(4'h5, 4'd1, 4'd3, 8'd0, 8'd3);             // c3->t1 pi/4
                    8'd7:  data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);                   // H2
                    8'd8:  data = pack_pair8(4'h5, 4'd2, 4'd3, 8'd0, 8'd2);             // c3->t2 pi/2
                    8'd9:  data = pack_i16(4'h1, 4'd3, 4'd0, 16'd0);                   // H3
                    8'd10: data = pack_i16(4'h6, 4'd0, 4'd3, 16'd0);                   // SWAP 0<->3
                    8'd11: data = pack_i16(4'h6, 4'd1, 4'd2, 16'd0);                   // SWAP 1<->2
                    8'd12: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            2'd2: begin // Grover2
                unique case (addr)
                    // Init |++>
                    8'd0:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);                  // H0
                    8'd1:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);                  // H1
                    // Oracle: CZ(pi) c=0->t=1
                    8'd2:  data = pack_pair8(4'h5, 4'd1, 4'd0, 8'd0, 8'd1);
                    // Diffusion: H H X X CZ X X H H
                    8'd3:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd4:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd5:  data = pack_i16(4'h2, 4'd0, 4'd0, 16'd0);
                    8'd6:  data = pack_i16(4'h2, 4'd1, 4'd0, 16'd0);
                    8'd7:  data = pack_pair8(4'h5, 4'd1, 4'd0, 8'd0, 8'd1);             // CZ pi
                    8'd8:  data = pack_i16(4'h2, 4'd0, 4'd0, 16'd0);
                    8'd9:  data = pack_i16(4'h2, 4'd1, 4'd0, 16'd0);
                    8'd10: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd11: data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd12: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            2'd3: begin // Bell pair on 2 qubits
                unique case (addr)
                    8'd0: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0); // H on qubit 0
                    8'd1: data = pack_i16(4'h4, 4'd1, 4'd0, 16'd0); // CNOT control 0 -> target 1
                    8'd2: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
        endcase
    end
endmodule
