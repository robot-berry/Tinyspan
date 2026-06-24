`timescale 1ns/1ps

module tb_sr_ddr_tinyspan_x4_endpoint_data;
    localparam int DATA_W = 24;
    localparam int AXI_DATA_W = 32;
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
    localparam logic [ADDR_W-1:0] CTRL_BASE = 32'hA000_0000;
    localparam logic [ADDR_W-1:0] INPUT_BASE = 32'h1000_0000;
    localparam logic [ADDR_W-1:0] OUTPUT_BASE = 32'h1100_0000;

    localparam logic [7:0] REG_CONTROL = 8'h00;
    localparam logic [7:0] REG_STATUS = 8'h04;
    localparam logic [7:0] REG_IMG_W = 8'h08;
    localparam logic [7:0] REG_IMG_H = 8'h0c;
    localparam logic [7:0] REG_INPUT_BASE = 8'h10;
    localparam logic [7:0] REG_OUTPUT_BASE = 8'h14;
    localparam logic [7:0] REG_TILES_DONE = 8'h20;
    localparam logic [7:0] REG_ERROR = 8'h24;

    logic clk = 1'b0;
    logic rstn = 1'b0;

    logic [7:0] s_axi_awaddr = '0;
    logic [2:0] s_axi_awprot = '0;
    logic s_axi_awvalid = 1'b0;
    wire s_axi_awready;
    logic [31:0] s_axi_wdata = '0;
    logic [3:0] s_axi_wstrb = 4'hf;
    logic s_axi_wvalid = 1'b0;
    wire s_axi_wready;
    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    logic s_axi_bready = 1'b0;
    logic [7:0] s_axi_araddr = '0;
    logic [2:0] s_axi_arprot = '0;
    logic s_axi_arvalid = 1'b0;
    wire s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    logic s_axi_rready = 1'b0;

    wire [ADDR_W-1:0] m_axi_awaddr;
    wire [7:0] m_axi_awlen;
    wire [2:0] m_axi_awsize;
    wire [1:0] m_axi_awburst;
    wire [3:0] m_axi_awcache;
    wire [2:0] m_axi_awprot;
    wire m_axi_awvalid;
    logic m_axi_awready = 1'b0;
    wire [AXI_DATA_W-1:0] m_axi_wdata;
    wire [(AXI_DATA_W/8)-1:0] m_axi_wstrb;
    wire m_axi_wlast;
    wire m_axi_wvalid;
    logic m_axi_wready = 1'b0;
    logic [1:0] m_axi_bresp = 2'b00;
    logic m_axi_bvalid = 1'b0;
    wire m_axi_bready;
    wire [ADDR_W-1:0] m_axi_araddr;
    wire [7:0] m_axi_arlen;
    wire [2:0] m_axi_arsize;
    wire [1:0] m_axi_arburst;
    wire [3:0] m_axi_arcache;
    wire [2:0] m_axi_arprot;
    wire m_axi_arvalid;
    logic m_axi_arready = 1'b0;
    logic [AXI_DATA_W-1:0] m_axi_rdata = '0;
    logic [1:0] m_axi_rresp = 2'b00;
    logic m_axi_rlast = 1'b1;
    logic m_axi_rvalid = 1'b0;
    wire m_axi_rready;
    wire irq;

    logic ref_s_valid = 1'b0;
    wire ref_s_ready;
    logic [DATA_W-1:0] ref_s_data = '0;
    logic ref_s_user = 1'b0;
    logic ref_s_last = 1'b0;
    wire ref_m_valid;
    wire [DATA_W-1:0] ref_m_data;
    wire ref_m_user;
    wire ref_m_last;

    logic [DATA_W-1:0] input_mem [0:FRAME_PIXELS-1];
    logic [DATA_W-1:0] ref_out [0:OUT_PIXELS-1];
    logic [DATA_W-1:0] output_mem [0:OUT_PIXELS-1];
    bit output_wrote [0:OUT_PIXELS-1];
    int ref_count = 0;
    int write_count = 0;
    int duplicate_count = 0;
    int mismatch_count = 0;
    int ready_tick = 0;
    bit endpoint_irq_seen = 1'b0;
    int ar_delay = 0;
    logic ar_pending = 1'b0;
    logic [ADDR_W-1:0] ar_addr_q = '0;
    logic aw_hold_valid = 1'b0;
    logic [ADDR_W-1:0] aw_hold_addr = '0;
    logic w_hold_valid = 1'b0;
    logic [AXI_DATA_W-1:0] w_hold_data = '0;
    logic [(AXI_DATA_W/8)-1:0] w_hold_strb = '0;

    always #5 clk = ~clk;

    sr_ddr_tinyspan_x4_tile_writer_endpoint #(
        .M_AXI_DATA_WIDTH(AXI_DATA_W),
        .DATA_W(DATA_W),
        .DEFAULT_IMG_W(IMG_W),
        .DEFAULT_IMG_H(IMG_H),
        .DEFAULT_INPUT_BASE(INPUT_BASE),
        .DEFAULT_OUTPUT_BASE(OUTPUT_BASE),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .SCALE(SCALE),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BPP),
        .USE_SERIAL_BASE(0)
    ) dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rstn),
        .m_axi_aclk(clk),
        .m_axi_aresetn(rstn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .irq(irq)
    );

    span_tinyspan_w8a8_full_streamed_rgb888_base_equiv #(
        .DATA_W(DATA_W),
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .USE_SERIAL_BASE(0)
    ) u_ref (
        .clk(clk),
        .rst(!rstn),
        .s_valid(ref_s_valid),
        .s_ready(ref_s_ready),
        .s_data(ref_s_data),
        .s_user(ref_s_user),
        .s_last(ref_s_last),
        .m_valid(ref_m_valid),
        .m_ready(1'b1),
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

    function automatic [DATA_W-1:0] read_pixel(input logic [ADDR_W-1:0] addr);
        int offset_bytes;
        int pixel_index;
        begin
            offset_bytes = addr - INPUT_BASE;
            if (addr < INPUT_BASE || (offset_bytes % BPP) != 0)
                $fatal(1, "AXI read address invalid: %08x", addr);
            pixel_index = offset_bytes / BPP;
            if (pixel_index < 0 || pixel_index >= FRAME_PIXELS)
                $fatal(1, "AXI read index out of range: %0d addr=%08x", pixel_index, addr);
            read_pixel = input_mem[pixel_index];
        end
    endfunction

    task automatic axi_lite_write(input logic [7:0] addr, input logic [31:0] data);
        bit aw_done;
        bit w_done;
        begin
            aw_done = 1'b0;
            w_done = 1'b0;
            @(posedge clk);
            s_axi_awaddr <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata <= data;
            s_axi_wstrb <= 4'hf;
            s_axi_wvalid <= 1'b1;
            s_axi_bready <= 1'b1;
            while (!aw_done || !w_done) begin
                @(posedge clk);
                if (!aw_done && s_axi_awready) begin
                    aw_done = 1'b1;
                    s_axi_awvalid <= 1'b0;
                end
                if (!w_done && s_axi_wready) begin
                    w_done = 1'b1;
                    s_axi_wvalid <= 1'b0;
                end
            end
            while (!s_axi_bvalid)
                @(posedge clk);
            @(posedge clk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task automatic axi_lite_read(input logic [7:0] addr, output logic [31:0] data);
        bit ar_done;
        begin
            ar_done = 1'b0;
            @(posedge clk);
            s_axi_araddr <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready <= 1'b1;
            while (!ar_done) begin
                @(posedge clk);
                if (s_axi_arready) begin
                    ar_done = 1'b1;
                    s_axi_arvalid <= 1'b0;
                end
            end
            while (!s_axi_rvalid)
                @(posedge clk);
            data = s_axi_rdata;
            @(posedge clk);
            s_axi_rready <= 1'b0;
        end
    endtask

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
        logic [31:0] status;
        logic [31:0] err;
        logic [31:0] tiles;

        for (int i = 0; i < FRAME_PIXELS; i++)
            input_mem[i] = pix(i);
        for (int i = 0; i < OUT_PIXELS; i++) begin
            ref_out[i] = '0;
            output_mem[i] = '0;
            output_wrote[i] = 1'b0;
        end

        repeat (8) @(posedge clk);
        rstn <= 1'b1;
        repeat (4) @(posedge clk);

        fork
            drive_ref_frame();
            begin
                axi_lite_write(REG_CONTROL, 32'h0000_0002);
                axi_lite_write(REG_IMG_W, IMG_W);
                axi_lite_write(REG_IMG_H, IMG_H);
                axi_lite_write(REG_INPUT_BASE, INPUT_BASE);
                axi_lite_write(REG_OUTPUT_BASE, OUTPUT_BASE);
                axi_lite_write(REG_CONTROL, 32'h0000_0001);
                for (int cyc = 0; cyc < 1000000; cyc++) begin
                    @(posedge clk);
                    if (irq) begin
                        endpoint_irq_seen = 1'b1;
                        break;
                    end
                end
                if (!endpoint_irq_seen)
                    $fatal(1, "timeout waiting for endpoint irq");
            end
        join

        axi_lite_read(REG_STATUS, status);
        axi_lite_read(REG_ERROR, err);
        axi_lite_read(REG_TILES_DONE, tiles);
        if ((status & 32'h8) == 0)
            $fatal(1, "endpoint did not report done, status=%08x", status);
        if (err != 0 || (status & 32'h10) != 0)
            $fatal(1, "endpoint reported error status=%08x err=%08x", status, err);
        if (tiles != 32'd1)
            $fatal(1, "expected one endpoint tile, got %0d", tiles);
        if (ref_count != OUT_PIXELS)
            $fatal(1, "reference output count mismatch: got=%0d expected=%0d", ref_count, OUT_PIXELS);
        if (write_count != OUT_PIXELS)
            $fatal(1, "AXI output write count mismatch: got=%0d expected=%0d", write_count, OUT_PIXELS);
        if (duplicate_count != 0)
            $fatal(1, "duplicate AXI output writes detected: %0d", duplicate_count);

        for (int i = 0; i < OUT_PIXELS; i++) begin
            if (!output_wrote[i])
                $fatal(1, "missing AXI output index %0d", i);
            if (output_mem[i] !== ref_out[i]) begin
                if (mismatch_count < 24) begin
                    $display("MISMATCH idx=%0d x=%0d y=%0d axi=%02x%02x%02x ref=%02x%02x%02x",
                             i, i % OUT_W, i / OUT_W,
                             output_mem[i][23:16], output_mem[i][15:8], output_mem[i][7:0],
                             ref_out[i][23:16], ref_out[i][15:8], ref_out[i][7:0]);
                end
                mismatch_count++;
            end
        end
        if (mismatch_count != 0)
            $fatal(1, "endpoint AXI data mismatch count=%0d", mismatch_count);
        $display("PASS sr_ddr_tinyspan_x4_endpoint_data pixels=%0d writes=%0d", OUT_PIXELS, write_count);
        $finish;
    end

    always @(posedge clk) begin
        if (!rstn) begin
            ready_tick <= 0;
            m_axi_awready <= 1'b0;
            m_axi_wready <= 1'b0;
            m_axi_arready <= 1'b0;
        end else begin
            ready_tick <= ready_tick + 1;
            m_axi_awready <= !aw_hold_valid && ((ready_tick % 7) != 3);
            m_axi_wready <= !w_hold_valid && ((ready_tick % 5) != 2);
            m_axi_arready <= !ar_pending && !m_axi_rvalid && ((ready_tick % 11) != 4);
        end
    end

    always @(posedge clk) begin
        if (!rstn) begin
            aw_hold_valid <= 1'b0;
            aw_hold_addr <= '0;
            w_hold_valid <= 1'b0;
            w_hold_data <= '0;
            w_hold_strb <= '0;
            m_axi_bvalid <= 1'b0;
            m_axi_bresp <= 2'b00;
            write_count <= 0;
            duplicate_count <= 0;
        end else begin
            if (m_axi_awvalid && m_axi_awready) begin
                aw_hold_valid <= 1'b1;
                aw_hold_addr <= m_axi_awaddr;
            end
            if (m_axi_wvalid && m_axi_wready) begin
                if (!m_axi_wlast)
                    $fatal(1, "AXI write beat without WLAST");
                w_hold_valid <= 1'b1;
                w_hold_data <= m_axi_wdata;
                w_hold_strb <= m_axi_wstrb;
            end
            if (!m_axi_bvalid && aw_hold_valid && w_hold_valid) begin
                int offset_bytes;
                int pixel_index;
                if (m_axi_awlen != 8'd0 || m_axi_awsize != 3'd2)
                    $fatal(1, "unexpected AXI write burst");
                offset_bytes = aw_hold_addr - OUTPUT_BASE;
                if (aw_hold_addr < OUTPUT_BASE || (offset_bytes % BPP) != 0)
                    $fatal(1, "AXI write address invalid: %08x", aw_hold_addr);
                pixel_index = offset_bytes / BPP;
                if (pixel_index < 0 || pixel_index >= OUT_PIXELS)
                    $fatal(1, "AXI write index out of range: %0d addr=%08x", pixel_index, aw_hold_addr);
                if (output_wrote[pixel_index])
                    duplicate_count++;
                output_wrote[pixel_index] = 1'b1;
                output_mem[pixel_index] <= w_hold_data[DATA_W-1:0];
                write_count++;
                aw_hold_valid <= 1'b0;
                w_hold_valid <= 1'b0;
                m_axi_bvalid <= 1'b1;
                m_axi_bresp <= 2'b00;
            end else if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!rstn) begin
            ar_pending <= 1'b0;
            ar_delay <= 0;
            ar_addr_q <= '0;
            m_axi_rvalid <= 1'b0;
            m_axi_rdata <= '0;
            m_axi_rresp <= 2'b00;
            m_axi_rlast <= 1'b1;
        end else begin
            if (m_axi_arvalid && m_axi_arready) begin
                if (m_axi_arlen != 8'd0 || m_axi_arsize != 3'd2)
                    $fatal(1, "unexpected AXI read burst");
                ar_pending <= 1'b1;
                ar_delay <= 2;
                ar_addr_q <= m_axi_araddr;
            end
            if (ar_pending && !m_axi_rvalid) begin
                if (ar_delay > 0) begin
                    ar_delay <= ar_delay - 1;
                end else begin
                    m_axi_rvalid <= 1'b1;
                    m_axi_rdata <= {{(AXI_DATA_W-DATA_W){1'b0}}, read_pixel(ar_addr_q)};
                    m_axi_rresp <= 2'b00;
                    m_axi_rlast <= 1'b1;
                    ar_pending <= 1'b0;
                end
            end
            if (m_axi_rvalid && m_axi_rready)
                m_axi_rvalid <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rstn && ref_m_valid) begin
            if (ref_count >= OUT_PIXELS)
                $fatal(1, "too many reference pixels");
            ref_out[ref_count] <= ref_m_data;
            ref_count++;
        end
    end

    wire unused_axi = ^{m_axi_awburst, m_axi_awcache, m_axi_awprot,
                        m_axi_arburst, m_axi_arcache, m_axi_arprot,
                        s_axi_bresp, s_axi_rresp, irq, CTRL_BASE,
                        ref_m_user, ref_m_last};
endmodule
