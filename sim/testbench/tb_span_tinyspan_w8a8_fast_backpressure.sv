`timescale 1ns/1ps

module tb_span_tinyspan_w8a8_fast_backpressure;
    localparam integer DATA_W = 24;
    localparam integer ACT_W = 8;
    localparam integer IMG_W = 32;
    localparam integer IMG_H = 32;
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer OUT_PIXELS = IMG_W * IMG_H * 16;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg s_valid = 1'b0;
    wire ref_s_ready;
    wire bp_s_ready;
    reg [DATA_W-1:0] s_data = {DATA_W{1'b0}};
    reg s_user = 1'b0;
    reg s_last = 1'b0;

    wire ref_valid;
    wire bp_valid;
    wire signed [3*ACT_W-1:0] ref_rgb;
    wire signed [3*ACT_W-1:0] bp_rgb;
    wire ref_user;
    wire bp_user;
    wire ref_last;
    wire bp_last;
    reg bp_ready = 1'b1;
    integer ready_tick = 0;

    reg signed [3*ACT_W-1:0] ref_out [0:OUT_PIXELS-1];
    reg signed [3*ACT_W-1:0] bp_out [0:OUT_PIXELS-1];
    integer ref_count = 0;
    integer bp_count = 0;
    integer i;
    integer mismatch_count;

    always #5 clk = ~clk;

    span_tinyspan_w8a8_bicubic_base_x4_streamed #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) u_ref (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(ref_s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(ref_valid),
        .m_ready(1'b1),
        .m_rgb(ref_rgb),
        .m_user(ref_user),
        .m_last(ref_last)
    );

    span_tinyspan_w8a8_bicubic_base_x4_streamed #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) u_bp (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(bp_s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(bp_valid),
        .m_ready(bp_ready),
        .m_rgb(bp_rgb),
        .m_user(bp_user),
        .m_last(bp_last)
    );

    task automatic drive_pixel;
        input integer idx;
        reg [7:0] r;
        reg [7:0] g;
        reg [7:0] b;
        begin
            r = (idx * 17 + 3) & 8'hff;
            g = (idx * 29 + 7) & 8'hff;
            b = (idx * 43 + 11) & 8'hff;
            s_data <= {r, g, b};
            s_user <= (idx == 0);
            s_last <= ((idx % IMG_W) == (IMG_W - 1));
            s_valid <= 1'b1;
            wait (ref_s_ready && bp_s_ready);
            @(posedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            ready_tick <= 0;
            bp_ready <= 1'b1;
        end else begin
            ready_tick <= ready_tick + 1;
            bp_ready <= (ready_tick % 9) == 0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ref_count <= 0;
            bp_count <= 0;
        end else begin
            if (ref_valid) begin
                if (ref_count < OUT_PIXELS)
                    ref_out[ref_count] <= ref_rgb;
                ref_count <= ref_count + 1;
            end
            if (bp_valid && bp_ready) begin
                if (bp_count < OUT_PIXELS)
                    bp_out[bp_count] <= bp_rgb;
                bp_count <= bp_count + 1;
            end
        end
    end

    initial begin
        repeat (8) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        for (i = 0; i < FRAME_PIXELS; i = i + 1)
            drive_pixel(i);

        s_valid <= 1'b0;
        s_user <= 1'b0;
        s_last <= 1'b0;

        fork
            begin
                wait ((ref_count >= OUT_PIXELS) && (bp_count >= OUT_PIXELS));
                #50;
                mismatch_count = 0;
                for (i = 0; i < OUT_PIXELS; i = i + 1) begin
                    if (ref_out[i] !== bp_out[i]) begin
                        if (mismatch_count < 16) begin
                            $display("MISMATCH idx=%0d ref=%0d/%0d/%0d bp=%0d/%0d/%0d",
                                i,
                                $signed(ref_out[i][0*ACT_W +: ACT_W]),
                                $signed(ref_out[i][1*ACT_W +: ACT_W]),
                                $signed(ref_out[i][2*ACT_W +: ACT_W]),
                                $signed(bp_out[i][0*ACT_W +: ACT_W]),
                                $signed(bp_out[i][1*ACT_W +: ACT_W]),
                                $signed(bp_out[i][2*ACT_W +: ACT_W]));
                        end
                        mismatch_count = mismatch_count + 1;
                    end
                end

                if (ref_count != OUT_PIXELS)
                    $fatal(1, "REF_COUNT_MISMATCH got=%0d expected=%0d", ref_count, OUT_PIXELS);
                if (bp_count != OUT_PIXELS)
                    $fatal(1, "BP_COUNT_MISMATCH got=%0d expected=%0d", bp_count, OUT_PIXELS);
                if (mismatch_count != 0)
                    $fatal(1, "FAST_BACKPRESSURE_MISMATCH count=%0d", mismatch_count);
                $display("PASS tinyspan_w8a8_fast_backpressure outputs=%0d", OUT_PIXELS);
                $finish;
            end
            begin
                #20000000;
                $fatal(1, "TIMEOUT ref_count=%0d bp_count=%0d expected=%0d", ref_count, bp_count, OUT_PIXELS);
            end
        join_any
    end

    wire unused_sideband = ref_user ^ bp_user ^ ref_last ^ bp_last;
endmodule
