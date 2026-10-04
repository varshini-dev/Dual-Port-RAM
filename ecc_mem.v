`timescale 1ns/1ps
// Raw codeword storage: 2 write ports, 2 async read ports (same address per port).
// Same-address double write: port A wins, 'collision' flags it (combinational).
module ecc_mem #(
    parameter ADDR_WIDTH = 4,
    parameter CODE_WIDTH = 13,
    parameter DEPTH      = (1<<ADDR_WIDTH)
)(
    input                   clk,
    input  [ADDR_WIDTH-1:0] addr_a,
    input  [CODE_WIDTH-1:0] wcode_a,
    input                   we_a,
    output [CODE_WIDTH-1:0] rcode_a,
    input  [ADDR_WIDTH-1:0] addr_b,
    input  [CODE_WIDTH-1:0] wcode_b,
    input                   we_b,
    output [CODE_WIDTH-1:0] rcode_b,
    output                  collision
);
    reg [CODE_WIDTH-1:0] mem [0:DEPTH-1];

    assign rcode_a   = mem[addr_a];
    assign rcode_b   = mem[addr_b];
    assign collision = we_a && we_b && (addr_a == addr_b);

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= wcode_a;
        if (we_b && !collision) mem[addr_b] <= wcode_b;
    end
endmodule
