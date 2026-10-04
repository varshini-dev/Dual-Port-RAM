`timescale 1ns/1ps
// March-style BIST: W0 ; R0,W1 ; R1,W0 ; R0   (reads go through the ECC decoder)
module bist_ctrl #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter DEPTH      = (1<<ADDR_WIDTH)
)(
    input                    clk,
    input                    rst_n,
    input                    start,
    // read-back from the decoder at bist_addr (combinational, same cycle)
    input  [DATA_WIDTH-1:0]  rd_data,
    input                    rd_uncorr,
    // drives memory port A while busy
    output [ADDR_WIDTH-1:0]  addr,
    output                   we,
    output [DATA_WIDTH-1:0]  wdata,
    output reg               busy,
    output reg               done,
    output reg               pass
);
    localparam S_IDLE=3'b000, S_WRITE0=3'b001, S_R0W1=3'b010,
               S_R1W0=3'b011, S_READ0=3'b100;

    reg [2:0]            state;
    reg [ADDR_WIDTH-1:0] cnt;
    reg                  err;

    wire last     = (cnt == DEPTH-1);
    wire exp_ones = (state == S_R1W0);
    wire check    = (state == S_R0W1) || (state == S_R1W0) || (state == S_READ0);
    wire mismatch = check && (rd_uncorr || (rd_data != (exp_ones ? {DATA_WIDTH{1'b1}}
                                                                 : {DATA_WIDTH{1'b0}})));

    assign addr  = cnt;
    assign we    = busy && (state == S_WRITE0 || state == S_R0W1 || state == S_R1W0);
    assign wdata = (state == S_R0W1) ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0; done <= 1'b0; pass <= 1'b0;
            state <= S_IDLE; cnt <= {ADDR_WIDTH{1'b0}}; err <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy <= 1'b1; pass <= 1'b1; err <= 1'b0;
                cnt  <= {ADDR_WIDTH{1'b0}};
                state <= S_WRITE0;
            end
            else if (busy) begin
                if (mismatch) err <= 1'b1;

                case (state)
                    S_WRITE0, S_R0W1, S_R1W0, S_READ0: begin
                        if (last) begin
                            cnt <= {ADDR_WIDTH{1'b0}};
                            case (state)
                                S_WRITE0: state <= S_R0W1;
                                S_R0W1:   state <= S_R1W0;
                                S_R1W0:   state <= S_READ0;
                                default: begin            // S_READ0 -> finish
                                    busy  <= 1'b0;
                                    done  <= 1'b1;
                                    state <= S_IDLE;
                                    pass  <= !(err || mismatch);
                                end
                            endcase
                        end else
                            cnt <= cnt + 1'b1;
                    end
                    default: begin
                        state <= S_IDLE; busy <= 1'b0; done <= 1'b0; pass <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule
