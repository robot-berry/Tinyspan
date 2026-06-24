`timescale 1ns/1ps

module tb_sr_tile_tinyspan_x4_writer_shell;
    localparam int DATA_W = 24;
    localparam int TILE_W = 4;
    localparam int TILE_H = 4;
    localparam int SCALE = 4;
    localparam int IMG_W = 6;
    localparam int IMG_H = 5;
    localparam int OUT_W = IMG_W * SCALE;
    localparam int OUT_H = IMG_H * SCALE;
    localparam int OUT_PIXELS = OUT_W * OUT_H;
    localparam int COORD_W = 16;
    localparam int ADDR_W = 32;
    localparam int BPP = 3;
    localparam logic [ADDR_W-1:0] INPUT_BASE = 32'h0000_0000;
    localparam logic [ADDR_W-1:0] OUTPUT_BASE = 32'h0010_0000;

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

    logic [DATA_W-1:0] input_mem [0:IMG_W*IMG_H-1];
    bit wrote [0:OUT_PIXELS-1];
    int write_count;
    int duplicate_count;
    int ready_tick;
    logic pending_resp;
    logic [ADDR_W-1:0] pending_addr;

    always #5 clk = ~clk;

    sr_tile_tinyspan_x4_writer_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BPP),
        .USE_SERIAL_BASE(1)
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

    function automatic [DATA_W-1:0] pix(input int x, input int y);
        pix = {8'(x * 17 + y), 8'(y * 29 + x), 8'(x * 11 + y * 7)};
    endfunction

    function automatic [DATA_W-1:0] data_for_addr(input logic [ADDR_W-1:0] addr);
        int offset_bytes;
        int pixel_index;
        begin
            offset_bytes = (addr - INPUT_BASE) / BPP;
            pixel_index = offset_bytes;
            if (addr < INPUT_BASE || (addr - INPUT_BASE) % BPP != 0 ||
                pixel_index < 0 || pixel_index >= IMG_W * IMG_H) begin
                $fatal(1, "read address out of range: %08x", addr);
            end
            data_for_addr = input_mem[pixel_index];
        end
    endfunction

    initial begin
        for (int y = 0; y < IMG_H; y++) begin
            for (int x = 0; x < IMG_W; x++) begin
                input_mem[y * IMG_W + x] = pix(x, y);
            end
        end

        repeat (4) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        for (int cyc = 0; cyc < 2000000; cyc++) begin
            @(posedge clk);
            if (done)
                break;
        end
        if (!done)
            $fatal(1, "timeout waiting for full-frame TinySPAN tile writer");
        @(posedge clk);

        if (error)
            $fatal(1, "unexpected shell error");
        if (tiles_done != 32'd4)
            $fatal(1, "expected 4 tiles, got %0d", tiles_done);
        if (write_count != OUT_PIXELS)
            $fatal(1, "expected %0d output writes, got %0d", OUT_PIXELS, write_count);
        if (duplicate_count != 0)
            $fatal(1, "duplicate writes detected: %0d", duplicate_count);
        for (int i = 0; i < OUT_PIXELS; i++) begin
            if (!wrote[i])
                $fatal(1, "missing output pixel index %0d", i);
        end
        $display("PASS sr_tile_tinyspan_x4_writer_shell tiles=%0d writes=%0d frame_cycles=%0d",
                 tiles_done, write_count, frame_cycles);
        $finish;
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
        if (rst) begin
            ready_tick <= 0;
            wr_ready <= 1'b1;
        end else begin
            ready_tick <= ready_tick + 1;
            wr_ready <= (ready_tick % 7) != 4;
        end
    end

    always @(posedge clk) begin
        if (!rst && wr_valid && wr_ready) begin
            int out_offset_bytes;
            int out_index;
            if (^wr_data === 1'bx)
                $fatal(1, "write data contains X at addr=%08x", wr_addr);
            if (wr_addr < OUTPUT_BASE || (wr_addr - OUTPUT_BASE) % BPP != 0)
                $fatal(1, "write address is invalid: %08x", wr_addr);
            out_offset_bytes = wr_addr - OUTPUT_BASE;
            out_index = out_offset_bytes / BPP;
            if (out_index < 0 || out_index >= OUT_PIXELS)
                $fatal(1, "write index out of range: %0d addr=%08x", out_index, wr_addr);
            if (wrote[out_index])
                duplicate_count++;
            wrote[out_index] = 1'b1;
            write_count++;
        end
    end
endmodule
