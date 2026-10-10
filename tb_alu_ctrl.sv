`timescale 1ns/1ps

import alu_common::*;

// Testbench for the ALU controller. enter/sign are driven directly (as if
// already debounced), each press held for several clock cycles.
module tb_alu_ctrl ();

    logic clk;
    logic rst;
    logic enter;
    logic sign;
    alu_op_t fn;
    logic [1:0] reg_ctrl;

    localparam int PERIOD = 10;
    localparam int HOLD = 5 * PERIOD;

    alu_ctrl uut (
        .clk(clk),
        .rst(rst),
        .enter(enter),
        .sign(sign),
        .fn(fn),
        .reg_ctrl(reg_ctrl)
        );

    initial clk = 1'b0;
    always #(PERIOD/2) clk = ~clk;

    task check_ctrl;
        input alu_op_t expected_fn;
        input logic [1:0] expected_reg_ctrl;
        input int line_num;
        begin
            if ((fn !== expected_fn) || (reg_ctrl !== expected_reg_ctrl)) begin
                // fn printed as its number in alu_op_t (INPUT_A = 0 ... S_MOD3 = 7)
                $display("Error on line %0d: fn=%0d reg_ctrl=%b, expected fn=%0d reg_ctrl=%b",
                         line_num, fn, reg_ctrl, expected_fn, expected_reg_ctrl);
                $stop;
            end
        end
    endtask

    task press_enter;
        begin
            enter = 1'b1;
            #(HOLD);
            enter = 1'b0;
            #(HOLD);
        end
    endtask

    task press_sign;
        begin
            sign = 1'b1;
            #(HOLD);
            sign = 1'b0;
            #(HOLD);
        end
    endtask

    // All input changes happen on multiples of PERIOD, i.e. between rising edges
    initial begin
        rst = 1'b1;
        enter = 1'b0;
        sign = 1'b0;
        #(2*PERIOD);
        rst = 1'b0;
        #(2*PERIOD);

        // After reset: show A, load reg A
        check_ctrl(INPUT_A, 2'b01, `__LINE__);

        press_enter;
        check_ctrl(INPUT_B, 2'b10, `__LINE__);

        press_enter;
        check_ctrl(U_ADD, 2'b00, `__LINE__);

        // Holding Enter for a long time must only advance one state
        enter = 1'b1;
        #(20*PERIOD);
        check_ctrl(U_SUB, 2'b00, `__LINE__);
        enter = 1'b0;
        #(HOLD);
        check_ctrl(U_SUB, 2'b00, `__LINE__);

        press_enter;
        check_ctrl(U_MOD3, 2'b00, `__LINE__);

        // After modulo the ALU goes back to addition
        press_enter;
        check_ctrl(U_ADD, 2'b00, `__LINE__);

        // Sign toggles signed/unsigned in the operation states
        press_sign;
        check_ctrl(S_ADD, 2'b00, `__LINE__);

        press_enter;
        check_ctrl(S_SUB, 2'b00, `__LINE__);

        press_enter;
        check_ctrl(S_MOD3, 2'b00, `__LINE__);

        press_enter;
        check_ctrl(S_ADD, 2'b00, `__LINE__);

        press_sign;
        check_ctrl(U_ADD, 2'b00, `__LINE__);

        // Reset clears everything, also signed mode (asynchronous)
        rst = 1'b1;
        #(PERIOD);
        check_ctrl(INPUT_A, 2'b01, `__LINE__);
        rst = 1'b0;
        #(PERIOD);

        // Sign while entering operands: inputs are always shown unsigned,
        // but the mode is remembered for the operations
        press_sign;
        check_ctrl(INPUT_A, 2'b01, `__LINE__);

        press_enter;
        check_ctrl(INPUT_B, 2'b10, `__LINE__);

        press_enter;
        check_ctrl(S_ADD, 2'b00, `__LINE__);

        // Both buttons pressed at the same time
        enter = 1'b1;
        sign = 1'b1;
        #(HOLD);
        enter = 1'b0;
        sign = 1'b0;
        #(HOLD);
        check_ctrl(U_SUB, 2'b00, `__LINE__);

        $display("All tests passed!");
        $finish;
    end

endmodule
