`timescale 1ns/1ps

// Unsigned 8-bit x mod 3 as a chain of compare-and-subtract stages
// (Fig. 1 in Modulo3.pdf). The stages subtract 192, 96, 48, 24, 12, 6 and 3
// (3*64 down to 3*1) when the value is at least that large. A stage's input is
// always below twice its constant, so one subtraction leaves a value below the
// constant and the value loses a bit after every stage but the first. What is
// left after the stage for 3 is in 0..2, i.e. x mod 3.
module mod3 (
    input logic [7:0] x,
    output logic [1:0] r
    );

    logic [7:0] r192; // < 192
    logic [6:0] r96;  // < 96
    logic [5:0] r48;  // < 48
    logic [4:0] r24;  // < 24
    logic [3:0] r12;  // < 12
    logic [2:0] r6;   // < 6

    mod3_stage #(.W(8), .K(192)) stage_192 (.x(x),    .y(r192));
    mod3_stage #(.W(8), .K(96))  stage_96  (.x(r192), .y(r96));
    mod3_stage #(.W(7), .K(48))  stage_48  (.x(r96),  .y(r48));
    mod3_stage #(.W(6), .K(24))  stage_24  (.x(r48),  .y(r24));
    mod3_stage #(.W(5), .K(12))  stage_12  (.x(r24),  .y(r12));
    mod3_stage #(.W(4), .K(6))   stage_6   (.x(r12),  .y(r6));
    mod3_stage #(.W(3), .K(3))   stage_3   (.x(r6),   .y(r));

endmodule

// y = (x >= K) ? x - K : x, for a W-bit x below 2*K, so y < K fits in
// $clog2(K) bits. The subtraction is x + (two's complement of K) in W+1 bits;
// its carry out is 1 exactly when there is no borrow, i.e. when x >= K, so the
// same adder does both the compare and the subtract.
module mod3_stage #(
    parameter int W = 8,
    parameter int K = 192
    ) (
    input logic [W-1:0] x,
    output logic [$clog2(K)-1:0] y
    );

    localparam logic [W-1:0] K_NEG = W'(~K + 1);

    logic [W:0] diff;

    always_comb begin
        diff = {1'b0, x} + {1'b0, K_NEG};
        y    = diff[W] ? diff[$clog2(K)-1:0] : x[$clog2(K)-1:0];
    end

endmodule
