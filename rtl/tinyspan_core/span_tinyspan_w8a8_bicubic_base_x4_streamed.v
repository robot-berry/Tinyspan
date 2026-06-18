`timescale 1ns/1ps

// BRAM-friendly X4 bicubic base generator for TinySPAN W8A8.
//
// Geometry matches PyTorch interpolate(scale_factor=4, mode="bicubic",
// align_corners=False). Coefficients use the PyTorch cubic alpha -0.75 for the
// four fixed x4 subpixel phases, quantized to Q14.
//
// The 320x180 -> 1280x720 acceptance target is too large for a 16-read
// combinational frame buffer. This implementation mirrors the LR RGB888 frame
// into eight single-read BRAM candidates and processes two bicubic row taps per
// cycle. The read-data and coefficient pipeline is explicitly aligned for
// synchronous BRAM inference.
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

    localparam [1:0] ST_LOAD = 2'd0;
    localparam [1:0] ST_RUN  = 2'd1;
    localparam [1:0] ST_OUT  = 2'd2;

    reg [1:0] state;

    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem0 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem1 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem2 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem3 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem4 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem5 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem6 [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] frame_mem7 [0:FRAME_PIXELS-1];

    reg [LR_PIX_W-1:0] load_pix;
    reg [LR_PIX_W-1:0] rd_addr0;
    reg [LR_PIX_W-1:0] rd_addr1;
    reg [LR_PIX_W-1:0] rd_addr2;
    reg [LR_PIX_W-1:0] rd_addr3;
    reg [LR_PIX_W-1:0] rd_addr4;
    reg [LR_PIX_W-1:0] rd_addr5;
    reg [LR_PIX_W-1:0] rd_addr6;
    reg [LR_PIX_W-1:0] rd_addr7;
    reg [DATA_W-1:0] rd_pix0;
    reg [DATA_W-1:0] rd_pix1;
    reg [DATA_W-1:0] rd_pix2;
    reg [DATA_W-1:0] rd_pix3;
    reg [DATA_W-1:0] rd_pix4;
    reg [DATA_W-1:0] rd_pix5;
    reg [DATA_W-1:0] rd_pix6;
    reg [DATA_W-1:0] rd_pix7;

    reg [HR_X_W-1:0] emit_x;
    reg [HR_Y_W-1:0] emit_y;
    reg frame_user_q;
    reg frame_done_q;
    reg [1:0] issue_idx;

    reg pipe_valid_d0;
    reg pipe_valid_d1;
    reg pair_idx_d0;
    reg pair_idx_d1;
    reg signed [15:0] wx0_d0;
    reg signed [15:0] wx1_d0;
    reg signed [15:0] wx2_d0;
    reg signed [15:0] wx3_d0;
    reg signed [15:0] wy0_d0;
    reg signed [15:0] wy1_d0;
    reg signed [15:0] wx0_d1;
    reg signed [15:0] wx1_d1;
    reg signed [15:0] wx2_d1;
    reg signed [15:0] wx3_d1;
    reg signed [15:0] wy0_d1;
    reg signed [15:0] wy1_d1;

    reg signed [63:0] acc_r;
    reg signed [63:0] acc_g;
    reg signed [63:0] acc_b;

    reg signed [31:0] w00;
    reg signed [31:0] w01;
    reg signed [31:0] w02;
    reg signed [31:0] w03;
    reg signed [31:0] w10;
    reg signed [31:0] w11;
    reg signed [31:0] w12;
    reg signed [31:0] w13;
    reg signed [63:0] row0_r;
    reg signed [63:0] row0_g;
    reg signed [63:0] row0_b;
    reg signed [63:0] row1_r;
    reg signed [63:0] row1_g;
    reg signed [63:0] row1_b;
    reg signed [63:0] pair_r;
    reg signed [63:0] pair_g;
    reg signed [63:0] pair_b;
    reg signed [63:0] next_r;
    reg signed [63:0] next_g;
    reg signed [63:0] next_b;

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

    function automatic [LR_PIX_W-1:0] pixel_addr;
        input integer y;
        input integer x;
        integer cy;
        integer cx;
        begin
            cy = clamp_y(y);
            cx = clamp_x(x);
            pixel_addr = cy * IMG_W + cx;
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

    function automatic signed [ACT_W-1:0] acc_to_qbase;
        input signed [63:0] acc_i;
        reg signed [63:0] num;
        reg signed [63:0] abs_num;
        reg [7:0] q_abs;
        reg signed [63:0] q_signed;
        begin
            num = acc_i * 64'sd127;
            abs_num = (num < 64'sd0) ? -num : num;
            q_abs = rounded_div_qbase(abs_num);
            q_signed = (num < 64'sd0) ? -$signed({1'b0, q_abs}) : $signed({1'b0, q_abs});
            if (q_signed > 64'sd127)
                acc_to_qbase = 8'sd127;
            else if (q_signed < -64'sd128)
                acc_to_qbase = -8'sd128;
            else
                acc_to_qbase = q_signed[ACT_W-1:0];
        end
    endfunction

    task automatic issue_pair;
        input integer pair_index;
        integer sx_phase;
        integer sy_phase;
        integer src_x_floor;
        integer src_y_floor;
        integer ty0;
        integer ty1;
        begin
            sx_phase = emit_x & 3;
            sy_phase = emit_y & 3;
            src_x_floor = (emit_x >>> 2) + ((sx_phase < 2) ? -1 : 0);
            src_y_floor = (emit_y >>> 2) + ((sy_phase < 2) ? -1 : 0);
            ty0 = pair_index * 2;
            ty1 = ty0 + 1;

            rd_addr0 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor - 1);
            rd_addr1 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor);
            rd_addr2 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor + 1);
            rd_addr3 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor + 2);
            rd_addr4 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor - 1);
            rd_addr5 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor);
            rd_addr6 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor + 1);
            rd_addr7 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor + 2);

            wx0_d0 <= phase_coeff_q14(sx_phase, 0);
            wx1_d0 <= phase_coeff_q14(sx_phase, 1);
            wx2_d0 <= phase_coeff_q14(sx_phase, 2);
            wx3_d0 <= phase_coeff_q14(sx_phase, 3);
            wy0_d0 <= phase_coeff_q14(sy_phase, ty0);
            wy1_d0 <= phase_coeff_q14(sy_phase, ty1);
            pair_idx_d0 <= (pair_index == 0) ? 1'b0 : 1'b1;
            pipe_valid_d0 <= 1'b1;
        end
    endtask

    task automatic begin_pixel;
        begin
            acc_r <= 64'sd0;
            acc_g <= 64'sd0;
            acc_b <= 64'sd0;
            issue_idx <= 2'd1;
            pipe_valid_d0 <= 1'b0;
            pipe_valid_d1 <= 1'b0;
            pair_idx_d0 <= 1'b0;
            pair_idx_d1 <= 1'b0;
            issue_pair(0);
        end
    endtask

    task automatic advance_pixel;
        begin
            frame_done_q <= (emit_x == HR_W - 1) && (emit_y == HR_H - 1);
            if ((emit_x == HR_W - 1) && (emit_y == HR_H - 1)) begin
                emit_x <= {HR_X_W{1'b0}};
                emit_y <= {HR_Y_W{1'b0}};
            end else if (emit_x == HR_W - 1) begin
                emit_x <= {HR_X_W{1'b0}};
                emit_y <= emit_y + 1'b1;
            end else begin
                emit_x <= emit_x + 1'b1;
            end
        end
    endtask

    always @(posedge clk) begin
        rd_pix0 <= frame_mem0[rd_addr0];
        rd_pix1 <= frame_mem1[rd_addr1];
        rd_pix2 <= frame_mem2[rd_addr2];
        rd_pix3 <= frame_mem3[rd_addr3];
        rd_pix4 <= frame_mem4[rd_addr4];
        rd_pix5 <= frame_mem5[rd_addr5];
        rd_pix6 <= frame_mem6[rd_addr6];
        rd_pix7 <= frame_mem7[rd_addr7];

        if (rst) begin
            state <= ST_LOAD;
            load_pix <= {LR_PIX_W{1'b0}};
            rd_addr0 <= {LR_PIX_W{1'b0}};
            rd_addr1 <= {LR_PIX_W{1'b0}};
            rd_addr2 <= {LR_PIX_W{1'b0}};
            rd_addr3 <= {LR_PIX_W{1'b0}};
            rd_addr4 <= {LR_PIX_W{1'b0}};
            rd_addr5 <= {LR_PIX_W{1'b0}};
            rd_addr6 <= {LR_PIX_W{1'b0}};
            rd_addr7 <= {LR_PIX_W{1'b0}};
            rd_pix0 <= {DATA_W{1'b0}};
            rd_pix1 <= {DATA_W{1'b0}};
            rd_pix2 <= {DATA_W{1'b0}};
            rd_pix3 <= {DATA_W{1'b0}};
            rd_pix4 <= {DATA_W{1'b0}};
            rd_pix5 <= {DATA_W{1'b0}};
            rd_pix6 <= {DATA_W{1'b0}};
            rd_pix7 <= {DATA_W{1'b0}};
            emit_x <= {HR_X_W{1'b0}};
            emit_y <= {HR_Y_W{1'b0}};
            frame_user_q <= 1'b0;
            frame_done_q <= 1'b0;
            issue_idx <= 2'd0;
            pipe_valid_d0 <= 1'b0;
            pipe_valid_d1 <= 1'b0;
            pair_idx_d0 <= 1'b0;
            pair_idx_d1 <= 1'b0;
            wx0_d0 <= 16'sd0;
            wx1_d0 <= 16'sd0;
            wx2_d0 <= 16'sd0;
            wx3_d0 <= 16'sd0;
            wy0_d0 <= 16'sd0;
            wy1_d0 <= 16'sd0;
            wx0_d1 <= 16'sd0;
            wx1_d1 <= 16'sd0;
            wx2_d1 <= 16'sd0;
            wx3_d1 <= 16'sd0;
            wy0_d1 <= 16'sd0;
            wy1_d1 <= 16'sd0;
            acc_r <= 64'sd0;
            acc_g <= 64'sd0;
            acc_b <= 64'sd0;
            m_valid <= 1'b0;
            m_rgb <= {3*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            case (state)
                ST_LOAD: begin
                    m_valid <= 1'b0;
                    pipe_valid_d0 <= 1'b0;
                    pipe_valid_d1 <= 1'b0;
                    if (s_valid && s_ready) begin
                        frame_mem0[load_pix] <= s_data;
                        frame_mem1[load_pix] <= s_data;
                        frame_mem2[load_pix] <= s_data;
                        frame_mem3[load_pix] <= s_data;
                        frame_mem4[load_pix] <= s_data;
                        frame_mem5[load_pix] <= s_data;
                        frame_mem6[load_pix] <= s_data;
                        frame_mem7[load_pix] <= s_data;
                        if (load_pix == {LR_PIX_W{1'b0}})
                            frame_user_q <= s_user;

                        if (load_pix == FRAME_PIXELS - 1) begin
                            load_pix <= {LR_PIX_W{1'b0}};
                            emit_x <= {HR_X_W{1'b0}};
                            emit_y <= {HR_Y_W{1'b0}};
                            frame_done_q <= 1'b0;
                            begin_pixel();
                            state <= ST_RUN;
                        end else begin
                            load_pix <= load_pix + 1'b1;
                        end
                    end
                end

                ST_RUN: begin
                    m_valid <= 1'b0;
                    pipe_valid_d1 <= pipe_valid_d0;
                    pair_idx_d1 <= pair_idx_d0;
                    wx0_d1 <= wx0_d0;
                    wx1_d1 <= wx1_d0;
                    wx2_d1 <= wx2_d0;
                    wx3_d1 <= wx3_d0;
                    wy0_d1 <= wy0_d0;
                    wy1_d1 <= wy1_d0;
                    pipe_valid_d0 <= 1'b0;

                    if (pipe_valid_d1) begin
                        w00 = wx0_d1 * wy0_d1;
                        w01 = wx1_d1 * wy0_d1;
                        w02 = wx2_d1 * wy0_d1;
                        w03 = wx3_d1 * wy0_d1;
                        w10 = wx0_d1 * wy1_d1;
                        w11 = wx1_d1 * wy1_d1;
                        w12 = wx2_d1 * wy1_d1;
                        w13 = wx3_d1 * wy1_d1;

                        row0_r = ($signed({1'b0, rd_pix0[23:16]}) * w00) +
                                 ($signed({1'b0, rd_pix1[23:16]}) * w01) +
                                 ($signed({1'b0, rd_pix2[23:16]}) * w02) +
                                 ($signed({1'b0, rd_pix3[23:16]}) * w03);
                        row0_g = ($signed({1'b0, rd_pix0[15:8]}) * w00) +
                                 ($signed({1'b0, rd_pix1[15:8]}) * w01) +
                                 ($signed({1'b0, rd_pix2[15:8]}) * w02) +
                                 ($signed({1'b0, rd_pix3[15:8]}) * w03);
                        row0_b = ($signed({1'b0, rd_pix0[7:0]}) * w00) +
                                 ($signed({1'b0, rd_pix1[7:0]}) * w01) +
                                 ($signed({1'b0, rd_pix2[7:0]}) * w02) +
                                 ($signed({1'b0, rd_pix3[7:0]}) * w03);
                        row1_r = ($signed({1'b0, rd_pix4[23:16]}) * w10) +
                                 ($signed({1'b0, rd_pix5[23:16]}) * w11) +
                                 ($signed({1'b0, rd_pix6[23:16]}) * w12) +
                                 ($signed({1'b0, rd_pix7[23:16]}) * w13);
                        row1_g = ($signed({1'b0, rd_pix4[15:8]}) * w10) +
                                 ($signed({1'b0, rd_pix5[15:8]}) * w11) +
                                 ($signed({1'b0, rd_pix6[15:8]}) * w12) +
                                 ($signed({1'b0, rd_pix7[15:8]}) * w13);
                        row1_b = ($signed({1'b0, rd_pix4[7:0]}) * w10) +
                                 ($signed({1'b0, rd_pix5[7:0]}) * w11) +
                                 ($signed({1'b0, rd_pix6[7:0]}) * w12) +
                                 ($signed({1'b0, rd_pix7[7:0]}) * w13);

                        pair_r = row0_r + row1_r;
                        pair_g = row0_g + row1_g;
                        pair_b = row0_b + row1_b;
                        next_r = acc_r + pair_r;
                        next_g = acc_g + pair_g;
                        next_b = acc_b + pair_b;

                        if (pair_idx_d1) begin
                            m_rgb[0*ACT_W +: ACT_W] <= acc_to_qbase(next_r);
                            m_rgb[1*ACT_W +: ACT_W] <= acc_to_qbase(next_g);
                            m_rgb[2*ACT_W +: ACT_W] <= acc_to_qbase(next_b);
                            m_user <= frame_user_q && (emit_x == {HR_X_W{1'b0}}) && (emit_y == {HR_Y_W{1'b0}});
                            m_last <= (emit_x == HR_W - 1);
                            m_valid <= 1'b1;
                            advance_pixel();
                            state <= ST_OUT;
                        end else begin
                            acc_r <= next_r;
                            acc_g <= next_g;
                            acc_b <= next_b;
                        end
                    end

                    if (issue_idx < 2) begin
                        issue_pair(issue_idx);
                        issue_idx <= issue_idx + 1'b1;
                    end
                end

                ST_OUT: begin
                    if (m_ready) begin
                        m_valid <= 1'b0;
                        if (frame_done_q) begin
                            state <= ST_LOAD;
                            pipe_valid_d0 <= 1'b0;
                            pipe_valid_d1 <= 1'b0;
                        end else begin
                            begin_pixel();
                            state <= ST_RUN;
                        end
                    end
                end

                default: state <= ST_LOAD;
            endcase
        end
    end

    wire unused_last = s_last;
endmodule
