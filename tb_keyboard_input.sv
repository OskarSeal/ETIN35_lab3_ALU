`timescale 1ns/1ps

// Testbench for keyboard_input together with the lab 2 receiver modules it
// uses. Keys are sent as real PS/2 frames: a tap is the make code followed by
// the release sequence F0 + make code. The PS/2 clock runs at 1 MHz instead of
// 10-16.7 kHz to keep the run short; the receiver only needs each clock phase
// to last a few system clock cycles.
module tb_keyboard_input ();

    logic clk;
    logic rst;
    logic kb_clk;
    logic kb_data;
    logic clear;
    logic [7:0] number;
    logic enter;
    int enter_count;            // clock cycles with enter high

    localparam int PERIOD = 10;         // 100 MHz
    localparam int KB_HALF = 500;       // half a PS/2 clock period

    // PS/2 set 2 make codes
    localparam logic [7:0] KEY_0         = 8'h45;
    localparam logic [7:0] KEY_1         = 8'h16;
    localparam logic [7:0] KEY_2         = 8'h1E;
    localparam logic [7:0] KEY_3         = 8'h26;
    localparam logic [7:0] KEY_4         = 8'h25;
    localparam logic [7:0] KEY_5         = 8'h2E;
    localparam logic [7:0] KEY_6         = 8'h36;
    localparam logic [7:0] KEY_7         = 8'h3D;
    localparam logic [7:0] KEY_8         = 8'h3E;
    localparam logic [7:0] KEY_9         = 8'h46;
    localparam logic [7:0] KEY_A         = 8'h1C;
    localparam logic [7:0] KEY_ENTER     = 8'h5A;
    localparam logic [7:0] KEY_BACKSPACE = 8'h66;
    localparam logic [7:0] EXTENDED      = 8'hE0;
    localparam logic [7:0] BREAK         = 8'hF0;

    keyboard_input uut (
        .clk(clk),
        .rst(rst),
        .kb_clk(kb_clk),
        .kb_data(kb_data),
        .clear(clear),
        .number(number),
        .enter(enter)
        );

    initial clk = 1'b0;
    always #(PERIOD/2) clk = ~clk;

    always @(posedge clk) begin
        if (enter) begin
            enter_count = enter_count + 1;
        end
    end

    // One PS/2 frame: start bit (0), 8 data bits LSB first, odd parity, stop
    // bit (1). Data changes while kb_clk is high and is read on the falling edge.
    task send_byte;
        input logic [7:0] code;
        logic [10:0] frame;
        begin
            frame = {1'b1, ~^code, code, 1'b0};
            repeat (11) begin
                kb_data = frame[0];
                #(KB_HALF);
                kb_clk = 1'b0;
                #(KB_HALF);
                kb_clk = 1'b1;
                frame = frame >> 1;
            end
            kb_data = 1'b1;
            #(4*KB_HALF);
        end
    endtask

    task tap_key;
        input logic [7:0] code;
        begin
            send_byte(code);
            send_byte(BREAK);
            send_byte(code);
        end
    endtask

    // Extended keys such as keypad Enter: E0 + code, released as E0 F0 + code
    task tap_extended_key;
        input logic [7:0] code;
        begin
            send_byte(EXTENDED);
            send_byte(code);
            send_byte(EXTENDED);
            send_byte(BREAK);
            send_byte(code);
        end
    endtask

    task check_number;
        input logic [7:0] expected;
        input int line_num;
        begin
            if (number !== expected) begin
                $display("Error on line %0d: number = %0d, expected %0d", line_num, number, expected);
                $stop;
            end
        end
    endtask

    task check_enter_count;
        input int expected;
        input int line_num;
        begin
            if (enter_count !== expected) begin
                $display("Error on line %0d: enter was high for %0d cycles, expected %0d",
                         line_num, enter_count, expected);
                $stop;
            end
        end
    endtask

    task pulse_clear;
        begin
            @(negedge clk);
            clear = 1'b1;
            @(negedge clk);
            clear = 1'b0;
        end
    endtask

    initial begin
        kb_clk = 1'b1;
        kb_data = 1'b1;
        clear = 1'b0;
        enter_count = 0;
        rst = 1'b1;
        #(10*PERIOD);
        rst = 1'b0;
        #(10*PERIOD);
        check_number(8'd0, `__LINE__);

        // Digits are appended; a fourth digit does not fit
        tap_key(KEY_1);
        check_number(8'd1, `__LINE__);
        tap_key(KEY_2);
        tap_key(KEY_3);
        check_number(8'd123, `__LINE__);
        tap_key(KEY_4);
        check_number(8'd123, `__LINE__);

        // Backspace removes the last digit, and does nothing when empty
        tap_key(KEY_BACKSPACE);
        check_number(8'd12, `__LINE__);
        tap_key(KEY_BACKSPACE);
        tap_key(KEY_BACKSPACE);
        check_number(8'd0, `__LINE__);
        tap_key(KEY_BACKSPACE);
        check_number(8'd0, `__LINE__);

        // 256 is out of range, so the 6 is ignored, but 255 fits
        tap_key(KEY_2);
        tap_key(KEY_5);
        tap_key(KEY_6);
        check_number(8'd25, `__LINE__);
        tap_key(KEY_5);
        check_number(8'd255, `__LINE__);

        // Other keys are ignored
        tap_key(KEY_A);
        check_number(8'd255, `__LINE__);

        // clear empties the number; the remaining digit keys
        pulse_clear;
        check_number(8'd0, `__LINE__);
        tap_key(KEY_2);
        tap_key(KEY_4);
        tap_key(KEY_6);
        check_number(8'd246, `__LINE__);
        pulse_clear;
        tap_key(KEY_1);
        tap_key(KEY_8);
        tap_key(KEY_9);
        check_number(8'd189, `__LINE__);

        // Leading zeros
        pulse_clear;
        tap_key(KEY_0);
        tap_key(KEY_0);
        tap_key(KEY_7);
        check_number(8'd7, `__LINE__);

        // Overlapping keys: press 3, press 8, release 3, release 8
        pulse_clear;
        send_byte(KEY_3);
        send_byte(KEY_8);
        send_byte(BREAK);
        send_byte(KEY_3);
        send_byte(BREAK);
        send_byte(KEY_8);
        check_number(8'd38, `__LINE__);

        // Enter and keypad Enter give a one-cycle pulse each and keep the number
        check_enter_count(0, `__LINE__);
        tap_key(KEY_ENTER);
        check_enter_count(1, `__LINE__);
        tap_extended_key(KEY_ENTER);
        check_enter_count(2, `__LINE__);
        check_number(8'd38, `__LINE__);

        $display("All tests passed!");
        $finish;
    end

endmodule
