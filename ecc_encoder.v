`timescale 1ns/1ps
// SECDED encoder: Hamming(data+parity) + overall parity bit. Purely combinational.
module ecc_encoder #(
    parameter DATA_WIDTH = 8,
    parameter ECC_BITS   = 4,
    parameter CODE_WIDTH = DATA_WIDTH + ECC_BITS + 1
)(
    input      [DATA_WIDTH-1:0] data,
    output reg [CODE_WIDTH-1:0] code
);
    reg     parity;
    integer pos, data_index, p;

    always @(*) begin
        code       = {CODE_WIDTH{1'b0}};
        data_index = 0;

        // place data bits in non-power-of-2 positions
        for (pos = 1; pos <= DATA_WIDTH+ECC_BITS; pos = pos + 1)
            if ((pos & (pos-1)) != 0) begin
                code[pos-1] = data[data_index];
                data_index  = data_index + 1;
            end

        // Hamming parity bits at positions 1,2,4,8...
        for (p = 0; p < ECC_BITS; p = p + 1) begin
            parity = 1'b0;
            for (pos = 1; pos <= DATA_WIDTH+ECC_BITS; pos = pos + 1)
                if ((pos & (1<<p)) != 0)
                    parity = parity ^ code[pos-1];
            code[(1<<p)-1] = parity;
        end

        // overall parity (double-error detect)
        parity = 1'b0;
        for (pos = 0; pos < DATA_WIDTH+ECC_BITS; pos = pos + 1)
            parity = parity ^ code[pos];
        code[CODE_WIDTH-1] = parity;
    end
endmodule
