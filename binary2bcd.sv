`timescale 1ns/1ps

// 8-bit binary to 3-digit BCD, Double Dabble unrolled into its combinational
// form: seven add3 cells wired in the standard 8-bit pattern. No loops and no
// generate; every cell is a named instance.
// bcd_out = {hundreds[1:0], tens[3:0], ones[3:0]}
module binary2bcd (
    input logic [7:0] binary_in,
    output logic [9:0] bcd_out
    );

    logic [3:0] c1, c2, c3, c4, c5, c6, c7;

    add3 add3_1 (.value_in({1'b0, binary_in[7:5]}),          .value_out(c1));
    add3 add3_2 (.value_in({c1[2:0], binary_in[4]}),         .value_out(c2));
    add3 add3_3 (.value_in({c2[2:0], binary_in[3]}),         .value_out(c3));
    add3 add3_4 (.value_in({1'b0, c1[3], c2[3], c3[3]}),     .value_out(c4));
    add3 add3_5 (.value_in({c3[2:0], binary_in[2]}),         .value_out(c5));
    add3 add3_6 (.value_in({c4[2:0], c5[3]}),                .value_out(c6));
    add3 add3_7 (.value_in({c5[2:0], binary_in[1]}),         .value_out(c7));

    assign bcd_out = {c4[3], c6, c7, binary_in[0]};

endmodule

// Double Dabble correction cell: add 3 if the BCD digit is 5 or more, so that
// the following shift (the next cell's input wiring) carries into the next digit.
module add3 (
    input logic [3:0] value_in,
    output logic [3:0] value_out
    );

    always_comb begin
        if (value_in >= 4'd5) begin
            value_out = value_in + 4'd3;
        end else begin
            value_out = value_in;
        end
    end

endmodule
