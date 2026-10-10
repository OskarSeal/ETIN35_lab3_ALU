`timescale 1ns/1ps

import alu_common::*;

// ALU controller (Moore FSM).
//   ST_IN_A: show A live from switches, load reg A every cycle (reg_ctrl 01)
//   ST_IN_B: show B live from switches, load reg B every cycle (reg_ctrl 10)
//   ST_ADD -> ST_SUB -> ST_MOD -> ST_ADD ...: no register updates (switches locked)
// Each rising edge of 'enter' moves to the next state. Each rising edge of
// 'sign' toggles signed_mode, which selects the U_/S_ version of the operation.
// The debounced buttons are levels, so edges are detected here with a
// one-cycle delayed copy of each button.
module alu_ctrl (
    input logic clk,
    input logic rst,
    input logic enter,
    input logic sign,
    output alu_op_t fn,
    output logic [1:0] reg_ctrl
    );

    typedef enum logic [2:0] {
        ST_IN_A,
        ST_IN_B,
        ST_ADD,
        ST_SUB,
        ST_MOD
    } state_t;

    state_t state, state_next;
    logic signed_mode, signed_mode_next;
    logic enter_prev, sign_prev;
    logic enter_edge, sign_edge;

    always_ff @( posedge clk or posedge rst ) begin : registers
        if (rst) begin
            state       <= ST_IN_A;
            signed_mode <= 1'b0;
            enter_prev  <= 1'b0;
            sign_prev   <= 1'b0;
        end else begin
            state       <= state_next;
            signed_mode <= signed_mode_next;
            enter_prev  <= enter;
            sign_prev   <= sign;
        end
    end

    assign enter_edge = enter & ~enter_prev;
    assign sign_edge  = sign & ~sign_prev;

    always_comb begin : next_state
        state_next       = state;
        signed_mode_next = signed_mode;

        if (sign_edge) begin
            signed_mode_next = ~signed_mode;
        end

        if (enter_edge) begin
            case (state)
                ST_IN_A: state_next = ST_IN_B;
                ST_IN_B: state_next = ST_ADD;
                ST_ADD:  state_next = ST_SUB;
                ST_SUB:  state_next = ST_MOD;
                ST_MOD:  state_next = ST_ADD;
                default: state_next = ST_IN_A;
            endcase
        end
    end

    always_comb begin : outputs
        fn       = INPUT_A;
        reg_ctrl = 2'b00;
        case (state)
            ST_IN_A: begin
                fn       = INPUT_A;
                reg_ctrl = 2'b01;
            end
            ST_IN_B: begin
                fn       = INPUT_B;
                reg_ctrl = 2'b10;
            end
            ST_ADD: begin
                if (signed_mode) begin
                    fn = S_ADD;
                end else begin
                    fn = U_ADD;
                end
            end
            ST_SUB: begin
                if (signed_mode) begin
                    fn = S_SUB;
                end else begin
                    fn = U_SUB;
                end
            end
            ST_MOD: begin
                if (signed_mode) begin
                    fn = S_MOD3;
                end else begin
                    fn = U_MOD3;
                end
            end
            default: fn = INPUT_A;
        endcase
    end

endmodule
