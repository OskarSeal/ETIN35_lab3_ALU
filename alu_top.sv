`timescale 1ns/1ps

import alu_common::*;

module alu_top (
    input logic clk,
    input logic rst,            // CPU_RESET button, active-low on the Nexys4
    input logic b_enter,
    input logic b_sign,
    input logic [7:0] alu_input,
    output logic [6:0] seven_seg,
    output logic [3:0] anode
    );

    // SIGNAL DEFINITIONS
    logic reset;                // active-high reset used by every module
    logic enter, sign;          // debounced buttons
    alu_op_t fn;
    logic [1:0] reg_ctrl;
    logic [7:0] a, b;
    logic [7:0] alu_result;
    logic alu_overflow, alu_sign;
    logic [9:0] bcd;

    // CPU_RESET is pressed = 0, so invert it once here
    assign reset = ~rst;

    // To provide a clean signal out of a bouncy one coming from a push button:
    debouncer debouncer_enter (
        .clk(clk),
        .rst(reset),
        .button_in(b_enter),
        .button_out(enter)
        );

    debouncer debouncer_sign (
        .clk(clk),
        .rst(reset),
        .button_in(b_sign),
        .button_out(sign)
        );

    alu_ctrl alu_ctrl_inst (
        .clk(clk),
        .rst(reset),
        .enter(enter),
        .sign(sign),
        .fn(fn),
        .reg_ctrl(reg_ctrl)
        );

    reg_update reg_update_inst (
        .clk(clk),
        .rst(reset),
        .reg_ctrl(reg_ctrl),
        .reg_input(alu_input),
        .a(a),
        .b(b)
        );

    alu alu_inst (
        .a(a),
        .b(b),
        .fn(fn),
        .result(alu_result),
        .overflow(alu_overflow),
        .sign(alu_sign)
        );

    binary2bcd binary2bcd_inst (
        .binary_in(alu_result),
        .bcd_out(bcd)
        );

    seven_seg_driver seven_seg_driver_inst (
        .clk(clk),
        .rst(reset),
        .bcd_digit(bcd),
        .sign(alu_sign),
        .overflow(alu_overflow),
        .digit_anode(anode),
        .segment(seven_seg)
        );

endmodule
