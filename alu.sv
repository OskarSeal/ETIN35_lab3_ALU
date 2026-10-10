`timescale 1ns/1ps

import alu_common::*;

// Purely combinational ALU.
// Add/sub: one 9-bit adder. Operands are zero-extended (unsigned) or
// sign-extended (signed) to 9 bits, and for subtraction b is replaced by its
// two's complement (~b + 1), so a - b is computed as a + (-b) with '+' only.
// The 9th bit gives the full 0..255 range for unsigned subtraction and makes
// overflow detection simple:
//   unsigned: overflow = sum[8]            (carry out / borrow)
//   signed:   overflow = sum[8] ^ sum[7]   (result does not fit in 8 bits)
// Signed negative results are output as magnitude + high sign bit, where the
// sign is bit 7 of the wrapped 8-bit result.
// Mod 3: one unsigned mod3 instance. A negative signed a is a_u - 256 and
// 256 mod 3 = 1, so the signed result is (a_u mod 3 - 1) mod 3, i.e. the
// 2-bit remap 0->2, 1->0, 2->1.
module alu (
    input logic [7:0] a,
    input logic [7:0] b,
    input alu_op_t fn,
    output logic [7:0] result,
    output logic overflow,
    output logic sign
    );

    logic is_signed, is_sub;
    logic [8:0] a_ext, b_ext, b_neg, b_op, sum;
    logic [7:0] sum_magnitude;
    logic [1:0] mod_unsigned, mod_negative;

    mod3 mod3_inst (
        .x(a),
        .r(mod_unsigned)
        );

    always_comb begin : add_sub
        is_signed     = (fn == S_ADD) || (fn == S_SUB);
        is_sub        = (fn == U_SUB) || (fn == S_SUB);
        a_ext         = {is_signed & a[7], a};
        b_ext         = {is_signed & b[7], b};
        b_neg         = ~b_ext + 9'd1;
        b_op          = is_sub ? b_neg : b_ext;
        sum           = a_ext + b_op;
        sum_magnitude = ~sum[7:0] + 8'd1;
    end

    always_comb begin : mod3_signed
        case (mod_unsigned)
            2'd0:    mod_negative = 2'd2;
            2'd1:    mod_negative = 2'd0;
            2'd2:    mod_negative = 2'd1;
            default: mod_negative = 2'd0;
        endcase
    end

    always_comb begin : output_mux
        result   = 8'd0;
        overflow = 1'b0;
        sign     = 1'b0;
        case (fn)
            INPUT_A: result = a;
            INPUT_B: result = b;
            U_ADD, U_SUB: begin
                result   = sum[7:0];
                overflow = sum[8];
            end
            S_ADD, S_SUB: begin
                sign     = sum[7];
                overflow = sum[8] ^ sum[7];
                result   = sum[7] ? sum_magnitude : sum[7:0];
            end
            U_MOD3: result = {6'd0, mod_unsigned};
            S_MOD3: result = {6'd0, a[7] ? mod_negative : mod_unsigned};
            default: result = 8'd0;
        endcase
    end

endmodule
