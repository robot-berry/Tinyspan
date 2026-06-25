`timescale 1ns/1ps

// Board-facing TinySPAN W8A8 final-output equivalent that emits RGB888.
module span_tinyspan_w8a8_full_streamed_rgb888_base_equiv #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer SCALE = 4,
    parameter integer USE_SERIAL_BASE = 1,
    parameter integer BASE_Q31 = 2007717611,
    parameter integer Q16_MULT = 140748
) (
    input  wire               clk,
    input  wire               rst,

    input  wire               s_valid,
    output wire               s_ready,
    input  wire [DATA_W-1:0]  s_data,
    input  wire               s_user,
    input  wire               s_last,

    output wire               m_valid,
    input  wire               m_ready,
    output wire [23:0]        m_data,
    output wire               m_user,
    output wire               m_last
);
    wire                       q_valid;
    wire                       q_ready;
    wire signed [3*ACT_W-1:0]  q_rgb;
    wire                       q_user;
    wire                       q_last;

    reg                        q_valid_q;
    reg signed [3*ACT_W-1:0]   q_rgb_q;
    reg                        q_user_q;
    reg                        q_last_q;

    span_tinyspan_w8a8_full_streamed_rgb_base_equiv #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .SCALE(SCALE),
        .USE_SERIAL_BASE(USE_SERIAL_BASE),
        .BASE_Q31(BASE_Q31)
    ) u_q_base_equiv (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(q_valid),
        .m_ready(q_ready),
        .m_rgb(q_rgb),
        .m_user(q_user),
        .m_last(q_last)
    );

    assign q_ready = !q_valid_q || m_ready;

    always @(posedge clk) begin
        if (rst) begin
            q_valid_q <= 1'b0;
            q_rgb_q <= {3*ACT_W{1'b0}};
            q_user_q <= 1'b0;
            q_last_q <= 1'b0;
        end else if (q_ready) begin
            q_valid_q <= q_valid;
            q_rgb_q <= q_rgb;
            q_user_q <= q_user;
            q_last_q <= q_last;
        end
    end

    span_tinyspan_w8a8_qrgb_to_rgb888 #(
        .ACT_W(ACT_W),
        .Q16_MULT(Q16_MULT)
    ) u_to_rgb888 (
        .q_rgb_i(q_rgb_q),
        .rgb_o(m_data)
    );

    assign m_valid = q_valid_q;
    assign m_user = q_user_q;
    assign m_last = q_last_q;
endmodule
