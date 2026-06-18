`timescale 1ns/1ps

// Frame-buffered X4 bicubic base generator for TinySPAN W8A8.
//
// Geometry matches PyTorch interpolate(scale_factor=4, mode="bicubic",
// align_corners=False). Coefficients use the PyTorch cubic alpha -0.75 for the
// four fixed x4 subpixel phases, quantized to Q14.
//
// Input is LR RGB888. Output is q_base in TinySPAN input scale:
//   q_base = clamp(round(bicubic(rgb / 255) * 127), -128, 127)
module span_tinyspan_w8a8_bicubic_base_x4_streamed #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_user,
    input  wire                       s_last,

    output reg                        m_valid,
    input  wire                       m_ready,
    output reg signed [3*ACT_W-1:0]   m_rgb,
    output reg                        m_user,
    output reg                        m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer HR_W = IMG_W * 4;
    localparam integer HR_H = IMG_H * 4;
    localparam integer LR_PIX_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);
    localparam integer HR_X_W = (HR_W <= 2) ? 1 : $clog2(HR_W);
    localparam integer HR_Y_W = (HR_H <= 2) ? 1 : $clog2(HR_H);
    localparam signed [63:0] QBASE_DEN = 64'sd68451041280; // 255 * 2^28

    localparam [1:0] ST_LOAD = 2'd0;
    localparam [1:0] ST_EMIT = 2'd1;

    reg [1:0] state;
    reg [DATA_W-1:0] frame_mem [0:FRAME_PIXELS-1];
    reg [LR_PIX_W-1:0] load_pix;
    reg [HR_X_W-1:0] emit_x;
    reg [HR_Y_W-1:0] emit_y;
    reg frame_user_q;

    integer color;

    assign s_ready = (state == ST_LOAD);

    function automatic signed [15:0] phase_coeff_q14;
        input integer phase;
        input integer tap;
        begin
            case (phase)
                0: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd1080;
                        1: phase_coeff_q14 =  16'sd6984;
                        2: phase_coeff_q14 =  16'sd12280;
                        default: phase_coeff_q14 = -16'sd1800;
                    endcase
                end
                1: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd168;
                        1: phase_coeff_q14 =  16'sd1880;
                        2: phase_coeff_q14 =  16'sd15848;
                        default: phase_coeff_q14 = -16'sd1176;
                    endcase
                end
                2: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd1176;
                        1: phase_coeff_q14 =  16'sd15848;
                        2: phase_coeff_q14 =  16'sd1880;
                        default: phase_coeff_q14 = -16'sd168;
                    endcase
                end
                default: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd1800;
                        1: phase_coeff_q14 =  16'sd12280;
                        2: phase_coeff_q14 =  16'sd6984;
                        default: phase_coeff_q14 = -16'sd1080;
                    endcase
                end
            endcase
        end
    endfunction

    function automatic integer clamp_x;
        input integer x;
        begin
            if (x < 0)
                clamp_x = 0;
            else if (x >= IMG_W)
                clamp_x = IMG_W - 1;
            else
                clamp_x = x;
        end
    endfunction

    function automatic integer clamp_y;
        input integer y;
        begin
            if (y < 0)
                clamp_y = 0;
            else if (y >= IMG_H)
                clamp_y = IMG_H - 1;
            else
                clamp_y = y;
        end
    endfunction

    function automatic signed [ACT_W-1:0] sat_i8;
        input signed [63:0] q;
        begin
            if (q > 64'sd127)
                sat_i8 = 8'sd127;
            else if (q < -64'sd128)
                sat_i8 = -8'sd128;
            else
                sat_i8 = q[ACT_W-1:0];
        end
    endfunction

    function automatic signed [ACT_W-1:0] compute_base_channel;
        input integer ox;
        input integer oy;
        input integer c;
        integer sx_phase;
        integer sy_phase;
        integer src_x_floor;
        integer src_y_floor;
        integer tx;
        integer ty;
        integer px;
        integer py;
        integer addr;
        reg signed [15:0] wx;
        reg signed [15:0] wy;
        reg signed [31:0] wxy;
        reg signed [63:0] acc;
        reg signed [63:0] num;
        reg signed [63:0] abs_num;
        reg [7:0] q_abs;
        reg signed [63:0] q_signed;
        reg [7:0] pix;
        begin
            sx_phase = ox & 3;
            sy_phase = oy & 3;
            src_x_floor = (ox >>> 2) + ((sx_phase < 2) ? -1 : 0);
            src_y_floor = (oy >>> 2) + ((sy_phase < 2) ? -1 : 0);
            acc = 64'sd0;

            for (ty = 0; ty < 4; ty = ty + 1) begin
                py = clamp_y(src_y_floor - 1 + ty);
                wy = phase_coeff_q14(sy_phase, ty);
                for (tx = 0; tx < 4; tx = tx + 1) begin
                    px = clamp_x(src_x_floor - 1 + tx);
                    wx = phase_coeff_q14(sx_phase, tx);
                    wxy = wx * wy;
                    addr = py * IMG_W + px;
                    pix = frame_mem[addr][(2 - c)*8 +: 8];
                    acc = acc + ($signed({1'b0, pix}) * wxy);
                end
            end

            num = acc * 64'sd127;
            abs_num = (num < 64'sd0) ? -num : num;
            q_abs = rounded_div_qbase(abs_num);
            q_signed = (num < 64'sd0) ? -$signed({1'b0, q_abs}) : $signed({1'b0, q_abs});
            compute_base_channel = sat_i8(q_signed);
        end
    endfunction

    function automatic [7:0] rounded_div_qbase;
        input signed [63:0] abs_num_i;
        integer k;
        reg [7:0] q;
        reg signed [63:0] threshold;
        begin
            q = 8'd0;
            for (k = 127; k >= 1; k = k - 1) begin
                threshold = (64'sd68451041280 * k) - 64'sd34225520640;
                if ((q == 8'd0) && (abs_num_i >= threshold))
                    q = k;
            end
            rounded_div_qbase = q;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_LOAD;
            load_pix <= {LR_PIX_W{1'b0}};
            emit_x <= {HR_X_W{1'b0}};
            emit_y <= {HR_Y_W{1'b0}};
            frame_user_q <= 1'b0;
            m_valid <= 1'b0;
            m_rgb <= {3*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_LOAD: begin
                    if (s_valid && s_ready) begin
                        frame_mem[load_pix] <= s_data;
                        if (load_pix == {LR_PIX_W{1'b0}})
                            frame_user_q <= s_user;

                        if (load_pix == FRAME_PIXELS - 1) begin
                            state <= ST_EMIT;
                            load_pix <= {LR_PIX_W{1'b0}};
                            emit_x <= {HR_X_W{1'b0}};
                            emit_y <= {HR_Y_W{1'b0}};
                        end else begin
                            load_pix <= load_pix + 1'b1;
                        end
                    end
                end

                ST_EMIT: begin
                    if (!m_valid || m_ready) begin
                        for (color = 0; color < 3; color = color + 1)
                            m_rgb[color*ACT_W +: ACT_W] <= compute_base_channel(emit_x, emit_y, color);
                        m_user <= frame_user_q && (emit_x == {HR_X_W{1'b0}}) && (emit_y == {HR_Y_W{1'b0}});
                        m_last <= (emit_x == HR_W - 1);
                        m_valid <= 1'b1;

                        if ((emit_x == HR_W - 1) && (emit_y == HR_H - 1)) begin
                            state <= ST_LOAD;
                            emit_x <= {HR_X_W{1'b0}};
                            emit_y <= {HR_Y_W{1'b0}};
                        end else if (emit_x == HR_W - 1) begin
                            emit_x <= {HR_X_W{1'b0}};
                            emit_y <= emit_y + 1'b1;
                        end else begin
                            emit_x <= emit_x + 1'b1;
                        end
                    end
                end

                default: state <= ST_LOAD;
            endcase
        end
    end

    wire unused_last = s_last;
endmodule
