`timescale 1ns/1ps
// ECC-protected dual-port RAM with BIST. Structural top level.
module top #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter ECC_BITS   = 4,
    parameter CODE_WIDTH = DATA_WIDTH+ECC_BITS+1,
    parameter DEPTH      = (1<<ADDR_WIDTH)
)(
    input                    clk,
    input                    rst_n,
    input  [ADDR_WIDTH-1:0]  addr_a,
    input  [DATA_WIDTH-1:0]  din_a,
    input                    we_a,
    input                    re_a,
    output reg [DATA_WIDTH-1:0] dout_a,
    input  [ADDR_WIDTH-1:0]  addr_b,
    input  [DATA_WIDTH-1:0]  din_b,
    input                    we_b,
    input                    re_b,
    output reg [DATA_WIDTH-1:0] dout_b,
    input                    bist_start,
    output                   bist_busy,
    output                   bist_done,
    output                   bist_pass,
    output reg               collision,
    output reg               corrected_error,
    output reg               uncorrectable_error
);
    // ---------------- BIST ----------------
    wire [ADDR_WIDTH-1:0] bist_addr;
    wire [DATA_WIDTH-1:0] bist_wdata;
    wire                  bist_we;
    wire [DATA_WIDTH-1:0] dec_data_a, dec_data_b;
    wire                  dec_corr_a, dec_corr_b, dec_unc_a, dec_unc_b;

    bist_ctrl #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .DEPTH(DEPTH)) u_bist (
        .clk(clk), .rst_n(rst_n), .start(bist_start),
        .rd_data(dec_data_a), .rd_uncorr(dec_unc_a),
        .addr(bist_addr), .we(bist_we), .wdata(bist_wdata),
        .busy(bist_busy), .done(bist_done), .pass(bist_pass)
    );

    // Normal traffic is blocked while BIST runs (and on the cycle it starts)
    wire norm_en = !bist_busy && !bist_start;

    // BIST takes over port A
    wire [ADDR_WIDTH-1:0] mem_addr_a = bist_busy ? bist_addr  : addr_a;
    wire [DATA_WIDTH-1:0] mem_din_a  = bist_busy ? bist_wdata : din_a;
    wire                  mem_we_a   = bist_busy ? bist_we    : (norm_en && we_a);
    wire                  mem_we_b   = norm_en && we_b;

    // ---------------- Encode / store / decode ----------------
    wire [CODE_WIDTH-1:0] wcode_a, wcode_b, rcode_a, rcode_b;
    wire                  mem_collision;

    ecc_encoder #(.DATA_WIDTH(DATA_WIDTH), .ECC_BITS(ECC_BITS)) u_enc_a (.data(mem_din_a), .code(wcode_a));
    ecc_encoder #(.DATA_WIDTH(DATA_WIDTH), .ECC_BITS(ECC_BITS)) u_enc_b (.data(din_b),    .code(wcode_b));

    ecc_mem #(.ADDR_WIDTH(ADDR_WIDTH), .CODE_WIDTH(CODE_WIDTH), .DEPTH(DEPTH)) u_mem (
        .clk(clk),
        .addr_a(mem_addr_a), .wcode_a(wcode_a), .we_a(mem_we_a), .rcode_a(rcode_a),
        .addr_b(addr_b),     .wcode_b(wcode_b), .we_b(mem_we_b), .rcode_b(rcode_b),
        .collision(mem_collision)
    );

    ecc_decoder #(.DATA_WIDTH(DATA_WIDTH), .ECC_BITS(ECC_BITS)) u_dec_a (
        .code_in(rcode_a), .data_out(dec_data_a), .corrected(dec_corr_a), .uncorrectable(dec_unc_a));
    ecc_decoder #(.DATA_WIDTH(DATA_WIDTH), .ECC_BITS(ECC_BITS)) u_dec_b (
        .code_in(rcode_b), .data_out(dec_data_b), .corrected(dec_corr_b), .uncorrectable(dec_unc_b));

    // ---------------- Output registers / status ----------------
    wire rd_a = norm_en && re_a;
    wire rd_b = norm_en && re_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout_a <= {DATA_WIDTH{1'b0}};
            dout_b <= {DATA_WIDTH{1'b0}};
            collision <= 1'b0;
            corrected_error <= 1'b0;
            uncorrectable_error <= 1'b0;
        end else begin
            collision           <= norm_en && mem_collision;
            corrected_error     <= (rd_a && dec_corr_a) || (rd_b && dec_corr_b);
            uncorrectable_error <= (rd_a && dec_unc_a)  || (rd_b && dec_unc_b);
            if (rd_a) dout_a <= dec_data_a;
            if (rd_b) dout_b <= dec_data_b;
        end
    end
endmodule
