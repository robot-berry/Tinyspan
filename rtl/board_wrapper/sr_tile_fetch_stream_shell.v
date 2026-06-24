`timescale 1ns/1ps

// One-tile fetch and stream shell.
//
// Consumes a hardware tile command, issues linear RGB888/XRGB888 read requests
// for the valid region from a large image buffer, writes the pixels into a
// tile-local buffer, then streams a fixed TILE_W x TILE_H tile with hardware
// zero padding.
//
// The read side can keep multiple AXI read requests outstanding through the
// simple rd_req/rd_resp interface. Responses are consumed in order and matched
// to tile-local coordinates through a small FIFO. This is AXI user logic only;
// board DDR remains the PS DDR controller IP in the Vivado Block Design.
module sr_tile_fetch_stream_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 16,
    parameter integer TILE_H = 16,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer MAX_RD_OUTSTANDING = 16
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  cmd_valid,
    output wire                  cmd_ready,
    input  wire [COORD_W-1:0]    cmd_image_w,
    input  wire [COORD_W-1:0]    cmd_valid_w,
    input  wire [COORD_W-1:0]    cmd_valid_h,
    input  wire [ADDR_W-1:0]     cmd_input_addr,

    output reg                   rd_req_valid,
    input  wire                  rd_req_ready,
    output reg  [ADDR_W-1:0]     rd_req_addr,
    input  wire                  rd_resp_valid,
    input  wire [DATA_W-1:0]     rd_resp_data,

    output wire                  m_valid,
    input  wire                  m_ready,
    output wire [DATA_W-1:0]     m_data,
    output wire                  m_pixel_valid,
    output wire                  m_user,
    output wire                  m_last,

    output reg                   busy,
    output reg                   done,
    output reg                   error
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_CLEAR_WAIT = 3'd1;
    localparam [2:0] ST_FETCH      = 3'd2;
    localparam [2:0] ST_STREAM_ARM = 3'd3;
    localparam [2:0] ST_STREAM     = 3'd4;

    localparam [COORD_W-1:0] TILE_W_C = TILE_W[COORD_W-1:0];
    localparam [COORD_W-1:0] TILE_H_C = TILE_H[COORD_W-1:0];

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam integer RD_PTR_W = (MAX_RD_OUTSTANDING <= 2) ? 1 : clog2(MAX_RD_OUTSTANDING);
    localparam integer RD_COUNT_W = clog2(MAX_RD_OUTSTANDING + 1);
    localparam [RD_PTR_W-1:0] RD_PTR_LAST = MAX_RD_OUTSTANDING - 1;
    localparam [RD_COUNT_W-1:0] MAX_RD_OUTSTANDING_C = MAX_RD_OUTSTANDING;
    localparam [RD_COUNT_W-1:0] MAX_RD_OUTSTANDING_M1_C = MAX_RD_OUTSTANDING - 1;

    reg [2:0] state;
    reg [COORD_W-1:0] image_w;
    reg [COORD_W-1:0] valid_w;
    reg [COORD_W-1:0] valid_h;
    reg [ADDR_W-1:0] base_addr;
    reg [COORD_W-1:0] fetch_x;
    reg [COORD_W-1:0] fetch_y;
    reg saw_buffer_clear;
    reg issue_done;
    reg [RD_PTR_W-1:0] fifo_wr_ptr;
    reg [RD_PTR_W-1:0] fifo_rd_ptr;
    reg [RD_COUNT_W-1:0] fifo_count;
    reg [COORD_W-1:0] fifo_x [0:MAX_RD_OUTSTANDING-1];
    reg [COORD_W-1:0] fifo_y [0:MAX_RD_OUTSTANDING-1];
    reg buf_load_start;
    reg buf_wr_valid;
    wire buf_wr_ready;
    reg [COORD_W-1:0] buf_wr_x;
    reg [COORD_W-1:0] buf_wr_y;
    reg [DATA_W-1:0] buf_wr_data;
    reg stream_start;
    wire stream_busy;
    wire stream_done;

    wire command_bad = (cmd_image_w == 0) || (cmd_valid_w == 0) || (cmd_valid_h == 0) ||
                       (cmd_valid_w > TILE_W_C) || (cmd_valid_h > TILE_H_C);
    wire req_fire = rd_req_valid && rd_req_ready;
    wire resp_fire = rd_resp_valid;
    wire issue_last = (fetch_x == (valid_w - {{(COORD_W-1){1'b0}}, 1'b1})) &&
                      (fetch_y == (valid_h - {{(COORD_W-1){1'b0}}, 1'b1}));
    wire end_issue_row = (fetch_x == (valid_w - {{(COORD_W-1){1'b0}}, 1'b1}));
    wire [COORD_W-1:0] next_fetch_x =
        end_issue_row ? {COORD_W{1'b0}} : fetch_x + {{(COORD_W-1){1'b0}}, 1'b1};
    wire [COORD_W-1:0] next_fetch_y =
        end_issue_row ? fetch_y + {{(COORD_W-1){1'b0}}, 1'b1} : fetch_y;
    wire fifo_full = (fifo_count == MAX_RD_OUTSTANDING_C);
    wire fifo_empty = (fifo_count == {RD_COUNT_W{1'b0}});
    wire can_start_req = (state == ST_FETCH) && !issue_done && !fifo_full;
    wire can_keep_req_after_fire =
        !issue_last && ((fifo_count < MAX_RD_OUTSTANDING_M1_C) || (resp_fire && !fifo_empty));
    wire [RD_COUNT_W:0] fifo_count_plus_req =
        {1'b0, fifo_count} + {{RD_COUNT_W{1'b0}}, req_fire};
    wire final_response = resp_fire && !fifo_empty &&
                          (issue_done || (req_fire && issue_last)) &&
                          (fifo_count_plus_req == {{RD_COUNT_W{1'b0}}, 1'b1});
    wire [ADDR_W+COORD_W+3:0] pixel_offset =
        (({{(ADDR_W+4){1'b0}}, fetch_y} * {{(ADDR_W+4){1'b0}}, image_w}) +
         {{(ADDR_W+4){1'b0}}, fetch_x}) * BYTES_PER_PIXEL;
    wire [ADDR_W+COORD_W+3:0] next_pixel_offset =
        (({{(ADDR_W+4){1'b0}}, next_fetch_y} * {{(ADDR_W+4){1'b0}}, image_w}) +
         {{(ADDR_W+4){1'b0}}, next_fetch_x}) * BYTES_PER_PIXEL;

    assign cmd_ready = (state == ST_IDLE);

    sr_tile_rgb_buffer_streamer #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .COORD_W(COORD_W)
    ) u_tile_buffer (
        .clk(clk),
        .rst(rst),
        .load_start(buf_load_start),
        .valid_w_i(valid_w),
        .valid_h_i(valid_h),
        .wr_valid(buf_wr_valid),
        .wr_ready(buf_wr_ready),
        .wr_x(buf_wr_x),
        .wr_y(buf_wr_y),
        .wr_data(buf_wr_data),
        .wr_pixel_valid(1'b1),
        .stream_start(stream_start),
        .stream_busy(stream_busy),
        .stream_done(stream_done),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data),
        .m_pixel_valid(m_pixel_valid),
        .m_user(m_user),
        .m_last(m_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            image_w <= {COORD_W{1'b0}};
            valid_w <= {COORD_W{1'b0}};
            valid_h <= {COORD_W{1'b0}};
            base_addr <= {ADDR_W{1'b0}};
            fetch_x <= {COORD_W{1'b0}};
            fetch_y <= {COORD_W{1'b0}};
            saw_buffer_clear <= 1'b0;
            issue_done <= 1'b0;
            fifo_wr_ptr <= {RD_PTR_W{1'b0}};
            fifo_rd_ptr <= {RD_PTR_W{1'b0}};
            fifo_count <= {RD_COUNT_W{1'b0}};
            rd_req_valid <= 1'b0;
            rd_req_addr <= {ADDR_W{1'b0}};
            buf_load_start <= 1'b0;
            buf_wr_valid <= 1'b0;
            buf_wr_x <= {COORD_W{1'b0}};
            buf_wr_y <= {COORD_W{1'b0}};
            buf_wr_data <= {DATA_W{1'b0}};
            stream_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;
            buf_load_start <= 1'b0;
            buf_wr_valid <= 1'b0;
            stream_start <= 1'b0;

            case (state)
                ST_IDLE: begin
                    rd_req_valid <= 1'b0;
                    busy <= 1'b0;
                    if (cmd_valid) begin
                        error <= command_bad;
                        done <= command_bad;
                        if (!command_bad) begin
                            image_w <= cmd_image_w;
                            valid_w <= cmd_valid_w;
                            valid_h <= cmd_valid_h;
                            base_addr <= cmd_input_addr;
                            fetch_x <= {COORD_W{1'b0}};
                            fetch_y <= {COORD_W{1'b0}};
                            saw_buffer_clear <= 1'b0;
                            issue_done <= 1'b0;
                            fifo_wr_ptr <= {RD_PTR_W{1'b0}};
                            fifo_rd_ptr <= {RD_PTR_W{1'b0}};
                            fifo_count <= {RD_COUNT_W{1'b0}};
                            buf_load_start <= 1'b1;
                            busy <= 1'b1;
                            state <= ST_CLEAR_WAIT;
                        end
                    end
                end

                ST_CLEAR_WAIT: begin
                    busy <= 1'b1;
                    rd_req_valid <= 1'b0;
                    if (!buf_wr_ready)
                        saw_buffer_clear <= 1'b1;
                    if (saw_buffer_clear && buf_wr_ready)
                        state <= ST_FETCH;
                end

                ST_FETCH: begin
                    busy <= 1'b1;

                    if (rd_req_valid && !rd_req_ready) begin
                        rd_req_valid <= 1'b1;
                    end else if (req_fire && can_keep_req_after_fire) begin
                        rd_req_valid <= 1'b1;
                        rd_req_addr <= base_addr + next_pixel_offset[ADDR_W-1:0];
                    end else if (!rd_req_valid && can_start_req) begin
                        rd_req_valid <= 1'b1;
                        rd_req_addr <= base_addr + pixel_offset[ADDR_W-1:0];
                    end else begin
                        rd_req_valid <= 1'b0;
                    end

                    if (req_fire) begin
                        fifo_x[fifo_wr_ptr] <= fetch_x;
                        fifo_y[fifo_wr_ptr] <= fetch_y;
                        fifo_wr_ptr <= (fifo_wr_ptr == RD_PTR_LAST) ?
                                       {RD_PTR_W{1'b0}} : fifo_wr_ptr + 1'b1;
                        if (issue_last) begin
                            issue_done <= 1'b1;
                        end else begin
                            fetch_x <= next_fetch_x;
                            fetch_y <= next_fetch_y;
                        end
                    end

                    if (resp_fire) begin
                        if (fifo_empty) begin
                            error <= 1'b1;
                        end else begin
                            if (!buf_wr_ready)
                                error <= 1'b1;
                            buf_wr_valid <= buf_wr_ready;
                            buf_wr_x <= fifo_x[fifo_rd_ptr];
                            buf_wr_y <= fifo_y[fifo_rd_ptr];
                            buf_wr_data <= rd_resp_data;
                            fifo_rd_ptr <= (fifo_rd_ptr == RD_PTR_LAST) ?
                                           {RD_PTR_W{1'b0}} : fifo_rd_ptr + 1'b1;
                            if (final_response)
                                state <= ST_STREAM_ARM;
                        end
                    end

                    case ({req_fire, resp_fire && !fifo_empty})
                        2'b10: fifo_count <= fifo_count + {{(RD_COUNT_W-1){1'b0}}, 1'b1};
                        2'b01: fifo_count <= fifo_count - {{(RD_COUNT_W-1){1'b0}}, 1'b1};
                        default: fifo_count <= fifo_count;
                    endcase
                end

                ST_STREAM_ARM: begin
                    busy <= 1'b1;
                    rd_req_valid <= 1'b0;
                    stream_start <= 1'b1;
                    state <= ST_STREAM;
                end

                ST_STREAM: begin
                    busy <= 1'b1;
                    rd_req_valid <= 1'b0;
                    if (stream_done) begin
                        done <= 1'b1;
                        busy <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    rd_req_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule
