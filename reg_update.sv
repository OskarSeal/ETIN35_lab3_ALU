`timescale 1ns/1ps

// Operand registers A and B (Fig. 3). reg_ctrl selects which register loads
// reg_input this cycle: 01 = A, 10 = B, anything else = hold both.
// Only one register can be updated at a time.
module reg_update (
    input logic clk,
    input logic rst,
    input logic [1:0] reg_ctrl,
    input logic [7:0] reg_input,
    output logic [7:0] a,
    output logic [7:0] b
    );

    logic [7:0] a_next, b_next;

    always_comb begin : next_state
        a_next = a;
        b_next = b;
        case (reg_ctrl)
            2'b01:   a_next = reg_input;
            2'b10:   b_next = reg_input;
            default: ;
        endcase
    end

    dff #(
        .W(8)
        ) reg_a (
        .clk(clk),
        .rst(rst),
        .d(a_next),
        .q(a)
        );

    dff #(
        .W(8)
        ) reg_b (
        .clk(clk),
        .rst(rst),
        .d(b_next),
        .q(b)
        );

endmodule
