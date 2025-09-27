
module scheduler #(
    parameter N_QUBITS = 4
)(
    input  logic clk,
    input  logic start,
    input  logic [2:0] prog_id,
    output logic done,
    output logic [31:0] cycle_count
);
    // Import fixed-point typedefs
    // (not strictly needed here but kept for consistency)
    // import fixed_point_pkg::*;

    // Opcodes
    /* verilator lint_off UNUSED */
    localparam [3:0] OP_NOP    = 4'd0;
    /* verilator lint_on UNUSED */
    localparam [3:0] OP_H      = 4'd1;
    localparam [3:0] OP_X      = 4'd2;
    localparam [3:0] OP_Z      = 4'd3;
    localparam [3:0] OP_CNOT   = 4'd4;
    localparam [3:0] OP_CPHASE = 4'd5;
    localparam [3:0] OP_SWAP   = 4'd6;
    localparam [3:0] OP_MASKPHASE = 4'd7;
    localparam [3:0] OP_END    = 4'd15;

    // Dimensions
    localparam int DIM = (1<<N_QUBITS);
    localparam int AW  = $clog2(DIM);

    // Memories and gates
    logic we_a, we_b;
    logic [AW-1:0] addr_a, addr_b;
    logic signed [15:0] din_a_r, din_a_i, dout_a_r, dout_a_i;
    logic signed [15:0] din_b_r, din_b_i, dout_b_r, dout_b_i;

    state_mem #(.N_QUBITS(N_QUBITS)) u_mem (
        .clk(clk),
        .we_a(we_a), .addr_a(addr_a), .din_a_r(din_a_r), .din_a_i(din_a_i), .dout_a_r(dout_a_r), .dout_a_i(dout_a_i),
        .we_b(we_b), .addr_b(addr_b), .din_b_r(din_b_r), .din_b_i(din_b_i), .dout_b_r(dout_b_r), .dout_b_i(dout_b_i)
    );

    // Gates
    logic signed [15:0] h0r,h0i,h1r,h1i;
    gate_h u_h(.ar(dout_a_r), .ai(dout_a_i), .br(dout_b_r), .bi(dout_b_i),
               .out0r(h0r), .out0i(h0i), .out1r(h1r), .out1i(h1i));

    logic signed [15:0] xz0r,xz0i,xz1r,xz1i;
    logic apply_x, apply_z;
    gate_xz u_xz(.apply_x(apply_x), .apply_z(apply_z),
                 .in0r(dout_a_r), .in0i(dout_a_i), .in1r(dout_b_r), .in1i(dout_b_i),
                 .out0r(xz0r), .out0i(xz0i), .out1r(xz1r), .out1i(xz1i));

    logic ctrl_bit;
    logic signed [15:0] cnot0r,cnot0i,cnot1r,cnot1i;
    gate_cnot u_cnot(.ctrl_bit(ctrl_bit),
                     .ar(dout_a_r), .ai(dout_a_i), .br(dout_b_r), .bi(dout_b_i),
                     .out0r(cnot0r), .out0i(cnot0i), .out1r(cnot1r), .out1i(cnot1i));

    // Phase
    logic signed [15:0] cos_t, sin_t, ph_out_r, ph_out_i;
    logic [7:0] angle_id;
    phase_lut u_pl(.angle_id(angle_id), .cos_t(cos_t), .sin_t(sin_t));
    gate_phase u_gp(.inr(dout_a_r), .ini(dout_a_i), .cos_theta(cos_t), .sin_theta(sin_t),
                    .outr(ph_out_r), .outi(ph_out_i));

    // Microcode
    logic [7:0]  mc_addr;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] mc_data;
    /* verilator lint_on UNUSEDSIGNAL */
    microcode_rom u_rom(.prog_id(prog_id), .addr(mc_addr), .data(mc_data));

    // Decode
    logic [3:0] opcode;
    logic [3:0] target, control_q2;
    assign opcode     = mc_data[31:28];
    assign target     = mc_data[27:24];
    assign control_q2 = mc_data[23:20];
    assign angle_id   = mc_data[11:4];

    // Iteration
    logic [AW-1:0] idx;
    logic pair_stage; // 0: compute, 1: write

    typedef enum logic [2:0] {S_IDLE, S_FETCH, S_EXEC_PAIR, S_EXEC_DIAG, S_EXEC_SWAP, S_NEXT, S_FIN} state_e;
    state_e st;

    localparam logic [AW-1:0] LAST_IDX = {AW{1'b1}};
    localparam logic [AW-1:0] IDX_ONE  = {{(AW-1){1'b0}}, 1'b1};

    logic [31:0] cnt;
    assign cycle_count = cnt;

    // Next-state signals
    logic we_a_next, we_b_next;
    logic [AW-1:0] addr_a_next, addr_b_next;
    logic signed [15:0] din_a_r_next, din_a_i_next, din_b_r_next, din_b_i_next;
    logic apply_x_next, apply_z_next;
    logic ctrl_bit_next;
    state_e st_next;
    logic [7:0] mc_addr_next;
    logic [31:0] cnt_next;
    logic [AW-1:0] idx_next;
    logic pair_stage_next;
    logic done_next;

    // Helpers (rename 'bit' to 'b' to avoid keyword clash)
    function automatic logic is_bit_set(input logic [AW-1:0] x, input logic [3:0] b);
        int unsigned idx_cast;
        begin
            idx_cast = int'(b);
            if (idx_cast < AW) begin
                return x[idx_cast];
            end else begin
                return 1'b0;
            end
        end
    endfunction

    function automatic logic [AW-1:0] partner(input logic [AW-1:0] x, input logic [3:0] b);
        logic [AW-1:0] mask;
        int unsigned idx_cast;
        begin
            mask = '0;
            idx_cast  = int'(b);
            if (idx_cast < AW) begin
                mask[idx_cast] = 1'b1;
            end
            return x ^ mask;
        end
    endfunction

    function automatic logic [AW-1:0] swap_bits(input logic [AW-1:0] x, input logic [3:0] b1, input logic [3:0] b2);
        logic [AW-1:0] y;
        logic [AW-1:0] mask;
        logic v1, v2;
        int unsigned idx1_cast, idx2_cast;
        begin
            y = x;
            mask = '0;
            v1 = 1'b0;
            v2 = 1'b0;
            idx1_cast = int'(b1);
            idx2_cast = int'(b2);
            if (idx1_cast < AW) begin
                v1 = x[idx1_cast];
                mask[idx1_cast] = 1'b1;
            end
            if (idx2_cast < AW) begin
                v2 = x[idx2_cast];
                mask[idx2_cast] = 1'b1;
            end
            if (v1 != v2) begin
                y = x ^ mask;
            end
            return y;
        end
    endfunction

    // Next-state logic
    always_comb begin
        // Hold previous values by default
        st_next         = st;
        done_next       = done;
        mc_addr_next    = mc_addr;
        cnt_next        = cnt;
        idx_next        = idx;
        pair_stage_next = pair_stage;

        // Default outputs for this cycle
        we_a_next       = 1'b0;
        we_b_next       = 1'b0;
        din_a_r_next    = '0;
        din_a_i_next    = '0;
        din_b_r_next    = '0;
        din_b_i_next    = '0;
        addr_a_next     = idx;
        addr_b_next     = idx;
        apply_x_next    = 1'b0;
        apply_z_next    = 1'b0;
        ctrl_bit_next   = 1'b0;

        case (st)
            S_IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    st_next         = S_FETCH;
                    mc_addr_next    = 8'd0;
                    cnt_next        = 32'd0;
                    idx_next        = '0;
                    pair_stage_next = 1'b0;
                end
            end

            S_FETCH: begin
                if (opcode == OP_END) begin
                    st_next = S_FIN;
                end else begin
                    idx_next        = '0;
                    pair_stage_next = 1'b0;
                    if (opcode == OP_H || opcode == OP_X || opcode == OP_CNOT) begin
                        st_next = S_EXEC_PAIR;
                    end else if (opcode == OP_Z || opcode == OP_CPHASE || opcode == OP_MASKPHASE) begin
                        st_next = S_EXEC_DIAG;
                    end else if (opcode == OP_SWAP) begin
                        st_next = S_EXEC_SWAP;
                    end else begin
                        st_next = S_NEXT; // NOP
                    end
                end
            end

            S_EXEC_PAIR: begin
                logic [AW-1:0] j;
                j = partner(idx, target);
                addr_a_next = idx;
                addr_b_next = j;

                if (!is_bit_set(idx, target)) begin
                    if (!pair_stage) begin
                        case (opcode)
                            OP_H: begin
                                pair_stage_next = 1'b1;
                            end
                            OP_X: begin
                                apply_x_next    = 1'b1;
                                pair_stage_next = 1'b1;
                            end
                            OP_CNOT: begin
                                ctrl_bit_next   = is_bit_set(idx, control_q2);
                                pair_stage_next = 1'b1;
                            end
                            default: pair_stage_next = 1'b1;
                        endcase
                    end else begin
                        case (opcode)
                            OP_H: begin
                                din_a_r_next = h0r;  din_a_i_next = h0i;
                                din_b_r_next = h1r;  din_b_i_next = h1i;
                            end
                            OP_X: begin
                                din_a_r_next = xz0r; din_a_i_next = xz0i;
                                din_b_r_next = xz1r; din_b_i_next = xz1i;
                            end
                            OP_CNOT: begin
                                din_a_r_next = cnot0r; din_a_i_next = cnot0i;
                                din_b_r_next = cnot1r; din_b_i_next = cnot1i;
                            end
                            default: begin
                                // No write-back for unsupported opcodes in pair stage
                            end
                        endcase
                        we_a_next       = 1'b1;
                        we_b_next       = 1'b1;
                        pair_stage_next = 1'b0;
                        idx_next        = idx + IDX_ONE;
                    end
                end else begin
                    idx_next = idx + IDX_ONE;
                end

                if ((idx == LAST_IDX) && (pair_stage == 1'b0)) begin
                    st_next = S_NEXT;
                end

                cnt_next = cnt + 32'd1;
            end

            S_EXEC_DIAG: begin
                addr_a_next = idx;
                if (opcode == OP_Z) begin
                    if (is_bit_set(idx, target)) begin
                        din_a_r_next = -dout_a_r;
                        din_a_i_next = -dout_a_i;
                        we_a_next    = 1'b1;
                    end
                end else if (opcode == OP_CPHASE) begin
                    if (is_bit_set(idx, target) && is_bit_set(idx, control_q2)) begin
                        din_a_r_next = ph_out_r;
                        din_a_i_next = ph_out_i;
                        we_a_next    = 1'b1;
                    end
                end else if (opcode == OP_MASKPHASE) begin
                    // target encodes mask bits [3:0], control_q2 encodes match bits [3:0]
                    logic [AW-1:0] mask_bits;
                    logic [AW-1:0] match_bits;
                    mask_bits  = '0;
                    match_bits = '0;
                    for (int unsigned b = 0; b < AW && b < 4; ++b) begin
                        mask_bits[b]  = target[b];
                        match_bits[b] = control_q2[b];
                    end
                    if ( (idx & mask_bits) == match_bits ) begin
                        if (angle_id == 8'd1) begin
                            din_a_r_next = -dout_a_r;
                            din_a_i_next = -dout_a_i;
                        end else begin
                            din_a_r_next = ph_out_r;
                            din_a_i_next = ph_out_i;
                        end
                        we_a_next    = 1'b1;
                    end
                end

                if (idx == LAST_IDX) begin
                    st_next = S_NEXT;
                end else begin
                    idx_next = idx + IDX_ONE;
                end
                cnt_next = cnt + 32'd1;
            end

            S_EXEC_SWAP: begin
                logic [AW-1:0] p;
                p = swap_bits(idx, target, control_q2);
                addr_a_next = idx;
                addr_b_next = p;
                if (idx < p) begin
                    din_a_r_next = dout_b_r;
                    din_a_i_next = dout_b_i;
                    din_b_r_next = dout_a_r;
                    din_b_i_next = dout_a_i;
                    we_a_next    = 1'b1;
                    we_b_next    = 1'b1;
                end

                if (idx == LAST_IDX) begin
                    st_next = S_NEXT;
                end else begin
                    idx_next = idx + IDX_ONE;
                end
                cnt_next = cnt + 32'd1;
            end

            S_NEXT: begin
                mc_addr_next = mc_addr + 8'd1;
                st_next      = S_FETCH;
                cnt_next     = cnt + 32'd1;
            end

            S_FIN: begin
                done_next = 1'b1;
                cnt_next  = cnt + 32'd1;
            end

            default: st_next = S_IDLE;
        endcase
    end

    // State registers
    always_ff @(posedge clk) begin
        st         <= st_next;
        done       <= done_next;
        mc_addr    <= mc_addr_next;
        cnt        <= cnt_next;
        idx        <= idx_next;
        pair_stage <= pair_stage_next;

        we_a       <= we_a_next;
        we_b       <= we_b_next;
        addr_a     <= addr_a_next;
        addr_b     <= addr_b_next;
        din_a_r    <= din_a_r_next;
        din_a_i    <= din_a_i_next;
        din_b_r    <= din_b_r_next;
        din_b_i    <= din_b_i_next;
        apply_x    <= apply_x_next;
        apply_z    <= apply_z_next;
        ctrl_bit   <= ctrl_bit_next;
    end

    initial begin
        st         = S_IDLE;
        done       = 1'b0;
        cnt        = 32'd0;
        mc_addr    = 8'd0;
        idx        = '0;
        pair_stage = 1'b0;
        we_a       = 1'b0;
        we_b       = 1'b0;
        addr_a     = '0;
        addr_b     = '0;
        din_a_r    = '0;
        din_a_i    = '0;
        din_b_r    = '0;
        din_b_i    = '0;
        apply_x    = 1'b0;
        apply_z    = 1'b0;
        ctrl_bit   = 1'b0;
    end
endmodule
