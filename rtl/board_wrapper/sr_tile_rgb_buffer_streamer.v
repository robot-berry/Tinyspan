`timescale 1ns/1ps

// Tile-local RGB888 buffer and streamer.
//
// A large-image fetcher writes the valid pixels of one tile into this local
// buffer. The streamer emits a fixed TILE_W x TILE_H AXIS-like RGB888 tile to a
// small SR engine. Pixels outside valid_w/valid_h are zero-padded in hardware,
// so edge tiles do not require PC-side pre-cut or pre-padding.
module sr_tile_rgb_buffer_streamer #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 16,
    parameter integer TILE_H = 16,
    parameter integer COORD_W = 8,
    parameter integer STREAM_FIFO_DEPTH = 8
) (
    input  wire                     clk,
    input  wire                     rst,

    input  wire                     load_start,
    input  wire [COORD_W-1:0]       valid_w_i,
    input  wire [COORD_W-1:0]       valid_h_i,

    input  wire                     wr_valid,
    output wire                     wr_ready,
    input  wire [COORD_W-1:0]       wr_x,
    input  wire [COORD_W-1:0]       wr_y,
    input  wire [DATA_W-1:0]        wr_data,
    input  wire                     wr_pixel_valid,

    input  wire                     stream_start,
    output reg                      stream_busy,
    output reg                      stream_done,

    output wire                     m_valid,
    input  wire                     m_ready,
    output wire [DATA_W-1:0]        m_data,
    output wire                     m_pixel_valid,
    output wire                     m_user,
    output wire                     m_last
);
    localparam integer TILE_PIXELS = TILE_W * TILE_H;
    localparam integer ADDR_W = (TILE_PIXELS <= 2) ? 1 : $clog2(TILE_PIXELS);
    localparam integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W);
    localparam integer Y_W = (TILE_H <= 2) ? 1 : $clog2(TILE_H);
    localparam integer ISSUE_COUNT_W = $clog2(TILE_PIXELS + 1);
    localparam integer FIFO_PTR_W = (STREAM_FIFO_DEPTH <= 2) ? 1 : $clog2(STREAM_FIFO_DEPTH);
    localparam integer FIFO_COUNT_W = $clog2(STREAM_FIFO_DEPTH + 1);
    localparam [COORD_W-1:0] TILE_W_C = TILE_W[COORD_W-1:0];
    localparam [COORD_W-1:0] TILE_H_C = TILE_H[COORD_W-1:0];
    localparam [ADDR_W-1:0] ADDR_ONE = 1;
    localparam [ADDR_W-1:0] TILE_PIXELS_LAST = (TILE_PIXELS-1);
    localparam [ISSUE_COUNT_W-1:0] TILE_PIXELS_COUNT = TILE_PIXELS[ISSUE_COUNT_W-1:0];
    localparam [FIFO_COUNT_W-1:0] FIFO_DEPTH_C = STREAM_FIFO_DEPTH[FIFO_COUNT_W-1:0];

    (* ram_style = "block" *)
    reg [DATA_W-1:0] mem [0:TILE_PIXELS-1];
    (* ram_style = "block" *)
    reg valid_mem [0:TILE_PIXELS-1];
    reg [COORD_W-1:0] valid_w;
    reg [COORD_W-1:0] valid_h;
    reg [X_W-1:0] issue_x;
    reg [Y_W-1:0] issue_y;
    reg [ADDR_W-1:0] issue_addr;
    reg [ISSUE_COUNT_W-1:0] issue_count;
    reg [ADDR_W-1:0] rd_addr;
    reg [DATA_W-1:0] rd_data;
    reg rd_valid_data;
    reg rd_pipe0_valid;
    reg [X_W-1:0] rd_pipe0_x;
    reg [Y_W-1:0] rd_pipe0_y;
    reg [ADDR_W-1:0] rd_pipe0_addr;
    reg rd_pipe1_valid;
    reg [X_W-1:0] rd_pipe1_x;
    reg [Y_W-1:0] rd_pipe1_y;
    reg [ADDR_W-1:0] rd_pipe1_addr;
    reg [FIFO_PTR_W-1:0] fifo_wr_ptr;
    reg [FIFO_PTR_W-1:0] fifo_rd_ptr;
    reg [FIFO_COUNT_W-1:0] fifo_count;
    reg [DATA_W-1:0] fifo_data [0:STREAM_FIFO_DEPTH-1];
    reg fifo_pixel_valid [0:STREAM_FIFO_DEPTH-1];
    reg fifo_user [0:STREAM_FIFO_DEPTH-1];
    reg fifo_last [0:STREAM_FIFO_DEPTH-1];
    reg fifo_final [0:STREAM_FIFO_DEPTH-1];
    reg load_pending;

    wire wr_in_tile = (wr_x < TILE_W_C) && (wr_y < TILE_H_C);
    wire wr_in_valid = (wr_x < valid_w) && (wr_y < valid_h);
    wire [ADDR_W-1:0] wr_addr = (wr_y[Y_W-1:0] * TILE_W) + wr_x[X_W-1:0];
    wire accept_out = m_valid && m_ready;
    wire issue_more = (issue_count < TILE_PIXELS_COUNT);
    wire issue_end_row = (issue_x == TILE_W-1);
    wire [FIFO_COUNT_W:0] buffered_total =
        {1'b0, fifo_count} +
        {{FIFO_COUNT_W{1'b0}}, rd_pipe0_valid} +
        {{FIFO_COUNT_W{1'b0}}, rd_pipe1_valid};
    wire can_issue_read = stream_busy && issue_more &&
                          ((buffered_total - {{FIFO_COUNT_W{1'b0}}, accept_out}) <
                           {1'b0, FIFO_DEPTH_C});
    wire push_fifo = stream_busy && rd_pipe1_valid;
    wire pop_final = accept_out && fifo_final[fifo_rd_ptr];

    assign wr_ready = !load_pending && !stream_busy;
    assign m_valid = stream_busy && (fifo_count != {FIFO_COUNT_W{1'b0}});
    assign m_data = fifo_data[fifo_rd_ptr];
    assign m_pixel_valid = m_valid && fifo_pixel_valid[fifo_rd_ptr];
    assign m_user = m_valid && fifo_user[fifo_rd_ptr];
    assign m_last = m_valid && fifo_last[fifo_rd_ptr];

    always @(posedge clk) begin
        if (rst) begin
            valid_w <= {COORD_W{1'b0}};
            valid_h <= {COORD_W{1'b0}};
            issue_x <= {X_W{1'b0}};
            issue_y <= {Y_W{1'b0}};
            issue_addr <= {ADDR_W{1'b0}};
            issue_count <= {ISSUE_COUNT_W{1'b0}};
            rd_addr <= {ADDR_W{1'b0}};
            rd_data <= {DATA_W{1'b0}};
            rd_valid_data <= 1'b0;
            rd_pipe0_valid <= 1'b0;
            rd_pipe0_x <= {X_W{1'b0}};
            rd_pipe0_y <= {Y_W{1'b0}};
            rd_pipe0_addr <= {ADDR_W{1'b0}};
            rd_pipe1_valid <= 1'b0;
            rd_pipe1_x <= {X_W{1'b0}};
            rd_pipe1_y <= {Y_W{1'b0}};
            rd_pipe1_addr <= {ADDR_W{1'b0}};
            fifo_wr_ptr <= {FIFO_PTR_W{1'b0}};
            fifo_rd_ptr <= {FIFO_PTR_W{1'b0}};
            fifo_count <= {FIFO_COUNT_W{1'b0}};
            load_pending <= 1'b0;
            stream_busy <= 1'b0;
            stream_done <= 1'b0;
        end else begin
            stream_done <= 1'b0;
            rd_data <= mem[rd_addr];
            rd_valid_data <= valid_mem[rd_addr];

            if (load_start) begin
                valid_w <= (valid_w_i > TILE_W_C) ? TILE_W_C : valid_w_i;
                valid_h <= (valid_h_i > TILE_H_C) ? TILE_H_C : valid_h_i;
                load_pending <= 1'b1;
                stream_busy <= 1'b0;
                rd_pipe0_valid <= 1'b0;
                rd_pipe1_valid <= 1'b0;
                fifo_wr_ptr <= {FIFO_PTR_W{1'b0}};
                fifo_rd_ptr <= {FIFO_PTR_W{1'b0}};
                fifo_count <= {FIFO_COUNT_W{1'b0}};
                issue_addr <= {ADDR_W{1'b0}};
                issue_count <= {ISSUE_COUNT_W{1'b0}};
                issue_x <= {X_W{1'b0}};
                issue_y <= {Y_W{1'b0}};
                rd_addr <= {ADDR_W{1'b0}};
            end else if (load_pending) begin
                load_pending <= 1'b0;
            end else if (wr_valid && wr_ready && wr_in_tile && wr_in_valid) begin
                mem[wr_addr] <= wr_data;
                valid_mem[wr_addr] <= wr_pixel_valid;
            end

            if (stream_start && !stream_busy && !load_pending) begin
                stream_busy <= 1'b1;
                issue_x <= {X_W{1'b0}};
                issue_y <= {Y_W{1'b0}};
                issue_addr <= {ADDR_W{1'b0}};
                issue_count <= {ISSUE_COUNT_W{1'b0}};
                rd_addr <= {ADDR_W{1'b0}};
                rd_pipe0_valid <= 1'b0;
                rd_pipe1_valid <= 1'b0;
                fifo_wr_ptr <= {FIFO_PTR_W{1'b0}};
                fifo_rd_ptr <= {FIFO_PTR_W{1'b0}};
                fifo_count <= {FIFO_COUNT_W{1'b0}};
            end else if (stream_busy) begin
                if (push_fifo) begin
                    fifo_data[fifo_wr_ptr] <= out_pixel_for(rd_pipe1_x, rd_pipe1_y, rd_data);
                    fifo_pixel_valid[fifo_wr_ptr] <= out_valid_for(rd_pipe1_x, rd_pipe1_y, rd_valid_data);
                    fifo_user[fifo_wr_ptr] <= (rd_pipe1_addr == {ADDR_W{1'b0}});
                    fifo_last[fifo_wr_ptr] <= (rd_pipe1_x == TILE_W-1);
                    fifo_final[fifo_wr_ptr] <= (rd_pipe1_addr == TILE_PIXELS_LAST);
                    fifo_wr_ptr <= (fifo_wr_ptr == STREAM_FIFO_DEPTH-1) ?
                                   {FIFO_PTR_W{1'b0}} : fifo_wr_ptr + 1'b1;
                end

                if (accept_out) begin
                    fifo_rd_ptr <= (fifo_rd_ptr == STREAM_FIFO_DEPTH-1) ?
                                   {FIFO_PTR_W{1'b0}} : fifo_rd_ptr + 1'b1;
                end

                case ({push_fifo, accept_out})
                    2'b10: fifo_count <= fifo_count + {{(FIFO_COUNT_W-1){1'b0}}, 1'b1};
                    2'b01: fifo_count <= fifo_count - {{(FIFO_COUNT_W-1){1'b0}}, 1'b1};
                    default: fifo_count <= fifo_count;
                endcase

                if (pop_final) begin
                    stream_busy <= 1'b0;
                    stream_done <= 1'b1;
                    rd_pipe0_valid <= 1'b0;
                    rd_pipe1_valid <= 1'b0;
                end else begin
                    rd_pipe1_valid <= rd_pipe0_valid;
                    rd_pipe1_x <= rd_pipe0_x;
                    rd_pipe1_y <= rd_pipe0_y;
                    rd_pipe1_addr <= rd_pipe0_addr;
                    rd_pipe0_valid <= 1'b0;

                    if (can_issue_read) begin
                        rd_addr <= issue_addr;
                        rd_pipe0_valid <= 1'b1;
                        rd_pipe0_x <= issue_x;
                        rd_pipe0_y <= issue_y;
                        rd_pipe0_addr <= issue_addr;
                        issue_addr <= issue_addr + ADDR_ONE;
                        issue_count <= issue_count + {{(ISSUE_COUNT_W-1){1'b0}}, 1'b1};
                        if (issue_end_row) begin
                            issue_x <= {X_W{1'b0}};
                            issue_y <= issue_y + {{(Y_W-1){1'b0}}, 1'b1};
                        end else begin
                            issue_x <= issue_x + {{(X_W-1){1'b0}}, 1'b1};
                        end
                    end else begin
                        rd_pipe0_valid <= 1'b0;
                    end
                end
            end
        end
    end

    function [DATA_W-1:0] out_pixel_for;
        input [X_W-1:0] nx;
        input [Y_W-1:0] ny;
        input [DATA_W-1:0] pixel;
        begin
            if (({{(COORD_W-X_W){1'b0}}, nx} < valid_w) &&
                ({{(COORD_W-Y_W){1'b0}}, ny} < valid_h))
                out_pixel_for = pixel;
            else
                out_pixel_for = {DATA_W{1'b0}};
        end
    endfunction

    function out_valid_for;
        input [X_W-1:0] nx;
        input [Y_W-1:0] ny;
        input pixel_valid;
        begin
            out_valid_for = ({{(COORD_W-X_W){1'b0}}, nx} < valid_w) &&
                            ({{(COORD_W-Y_W){1'b0}}, ny} < valid_h) &&
                            pixel_valid;
        end
    endfunction
endmodule
