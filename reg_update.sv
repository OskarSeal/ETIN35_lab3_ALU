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

    always_ff @( posedge clk or posedge rst ) begin : registers
        if (rst) begin
            a <= '0;
            b <= '0;
        end else begin
            case (reg_ctrl)
                2'b01:   a <= reg_input;
                2'b10:   b <= reg_input;
                default: ;
            endcase
        end
    end

endmodule
