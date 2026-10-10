`timescale 1ns/1ps

// Exhaustive testbench for binary2bcd, without loops: a counter register
// steps binary_in through 0..255 (one value per clock), and every value is
// checked on the falling edge against a divide/modulo reference model.
module tb_binary2bcd ();

    logic clk;
    logic rst;
    logic [7:0] binary_in, binary_in_next;
    logic [9:0] bcd_out;
    logic [7:0] hundreds, tens, ones;
    logic [9:0] bcd_expected;

    localparam int PERIOD = 10;

    binary2bcd uut (
        .binary_in(binary_in),
        .bcd_out(bcd_out)
        );

    initial clk = 1'b0;
    always #(PERIOD/2) clk = ~clk;

    // Stimulus counter
    always_ff @( posedge clk or posedge rst ) begin
        if (rst) begin
            binary_in <= 8'd0;
        end else begin
            binary_in <= binary_in_next;
        end
    end

    assign binary_in_next = binary_in + 8'd1;

    // Reference model (testbench only, never synthesized)
    assign hundreds     = binary_in / 8'd100;
    assign tens         = (binary_in / 8'd10) % 8'd10;
    assign ones         = binary_in % 8'd10;
    assign bcd_expected = {hundreds[1:0], tens[3:0], ones[3:0]};

    // Checker
    always @(negedge clk) begin
        if (!rst) begin
            if (bcd_out !== bcd_expected) begin
                $display("Error: %0d gave %0d %0d %0d, expected %0d %0d %0d", binary_in,
                         bcd_out[9:8], bcd_out[7:4], bcd_out[3:0],
                         bcd_expected[9:8], bcd_expected[7:4], bcd_expected[3:0]);
                $stop;
            end
            if (binary_in == 8'd255) begin
                $display("All 256 values passed!");
                $finish;
            end
        end
    end

    initial begin
        rst = 1'b1;
        #(PERIOD);
        rst = 1'b0;
    end

endmodule
