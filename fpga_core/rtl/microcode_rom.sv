module microcode_rom(
    input  logic [2:0]  prog_id,    // 0:QFT2, 1:QFT3, 2:QFT4, 3:GROVER2, 4:GROVER3, 5:GROVER4, 6:BELL2
    input  logic [7:0]  addr,
    output logic [31:0] data
);
    // Encoding: data[31:28]=opcode, data[27:24]=target qubit, data[23:20]=aux/control qubit,
    // data[19:12]=imm[15:8], data[11:4]=imm[7:0], data[3:0]=0
    // Opcodes: 0 NOP, 1 H, 2 X, 3 Z, 4 CNOT, 5 CPHASE, 6 SWAP, 7 MASKPHASE, 15 END

    function automatic [31:0] pack_i16(input [3:0] op, input [3:0] qa, input [3:0] qb, input [15:0] imm16);
        return {op, qa, qb, imm16[15:8], imm16[7:0], 4'h0};
    endfunction

    function automatic [31:0] pack_pair8(input [3:0] op, input [3:0] qa, input [3:0] qb, input [7:0] p0, input [7:0] p1);
        return {op, qa, qb, p0, p1, 4'h0};
    endfunction

    // Pack mask/value for OP_MASKPHASE (op=7): qa=mask[3:0], qb=value[3:0], p1=angle_id
    function automatic [31:0] pack_mask(input [3:0] mask, input [3:0] value, input [7:0] ang);
        return {4'h7, mask, value, 8'd0, ang, 4'h0};
    endfunction

    always_comb begin
        data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0); // default END
        unique case (prog_id)
            3'd0: begin // QFT2
                unique case (addr)
                    8'd0: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);                    // H t=0
                    8'd1: data = pack_pair8(4'h5, 4'd0, 4'd1, 8'd0, 8'd2);              // CPHASE c=1->t=0, pi/2
                    8'd2: data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);                    // H t=1
                    8'd3: data = pack_i16(4'h6, 4'd0, 4'd1, 16'd0);                    // SWAP 0<->1 (bit-reversal)
                    8'd4: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);                    // END
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            3'd1: begin // QFT3
                unique case (addr)
                    8'd0: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);                    // H0
                    8'd1: data = pack_pair8(4'h5, 4'd0, 4'd1, 8'd0, 8'd2);              // c1->t0 pi/2
                    8'd2: data = pack_pair8(4'h5, 4'd0, 4'd2, 8'd0, 8'd3);              // c2->t0 pi/4
                    8'd3: data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);                    // H1
                    8'd4: data = pack_pair8(4'h5, 4'd1, 4'd2, 8'd0, 8'd2);              // c2->t1 pi/2
                    8'd5: data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);                    // H2
                    8'd6: data = pack_i16(4'h6, 4'd0, 4'd2, 16'd0);                    // SWAP 0<->2 (bit reversal)
                    8'd7: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            3'd2: begin // QFT4
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
            3'd3: begin // Grover2
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
            3'd4: begin // Grover3 (n=3): 1 iteration, marked=|111>, qubit0=LSB
                unique case (addr)
                    // Prepare: H on all (q0,q1,q2)
                    8'd0:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0); // H0
                    8'd1:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0); // H1
                    8'd2:  data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0); // H2
                    // Oracle: flip |111>
                    8'd3:  data = pack_mask(4'h7, 4'h7, 8'd1);       // π
                    // Diffusion: H H H, X X X, flip |000>, X X X, H H H
                    8'd4:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd5:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd6:  data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);
                    8'd7:  data = pack_i16(4'h2, 4'd0, 4'd0, 16'd0);
                    8'd8:  data = pack_i16(4'h2, 4'd1, 4'd0, 16'd0);
                    8'd9:  data = pack_i16(4'h2, 4'd2, 4'd0, 16'd0);
                    8'd10: data = pack_mask(4'h7, 4'h0, 8'd1);       // π on |000>
                    8'd11: data = pack_i16(4'h2, 4'd0, 4'd0, 16'd0);
                    8'd12: data = pack_i16(4'h2, 4'd1, 4'd0, 16'd0);
                    8'd13: data = pack_i16(4'h2, 4'd2, 4'd0, 16'd0);
                    8'd14: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd15: data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd16: data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);
                    8'd17: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0); // END
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            3'd5: begin // Grover4 (n=4): 1 iteration, marked=|1111>, qubit0=LSB
                unique case (addr)
                    // Prepare: H on all (q0..q3)
                    8'd0:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd1:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd2:  data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);
                    8'd3:  data = pack_i16(4'h1, 4'd3, 4'd0, 16'd0);
                    // Oracle: flip |1111>
                    8'd4:  data = pack_mask(4'hF, 4'hF, 8'd1);       // π
                    // Diffusion: H*4, X*4, flip |0000>, X*4, H*4
                    8'd5:  data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd6:  data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd7:  data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);
                    8'd8:  data = pack_i16(4'h1, 4'd3, 4'd0, 16'd0);
                    8'd9:  data = pack_i16(4'h2, 4'd0, 4'd0, 16'd0);
                    8'd10: data = pack_i16(4'h2, 4'd1, 4'd0, 16'd0);
                    8'd11: data = pack_i16(4'h2, 4'd2, 4'd0, 16'd0);
                    8'd12: data = pack_i16(4'h2, 4'd3, 4'd0, 16'd0);
                    8'd13: data = pack_mask(4'hF, 4'h0, 8'd1);       // π on |0000>
                    8'd14: data = pack_i16(4'h2, 4'd0, 4'd0, 16'd0);
                    8'd15: data = pack_i16(4'h2, 4'd1, 4'd0, 16'd0);
                    8'd16: data = pack_i16(4'h2, 4'd2, 4'd0, 16'd0);
                    8'd17: data = pack_i16(4'h2, 4'd3, 4'd0, 16'd0);
                    8'd18: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0);
                    8'd19: data = pack_i16(4'h1, 4'd1, 4'd0, 16'd0);
                    8'd20: data = pack_i16(4'h1, 4'd2, 4'd0, 16'd0);
                    8'd21: data = pack_i16(4'h1, 4'd3, 4'd0, 16'd0);
                    8'd22: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0); // END
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            3'd6: begin // Bell pair on 2 qubits
                unique case (addr)
                    8'd0: data = pack_i16(4'h1, 4'd0, 4'd0, 16'd0); // H on qubit 0
                    8'd1: data = pack_i16(4'h4, 4'd1, 4'd0, 16'd0); // CNOT control 0 -> target 1
                    8'd2: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                    default: data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
                endcase
            end
            default: begin
                data = pack_i16(4'hF, 4'd0, 4'd0, 16'd0);
            end
        endcase
    end
endmodule
