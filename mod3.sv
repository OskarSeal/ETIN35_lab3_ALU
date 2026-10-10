`timescale 1ns/1ps

// Unsigned 8-bit x mod 3.
// Since 4 mod 3 = 1, x = d3*64 + d2*16 + d1*4 + d0 (2-bit digits d) gives
// x mod 3 = (d3 + d2 + d1 + d0) mod 3. The four digits are reduced pairwise
// by a tree of three mod3_add cells, so no division or subtraction is needed.
module mod3 (
    input logic [7:0] x,
    output logic [1:0] r
    );

    logic [1:0] r_low, r_high;

    mod3_add mod3_add_low (
        .p(x[1:0]),
        .q(x[3:2]),
        .r(r_low)
        );

    mod3_add mod3_add_high (
        .p(x[5:4]),
        .q(x[7:6]),
        .r(r_high)
        );

    mod3_add mod3_add_root (
        .p(r_low),
        .q(r_high),
        .r(r)
        );

endmodule

// (p + q) mod 3 for p, q in 0..3 (3 counts as 0). Pure look-up table.
module mod3_add (
    input logic [1:0] p,
    input logic [1:0] q,
    output logic [1:0] r
    );

    always_comb begin
        case ({p, q})
            4'b00_00: r = 2'd0;
            4'b00_01: r = 2'd1;
            4'b00_10: r = 2'd2;
            4'b00_11: r = 2'd0;
            4'b01_00: r = 2'd1;
            4'b01_01: r = 2'd2;
            4'b01_10: r = 2'd0;
            4'b01_11: r = 2'd1;
            4'b10_00: r = 2'd2;
            4'b10_01: r = 2'd0;
            4'b10_10: r = 2'd1;
            4'b10_11: r = 2'd2;
            4'b11_00: r = 2'd0;
            4'b11_01: r = 2'd1;
            4'b11_10: r = 2'd2;
            default:  r = 2'd0; // 4'b11_11
        endcase
    end

endmodule
