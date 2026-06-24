`timescale 1ns/1ps

// Single-pixel AXI4 bridge for TinySPAN frame buffers.
//
// This module is AXI user logic only. It does not implement a DDR controller,
// DDR PHY, or board-level DDR timing. The external memory is the board PS DDR
// controller IP exposed through the Vivado Block Design HP/HPC port.
//
// Reads are still blocking, matching the current tile fetch shell contract.
// Writes are posted single-beat AXI transactions with a small outstanding
// counter, so the TinySPAN output stream does not wait for every B response
// before presenting the next pixel.
module sr_ddr_pixel_axi_master #(
    parameter integer ADDR_W = 32,
    parameter integer DATA_W = 24,
    parameter integer AXI_DATA_W = 32,
    parameter integer MAX_WR_OUTSTANDING = 16
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  rd_req_valid,
    output wire                  rd_req_ready,
    input  wire [ADDR_W-1:0]     rd_req_addr,
    output reg                   rd_resp_valid,
    output reg  [DATA_W-1:0]     rd_resp_data,

    input  wire                  wr_valid,
    output wire                  wr_ready,
    input  wire [ADDR_W-1:0]     wr_addr,
    input  wire [DATA_W-1:0]     wr_data,

    output wire                  busy,
    output reg                   error,

    output reg  [ADDR_W-1:0]     m_axi_awaddr,
    output wire [7:0]            m_axi_awlen,
    output wire [2:0]            m_axi_awsize,
    output wire [1:0]            m_axi_awburst,
    output wire [3:0]            m_axi_awcache,
    output wire [2:0]            m_axi_awprot,
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,

    output reg  [AXI_DATA_W-1:0] m_axi_wdata,
    output reg  [(AXI_DATA_W/8)-1:0] m_axi_wstrb,
    output reg                   m_axi_wlast,
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,

    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,

    output reg  [ADDR_W-1:0]     m_axi_araddr,
    output wire [7:0]            m_axi_arlen,
    output wire [2:0]            m_axi_arsize,
    output wire [1:0]            m_axi_arburst,
    output wire [3:0]            m_axi_arcache,
    output wire [2:0]            m_axi_arprot,
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,

    input  wire [AXI_DATA_W-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rlast,
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready
);
    localparam [1:0] RD_IDLE = 2'd0;
    localparam [1:0] RD_ADDR = 2'd1;
    localparam [1:0] RD_DATA = 2'd2;

    localparam integer AXI_BYTES = AXI_DATA_W / 8;
    localparam [2:0] AXI_SIZE_32 = 3'd2;
    localparam [AXI_BYTES-1:0] WSTRB_RGB = {AXI_BYTES{1'b1}};

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam integer WR_COUNT_W = clog2(MAX_WR_OUTSTANDING + 1);
    localparam [WR_COUNT_W-1:0] MAX_WR_OUTSTANDING_C = MAX_WR_OUTSTANDING;

    reg [1:0] rd_state;
    reg pending_aw;
    reg pending_w;
    reg [WR_COUNT_W-1:0] wr_outstanding;

    wire pending_write = pending_aw || pending_w;
    wire wr_capacity = (wr_outstanding < MAX_WR_OUTSTANDING_C);
    wire b_fire = m_axi_bvalid && m_axi_bready;
    wire write_accept = wr_valid && wr_ready;

    assign rd_req_ready = (rd_state == RD_IDLE) && !pending_write && (wr_outstanding == 0);
    assign wr_ready = (rd_state == RD_IDLE) && !pending_write && wr_capacity;
    assign busy = (rd_state != RD_IDLE) || pending_write || (wr_outstanding != 0);

    assign m_axi_awlen = 8'd0;
    assign m_axi_awsize = AXI_SIZE_32;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot = 3'b000;

    assign m_axi_arlen = 8'd0;
    assign m_axi_arsize = AXI_SIZE_32;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot = 3'b000;

    always @(posedge clk) begin
        if (rst) begin
            rd_state <= RD_IDLE;
            pending_aw <= 1'b0;
            pending_w <= 1'b0;
            wr_outstanding <= {WR_COUNT_W{1'b0}};
            error <= 1'b0;
            rd_resp_valid <= 1'b0;
            rd_resp_data <= {DATA_W{1'b0}};
            m_axi_awaddr <= {ADDR_W{1'b0}};
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= {AXI_DATA_W{1'b0}};
            m_axi_wstrb <= {AXI_BYTES{1'b0}};
            m_axi_wlast <= 1'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
            m_axi_araddr <= {ADDR_W{1'b0}};
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
        end else begin
            rd_resp_valid <= 1'b0;
            m_axi_bready <= (wr_outstanding != 0) || write_accept;

            if (write_accept) begin
                m_axi_awaddr <= {wr_addr[ADDR_W-1:2], 2'b00};
                m_axi_awvalid <= 1'b1;
                pending_aw <= 1'b1;
                m_axi_wdata <= {{(AXI_DATA_W-DATA_W){1'b0}}, wr_data};
                m_axi_wstrb <= WSTRB_RGB;
                m_axi_wlast <= 1'b1;
                m_axi_wvalid <= 1'b1;
                pending_w <= 1'b1;
            end

            if (m_axi_awvalid && m_axi_awready) begin
                m_axi_awvalid <= 1'b0;
                pending_aw <= 1'b0;
            end
            if (m_axi_wvalid && m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
                m_axi_wlast <= 1'b0;
                pending_w <= 1'b0;
            end

            if (b_fire && m_axi_bresp != 2'b00)
                error <= 1'b1;

            case ({write_accept, b_fire})
                2'b10: wr_outstanding <= wr_outstanding + {{(WR_COUNT_W-1){1'b0}}, 1'b1};
                2'b01: wr_outstanding <= wr_outstanding - {{(WR_COUNT_W-1){1'b0}}, 1'b1};
                default: wr_outstanding <= wr_outstanding;
            endcase

            case (rd_state)
                RD_IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready <= 1'b0;
                    if (rd_req_valid && rd_req_ready) begin
                        m_axi_araddr <= {rd_req_addr[ADDR_W-1:2], 2'b00};
                        m_axi_arvalid <= 1'b1;
                        rd_state <= RD_ADDR;
                    end
                end

                RD_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b1;
                        rd_state <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        rd_resp_valid <= 1'b1;
                        rd_resp_data <= m_axi_rdata[DATA_W-1:0];
                        m_axi_rready <= 1'b0;
                        if (m_axi_rresp != 2'b00 || !m_axi_rlast)
                            error <= 1'b1;
                        rd_state <= RD_IDLE;
                    end
                end

                default: begin
                    error <= 1'b1;
                    rd_state <= RD_IDLE;
                end
            endcase
        end
    end
endmodule
