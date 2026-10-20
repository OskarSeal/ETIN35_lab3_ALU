`timescale 1ns/1ps

// Integration testbench for alu_top, using the real debouncers, so each button
// press must last longer than one debouncer sample period (2^20 cycles = 10.5 ms
// at 100 MHz). The whole run is about 0.3 s of simulated time:
// in Vivado use "run all" (the default 1000 ns is far too short).
// The display is read back digit by digit from anode/seven_seg.
module tb_alu_top ();

    logic clk;
    logic rst;          // active-low, like CPU_RESET
    logic b_enter;
    logic b_sign;
    logic [7:0] alu_input;
    logic [6:0] seven_seg;
    logic [3:0] anode;

    localparam int PERIOD = 10;                 // 100 MHz
    localparam int BUTTON_HOLD = 11_000_000;    // 11 ms, longer than one debouncer sample period

    // Expected active-low segment patterns (gfedcba)
    localparam logic [6:0] SEG_0     = 7'b1000000;
    localparam logic [6:0] SEG_1     = 7'b1111001;
    localparam logic [6:0] SEG_2     = 7'b0100100;
    localparam logic [6:0] SEG_3     = 7'b0110000;
    localparam logic [6:0] SEG_4     = 7'b0011001;
    localparam logic [6:0] SEG_5     = 7'b0010010;
    localparam logic [6:0] SEG_6     = 7'b0000010;
    localparam logic [6:0] SEG_7     = 7'b1111000;
    localparam logic [6:0] SEG_8     = 7'b0000000;
    localparam logic [6:0] SEG_9     = 7'b0010000;
    localparam logic [6:0] SEG_MINUS = 7'b0111111;
    localparam logic [6:0] SEG_F     = 7'b0001110;
    localparam logic [6:0] SEG_BLANK = 7'b1111111;

    alu_top dut (
        .clk(clk),
        .rst(rst),
        .b_enter(b_enter),
        .b_sign(b_sign),
        .alu_input(alu_input),
        .seven_seg(seven_seg),
        .anode(anode)
        );

    initial clk = 1'b0;
    always #(PERIOD/2) clk = ~clk;

    task press_enter;
        begin
            b_enter = 1'b1;
            #(BUTTON_HOLD);
            b_enter = 1'b0;
            #(BUTTON_HOLD);
        end
    endtask

    task press_sign;
        begin
            b_sign = 1'b1;
            #(BUTTON_HOLD);
            b_sign = 1'b0;
            #(BUTTON_HOLD);
        end
    endtask

    task press_reset;
        begin
            rst = 1'b0;
            #(10*PERIOD);
            rst = 1'b1;
            #(10*PERIOD);
        end
    endtask

    // Wait for each digit to be enabled in turn and compare its segments.
    // Arguments are given left to right as they appear on the board.
    task check_display;
        input logic [6:0] exp3;
        input logic [6:0] exp2;
        input logic [6:0] exp1;
        input logic [6:0] exp0;
        input int line_num;
        logic [6:0] got3, got2, got1, got0;
        begin
            wait (anode == 4'b0111);
            #1 got3 = seven_seg;
            wait (anode == 4'b1011);
            #1 got2 = seven_seg;
            wait (anode == 4'b1101);
            #1 got1 = seven_seg;
            wait (anode == 4'b1110);
            #1 got0 = seven_seg;
            if ({got3, got2, got1, got0} !== {exp3, exp2, exp1, exp0}) begin
                $display("Display error on line %0d: got %b %b %b %b, expected %b %b %b %b",
                         line_num, got3, got2, got1, got0, exp3, exp2, exp1, exp0);
                $stop;
            end
        end
    endtask

    initial begin
        b_enter = 1'b0;
        b_sign = 1'b0;
        alu_input = 8'd17;
        press_reset;

        // After reset the switches are shown live (unsigned)
        check_display(SEG_BLANK, SEG_0, SEG_1, SEG_7, `__LINE__);
        alu_input = 8'd200;
        #(10*PERIOD);
        check_display(SEG_BLANK, SEG_2, SEG_0, SEG_0, `__LINE__);

        // Latch A = 200 (-56 signed), then B is shown live
        press_enter;
        alu_input = 8'd20;
        #(10*PERIOD);
        check_display(SEG_BLANK, SEG_0, SEG_2, SEG_0, `__LINE__);

        // Latch B = 20 -> A + B = 220
        press_enter;
        check_display(SEG_BLANK, SEG_2, SEG_2, SEG_0, `__LINE__);

        // Switches are locked now
        alu_input = 8'd99;
        #(10*PERIOD);
        check_display(SEG_BLANK, SEG_2, SEG_2, SEG_0, `__LINE__);

        // A - B = 180
        press_enter;
        check_display(SEG_BLANK, SEG_1, SEG_8, SEG_0, `__LINE__);

        // Signed: -56 - 20 = -76
        press_sign;
        check_display(SEG_MINUS, SEG_0, SEG_7, SEG_6, `__LINE__);

        // Signed: -56 mod 3 = 1
        press_enter;
        check_display(SEG_BLANK, SEG_0, SEG_0, SEG_1, `__LINE__);

        // Back to addition, signed: -56 + 20 = -36
        press_enter;
        check_display(SEG_MINUS, SEG_0, SEG_3, SEG_6, `__LINE__);

        // Unsigned again: 220
        press_sign;
        check_display(SEG_BLANK, SEG_2, SEG_2, SEG_0, `__LINE__);

        // Reset starts over, showing the switches (still 99)
        press_reset;
        check_display(SEG_BLANK, SEG_0, SEG_9, SEG_9, `__LINE__);

        // A = 127, B = 1
        alu_input = 8'd127;
        press_enter;
        alu_input = 8'd1;
        press_enter;
        check_display(SEG_BLANK, SEG_1, SEG_2, SEG_8, `__LINE__);

        // Signed 127 + 1 overflows: 'F' has priority over '-'
        press_sign;
        check_display(SEG_F, SEG_1, SEG_2, SEG_8, `__LINE__);

        $display("All tests passed!");
        $finish;
    end

    // Watchdog in case the display never shows a digit
    initial begin
        #(64'd500_000_000);
        $display("Timeout!");
        $finish;
    end

endmodule
