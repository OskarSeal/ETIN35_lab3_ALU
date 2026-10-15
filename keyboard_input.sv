`timescale 1ns/1ps

// Operand entry from a PS/2 keyboard, so A and B can be typed instead of set
// on the switches. The receiver is the one from lab 2, used straight from
// Lund_lab_src/sv: sync_keyboard -> edge_detector -> convert_scancode, plus
// convert_to_binary to recognise the digit keys.
// Keys act when pressed. A release is sent as F0 + make code, so the byte
// after F0 is skipped. The E0 prefix of extended keys is not a digit and is
// ignored, which makes keypad Enter (E0 5A) work like Enter.
//   0-9:       append a digit, ignored if the number would go above 255
//   Backspace: remove the last digit
//   Enter:     one-cycle pulse on 'enter' (same job as BTNC)
// The number is stored as three decimal digits, so Backspace is a plain shift
// and no division is needed. 'clear' empties the number.
module keyboard_input (
    input logic clk,
    input logic rst,
    input logic kb_clk,
    input logic kb_data,
    input logic clear,
    output logic [7:0] number,
    output logic enter
    );

    localparam logic [7:0] BREAK_CODE     = 8'hF0;
    localparam logic [7:0] ENTER_CODE     = 8'h5A;
    localparam logic [7:0] BACKSPACE_CODE = 8'h66;

    logic kb_clk_sync, kb_data_sync;
    logic edge_found;
    logic valid_scan_code;
    logic [7:0] scan_code;
    logic [3:0] key_digit;      // 0-9, or 4'hF for any other key

    logic break_pending, break_pending_next;
    logic [3:0] hundreds, tens, ones;
    logic [3:0] hundreds_next, tens_next, ones_next;
    logic enter_next;
    logic [9:0] appended;       // value with key_digit appended, up to 999

    sync_keyboard sync_keyboard_inst (
        .clk(clk),
        .kb_clk(kb_clk),
        .kb_data(kb_data),
        .kb_clk_sync(kb_clk_sync),
        .kb_data_sync(kb_data_sync)
        );

    edge_detector edge_detector_inst (
        .clk(clk),
        .rst(rst),
        .kb_clk_sync(kb_clk_sync),
        .edge_found(edge_found)
        );

    convert_scancode convert_scancode_inst (
        .clk(clk),
        .rst(rst),
        .edge_found(edge_found),
        .serial_data(kb_data_sync),
        .valid_scan_code(valid_scan_code),
        .scan_code_out(scan_code)
        );

    convert_to_binary convert_to_binary_inst (
        .scan_code_in(scan_code),
        .binary_out(key_digit)
        );

    always_ff @( posedge clk or posedge rst ) begin : registers
        if (rst) begin
            break_pending <= 1'b0;
            hundreds      <= 4'd0;
            tens          <= 4'd0;
            ones          <= 4'd0;
            enter         <= 1'b0;
        end else begin
            break_pending <= break_pending_next;
            hundreds      <= hundreds_next;
            tens          <= tens_next;
            ones          <= ones_next;
            enter         <= enter_next;
        end
    end

    // Multiplications by constants only, i.e. shifts and adds in hardware
    assign appended = tens * 10'd100 + ones * 10'd10 + key_digit;
    assign number   = hundreds * 8'd100 + tens * 8'd10 + ones;

    always_comb begin : next_state
        break_pending_next = break_pending;
        hundreds_next      = hundreds;
        tens_next          = tens;
        ones_next          = ones;
        enter_next         = 1'b0;

        if (valid_scan_code) begin
            if (scan_code == BREAK_CODE) begin
                break_pending_next = 1'b1;
            end else if (break_pending) begin
                // Make code of a released key: nothing to do
                break_pending_next = 1'b0;
            end else if (scan_code == ENTER_CODE) begin
                enter_next = 1'b1;
            end else if (scan_code == BACKSPACE_CODE) begin
                hundreds_next = 4'd0;
                tens_next     = hundreds;
                ones_next     = tens;
            end else if (key_digit <= 4'd9 && hundreds == 4'd0 && appended <= 10'd255) begin
                hundreds_next = tens;
                tens_next     = ones;
                ones_next     = key_digit;
            end
        end

        if (clear) begin
            hundreds_next = 4'd0;
            tens_next     = 4'd0;
            ones_next     = 4'd0;
        end
    end

endmodule
