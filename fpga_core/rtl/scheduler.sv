
module scheduler #(
    parameter N_QUBITS = 4
)(
    input  logic clk,
    input  logic start,
    output logic done,
    output logic [31:0] cycle_count
);
    typedef enum logic [1:0] {IDLE, RUN, FIN} state_e;
    state_e st;
    logic [31:0] cnt;

    assign cycle_count = cnt;

    always_ff @(posedge clk) begin
        case (st)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    st  <= RUN;
                    cnt <= 32'd0;
                end
            end
            RUN: begin
                cnt <= cnt + 1;
                if (cnt == 32'd40) begin // placeholder "work"
                    st   <= FIN;
                    done <= 1'b1;
                end
            end
            FIN: begin
                // hold done high
                cnt <= cnt + 1;
            end
            default: st <= IDLE;
        endcase
    end

    // Resetless init
    initial begin
        st   = IDLE;
        cnt  = 32'd0;
        done = 1'b0;
    end
endmodule
