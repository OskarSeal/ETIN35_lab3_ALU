`timescale 1ns/1ps

import alu_common::*;

module alu_top (
    input logic clk,
    input logic rst,            // CPU_RESET button, active-low on the Nexys4
    input logic b_enter,
    input logic b_sign,
    input logic [7:0] alu_input,
    input logic use_keyboard,   // SW15: 1 = operands typed on the PS/2 keyboard
    input logic kb_clk,
    input logic kb_data,
    output logic [6:0] seven_seg,
    output logic [3:0] anode
    );

    // SIGNAL DEFINITIONS
    logic reset;                // active-high reset used by every module
    logic enter_button, sign;   // debounced buttons
    logic kb_enter;             // Enter key, one-cycle pulse
    logic enter;                // BTNC or the Enter key
    logic [7:0] kb_number;      // number typed on the keyboard
    logic [7:0] operand;        // value loaded into reg A or B
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
        .button_out(enter_button)
        );

    debouncer debouncer_sign (
        .clk(clk),
        .rst(reset),
        .button_in(b_sign),
        .button_out(sign)
        );

    // Operands typed on a PS/2 keyboard, using the lab 2 receiver. The number
    // is cleared on every Enter, so B is typed from scratch once A is latched.
    keyboard_input keyboard_input_inst (
        .clk(clk),
        .rst(reset),
        .kb_clk(kb_clk),
        .kb_data(kb_data),
        .clear(enter),
        .number(kb_number),
        .enter(kb_enter)
        );

    assign enter   = enter_button | kb_enter;
    assign operand = use_keyboard ? kb_number : alu_input;

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
        .reg_input(operand),
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
