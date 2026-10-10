`timescale 1ns/1ps

// Multiplexed 4-digit 7-segment driver for the Nexys4 (anodes and segments
// are active-low). The top two bits of a free-running counter select the digit.
//   digit 3 (leftmost): 'F' on overflow, else '-' if negative, else blank
//   digit 2..0:         hundreds, tens, ones from bcd_digit
// segment[0] = CA (a) ... segment[6] = CG (g)
module seven_seg_driver (
    input logic clk,
    input logic rst,
    input logic [9:0] bcd_digit,
    input logic sign,
    input logic overflow,
    output logic [3:0] digit_anode,
    output logic [6:0] segment
    );

    // 2^14 cycles per digit at 100 MHz = 164 us, whole display ~1.5 kHz.
    // Lower this if the display flickers.
    localparam int REFRESH_CNT_WIDTH = 16;

    // Symbol codes beyond the decimal digits 0..9
    localparam logic [3:0] SYM_MINUS = 4'hA;
    localparam logic [3:0] SYM_BLANK = 4'hB;
    localparam logic [3:0] SYM_F     = 4'hF;

    logic [REFRESH_CNT_WIDTH-1:0] refresh_cnt, refresh_cnt_next;
    logic [1:0] digit_sel;
    logic [3:0] symbol;
    logic [6:0] segment_on; // active-high pattern, bit 0 = a

    always_ff @( posedge clk or posedge rst ) begin : registers
        if (rst) begin
            refresh_cnt <= '0;
        end else begin
            refresh_cnt <= refresh_cnt_next;
        end
    end

    assign refresh_cnt_next = refresh_cnt + 1'b1;
    assign digit_sel        = refresh_cnt[REFRESH_CNT_WIDTH-1:REFRESH_CNT_WIDTH-2];

    always_comb begin : anode_select
        digit_anode            = 4'b1111;
        digit_anode[digit_sel] = 1'b0;
    end

    always_comb begin : symbol_select
        case (digit_sel)
            2'd0:    symbol = bcd_digit[3:0];
            2'd1:    symbol = bcd_digit[7:4];
            2'd2:    symbol = {2'b00, bcd_digit[9:8]};
            default: begin
                if (overflow) begin
                    symbol = SYM_F;
                end else if (sign) begin
                    symbol = SYM_MINUS;
                end else begin
                    symbol = SYM_BLANK;
                end
            end
        endcase
    end

    always_comb begin : segment_decode
        case (symbol)         // gfedcba
            4'd0:      segment_on = 7'b0111111;
            4'd1:      segment_on = 7'b0000110;
            4'd2:      segment_on = 7'b1011011;
            4'd3:      segment_on = 7'b1001111;
            4'd4:      segment_on = 7'b1100110;
            4'd5:      segment_on = 7'b1101101;
            4'd6:      segment_on = 7'b1111101;
            4'd7:      segment_on = 7'b0000111;
            4'd8:      segment_on = 7'b1111111;
            4'd9:      segment_on = 7'b1101111;
            SYM_MINUS: segment_on = 7'b1000000;
            SYM_F:     segment_on = 7'b1110001;
            default:   segment_on = 7'b0000000; // blank
        endcase
    end

    // Nexys4 cathodes are active-low
    assign segment = ~segment_on;

endmodule
