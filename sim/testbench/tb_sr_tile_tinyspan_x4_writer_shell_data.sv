`timescale 1ns/1ps

module tb_sr_tile_tinyspan_x4_writer_shell_data;
    localparam int DATA_W = 24;
    localparam int TILE_W = 32;
    localparam int TILE_H = 32;
    localparam int SCALE = 4;
    localparam int IMG_W = 32;
    localparam int IMG_H = 32;
    localparam int FRAME_PIXELS = IMG_W * IMG_H;
    localparam int OUT_W = IMG_W * SCALE;
    localparam int OUT_H = IMG_H * SCALE;
    localparam int OUT_PIXELS = OUT_W * OUT_H;
    localparam int COORD_W = 16;
    localparam int ADDR_W = 32;
    localparam int BPP = 4;
    localparam logic [ADDR_W-1:0] INPUT_BASE = 32'h1000_0000;
    localparam logic [ADDR_W-1:0] OUTPUT_BASE = 32'h1100_0000;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start = 1'b0;

    wire rd_req_valid;
    logic rd_req_ready = 1'b1;
    wire [ADDR_W-1:0] rd_req_addr;
    logic rd_resp_valid = 1'b0;
    logic [DATA_W-1:0] rd_resp_data = '0;

    wire wr_valid;
    logic wr_ready = 1'b1;
    wire [ADDR_W-1:0] wr_addr;
    wire [DATA_W-1:0] wr_data;
    wire busy;
    wire done;
    wire error;
    wire [31:0] tiles_done;
    wire [63:0] frame_cycles;

    logic ref_s_valid = 1'b0;
    wire ref_s_ready;
    logic [DATA_W-1:0] ref_s_data = '0;
    logic ref_s_user = 1'b0;
    logic ref_s_last = 1'b0;
    wire ref_m_valid;
    wire ref_m_ready = 1'b1;
    wire [DATA_W-1:0] ref_m_data;
    wire ref_m_user;
    wire ref_m_last;

    logic [DATA_W-1:0] input_mem [0:FRAME_PIXELS-1];
    logic [DATA_W-1:0] ref_out [0:OUT_PIXELS-1];
    logic [DATA_W-1:0] shell_out [0:OUT_PIXELS-1];
    bit shell_wrote [0:OUT_PIXELS-1];
    int ref_count = 0;
    int shell_count = 0;
    int duplicate_count = 0;
    int ready_tick = 0;
    int mismatch_count = 0;
    logic pending_resp = 1'b0;
    logic [ADDR_W-1:0] pending_addr = '0;

    always #5 clk = ~clk;

    sr_tile_tinyspan_x4_writer_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BPP),
        .USE_SERIAL_BASE(0)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .image_w(IMG_W[COORD_W-1:0]),
        .image_h(IMG_H[COORD_W-1:0]),
        .input_base(INPUT_BASE),
        .output_base(OUTPUT_BASE),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(busy),
        .done(done),
        .error(error),
        .tiles_done(tiles_done),
        .frame_cycles(frame_cycles)
    );

    span_tinyspan_w8a8_full_streamed_rgb888_base_equiv #(
        .DATA_W(DATA_W),
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .USE_SERIAL_BASE(0)
    ) u_ref (
        .clk(clk),
        .rst(rst),
        .s_valid(ref_s_valid),
        .s_ready(ref_s_ready),
        .s_data(ref_s_data),
        .s_user(ref_s_user),
        .s_last(ref_s_last),
        .m_valid(ref_m_valid),
        .m_ready(ref_m_ready),
        .m_data(ref_m_data),
        .m_user(ref_m_user),
        .m_last(ref_m_last)
    );

    function automatic [DATA_W-1:0] pix(input int idx);
        int x;
        int y;
        begin
            x = idx % IMG_W;
            y = idx / IMG_W;
            pix = {8'((x * 17 + y * 3 + 5) & 8'hff),
                   8'((x * 7 + y * 29 + 11) & 8'hff),
                   8'((x * 13 + y * 19 + 23) & 8'hff)};
        end
    endfunction

    function automatic [DATA_W-1:0] data_for_addr(input logic [ADDR_W-1:0] addr);
        int offset_bytes;
        int pixel_index;
        begin
            offset_bytes = addr - INPUT_BASE;
            if (addr < INPUT_BASE || (offset_bytes % BPP) != 0)
                $fatal(1, "read address is invalid: %08x", addr);
            pixel_index = offset_bytes / BPP;
            if (pixel_index < 0 || pixel_index >= FRAME_PIXELS)
                $fatal(1, "read index out of range: %0d addr=%08x", pixel_index, addr);
            data_for_addr = input_mem[pixel_index];
        end
    endfunction

    task automatic drive_ref_frame;
        int i;
        begin
            for (i = 0; i < FRAME_PIXELS; i++) begin
                ref_s_data <= input_mem[i];
                ref_s_user <= (i == 0);
                ref_s_last <= ((i % IMG_W) == (IMG_W - 1));
                ref_s_valid <= 1'b1;
                do begin
                    @(posedge clk);
                end while (!ref_s_ready);
            end
            ref_s_valid <= 1'b0;
            ref_s_user <= 1'b0;
            ref_s_last <= 1'b0;
            ref_s_data <= '0;
        end
    endtask

    initial begin
        for (int i = 0; i < FRAME_PIXELS; i++)
            input_mem[i] = pix(i);
        for (int i = 0; i < OUT_PIXELS; i++) begin
            ref_out[i] = '0;
            shell_out[i] = '0;
            shell_wrote[i] = 1'b0;
        end

        repeat (8) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        fork
            drive_ref_frame();
            begin
                for (int cyc = 0; cyc < 3000000; cyc++) begin
                    @(posedge clk);
                    if (done && ref_count >= OUT_PIXELS)
                        break;
                end
            end
        join

        if (!done)
            $fatal(1, "timeout waiting for tile writer data simulation");
        if (error)
            $fatal(1, "unexpected tile writer error");
        if (tiles_done != 32'd1)
            $fatal(1, "expected one tile, got %0d", tiles_done);
        if (ref_count != OUT_PIXELS)
            $fatal(1, "reference output count mismatch: got=%0d expected=%0d", ref_count, OUT_PIXELS);
        if (shell_count != OUT_PIXELS)
            $fatal(1, "shell output count mismatch: got=%0d expected=%0d", shell_count, OUT_PIXELS);
        if (duplicate_count != 0)
            $fatal(1, "duplicate shell writes detected: %0d", duplicate_count);

        for (int i = 0; i < OUT_PIXELS; i++) begin
            if (!shell_wrote[i])
                $fatal(1, "missing shell output index %0d", i);
            if (shell_out[i] !== ref_out[i]) begin
                if (mismatch_count < 24) begin
                    $display("MISMATCH idx=%0d x=%0d y=%0d shell=%02x%02x%02x ref=%02x%02x%02x",
                             i, i % OUT_W, i / OUT_W,
                             shell_out[i][23:16], shell_out[i][15:8], shell_out[i][7:0],
                             ref_out[i][23:16], ref_out[i][15:8], ref_out[i][7:0]);
                end
                mismatch_count++;
            end
        end
        if (mismatch_count != 0)
            $fatal(1, "tile writer data mismatch count=%0d", mismatch_count);
        $display("PASS sr_tile_tinyspan_x4_writer_shell_data pixels=%0d frame_cycles=%0d", OUT_PIXELS, frame_cycles);
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            ready_tick <= 0;
            rd_req_ready <= 1'b1;
            wr_ready <= 1'b1;
        end else begin
            ready_tick <= ready_tick + 1;
            rd_req_ready <= ((ready_tick % 5) != 2);
            wr_ready <= ((ready_tick % 11) != 3) && ((ready_tick % 11) != 7);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            pending_resp <= 1'b0;
            pending_addr <= '0;
            rd_resp_valid <= 1'b0;
            rd_resp_data <= '0;
        end else begin
            rd_resp_valid <= 1'b0;
            if (pending_resp) begin
                rd_resp_valid <= 1'b1;
                rd_resp_data <= data_for_addr(pending_addr);
                pending_resp <= 1'b0;
            end
            if (rd_req_valid && rd_req_ready) begin
                pending_resp <= 1'b1;
                pending_addr <= rd_req_addr;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst && ref_m_valid && ref_m_ready) begin
            if (ref_count >= OUT_PIXELS)
                $fatal(1, "too many reference pixels");
            ref_out[ref_count] <= ref_m_data;
            ref_count++;
        end
    end

    always @(posedge clk) begin
        if (!rst && wr_valid && wr_ready) begin
            int out_offset_bytes;
            int out_index;
            if (^wr_data === 1'bx)
                $fatal(1, "write data contains X at addr=%08x", wr_addr);
            out_offset_bytes = wr_addr - OUTPUT_BASE;
            if (wr_addr < OUTPUT_BASE || (out_offset_bytes % BPP) != 0)
                $fatal(1, "write address is invalid: %08x", wr_addr);
            out_index = out_offset_bytes / BPP;
            if (out_index < 0 || out_index >= OUT_PIXELS)
                $fatal(1, "write index out of range: %0d addr=%08x", out_index, wr_addr);
            if (shell_wrote[out_index])
                duplicate_count++;
            shell_wrote[out_index] = 1'b1;
            shell_out[out_index] <= wr_data;
            shell_count++;
        end
    end

    wire unused_ref_sideband = ref_m_user ^ ref_m_last ^ busy;
endmodule
