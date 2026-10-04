`timescale 1ns/1ps
// SECDED decoder: corrects 1-bit errors, flags 2-bit errors. Purely combinational.
module ecc_decoder #(
    parameter DATA_WIDTH = 8,
    parameter ECC_BITS   = 4,
    parameter CODE_WIDTH = DATA_WIDTH + ECC_BITS + 1
)(
    input      [CODE_WIDTH-1:0] code_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg                  corrected,
    output reg                  uncorrectable
);
    reg     [CODE_WIDTH-1:0] code;
    reg     parity;
    integer syndrome, pos, p, data_index;

    always @(*) begin
        code     = code_in;
        syndrome = 0;

        for (p = 0; p < ECC_BITS; p = p + 1) begin
            parity = 1'b0;
            for (pos = 1; pos <= DATA_WIDTH+ECC_BITS; pos = pos + 1)
                if ((pos & (1<<p)) != 0)
                    parity = parity ^ code[pos-1];
            if (parity) syndrome = syndrome | (1<<p);
        end

        parity = code[CODE_WIDTH-1];
        for (pos = 0; pos < DATA_WIDTH+ECC_BITS; pos = pos + 1)
            parity = parity ^ code[pos];

        corrected     = 1'b0;
        uncorrectable = 1'b0;

        if (parity && syndrome != 0) begin
            if (syndrome <= DATA_WIDTH+ECC_BITS) begin
                code[syndrome-1] = ~code[syndrome-1];
                corrected = 1'b1;
            end else
                uncorrectable = 1'b1;
        end
        else if (parity && syndrome == 0) begin
            code[CODE_WIDTH-1] = ~code[CODE_WIDTH-1];   // overall-parity bit itself flipped
            corrected = 1'b1;
        end
        else if (!parity && syndrome != 0)
            uncorrectable = 1'b1;

        data_out   = {DATA_WIDTH{1'b0}};
        data_index = 0;
        for (pos = 1; pos <= DATA_WIDTH+ECC_BITS; pos = pos + 1)
            if ((pos & (pos-1)) != 0) begin
                data_out[data_index] = code[pos-1];
                data_index = data_index + 1;
            end
    end
endmodule
