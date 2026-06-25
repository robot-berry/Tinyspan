`timescale 1ns/1ps

// X2 bicubic base generator for TinySPAN W8A8.
//
// The original X2 serial base produced the right pixels but put the final
// bicubic accumulation and q_base rounding in one long combinational path.
// This wrapper reuses the timing-closed parallel base engine with SCALE=2, so
// X2 keeps the same top-level module contract while matching the 720p30 route.
module span_tinyspan_w8a8_bicubic_base_x2_streamed #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_user,
    input  wire                       s_last,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire signed [3*ACT_W-1:0]  m_rgb,
    output wire                       m_user,
    output wire                       m_last
);
    span_tinyspan_w8a8_bicubic_base_x4_streamed #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .SCALE(2)
    ) u_x2_parallel_base (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
